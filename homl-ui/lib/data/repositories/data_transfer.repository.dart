import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/data/transfer/export_seal.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/server_reachability.dart';

/// An import cannot start: the server is out of reach, or changes made
/// offline still wait ([pendingChanges]). The import compares the file with
/// what the server holds, so both have to be settled first.
class ImportUnavailableFailure implements Exception {
  final bool pendingChanges;

  const ImportUnavailableFailure({required this.pendingChanges});
}

/// The connection dropped during an import. What reached the server stays,
/// and importing the same file again finishes the job: what is already there
/// is skipped.
class ImportInterruptedFailure implements Exception {
  final ImportReport report;

  const ImportInterruptedFailure(this.report);
}

/// What an import did.
class ImportReport {
  int categoriesCreated = 0;
  int tagsCreated = 0;
  int eventsCreated = 0;

  /// Events of the file the account already had.
  int eventsExisting = 0;

  /// Tags and events the server refused (a reserved tag name, say): left
  /// out, the rest imported anyway.
  int skipped = 0;

  bool get changedAnything =>
      categoriesCreated + tagsCreated + eventsCreated > 0;
}

/// Thrown inside an import when a write was kept in the outbox instead of
/// reaching the server: the connection is gone.
class _Interrupted implements Exception {}

/// Export and import of the account's data (homl-web/docs/data-export.md).
///
/// Both run on the device, through the other repositories: the server never
/// sees the file, and under E2EE only the device can read the data anyway —
/// the export decrypts it, the import encrypts it again like any write.
class DataTransferRepository {
  final CategoriesRepository categoriesRepository;
  final TagsRepository tagsRepository;
  final EventsRepository eventsRepository;

  DataTransferRepository(
      {required this.categoriesRepository,
      required this.tagsRepository,
      required this.eventsRepository});

  /// The export file of everything the app holds, as bytes to save. Works
  /// offline from the copy saved on the device, the changes waiting to be
  /// sent included. [password] seals it ([ExportSeal]).
  Future<Uint8List> export(
      {String? password,
      @visibleForTesting int iterations = ExportSeal.defaultIterations}) async {
    final categories = await categoriesRepository.getCategories();
    final events = await eventsRepository.getEvents();
    final file =
        ExportFile.fromData(categories, events, exportedAt: DateTime.now());

    final plain = utf8.encode(_encoder.convert(file.toJson()));
    if (password == null) return Uint8List.fromList(plain);

    final sealed =
        await ExportSeal.seal(plain, password, iterations: iterations);
    return Uint8List.fromList(utf8.encode(_encoder.convert(sealed)));
  }

  /// Indented: the plain file is meant to be readable too.
  static const _encoder = JsonEncoder.withIndent('  ');

  /// Reads an export file. Throws [ExportPasswordRequiredFailure] for a
  /// sealed file without [password], [ExportPasswordFailure] for a wrong
  /// one, [ExportVersionFailure] for a newer format and
  /// [ExportFormatFailure] for anything else that is not a valid export.
  Future<ExportFile> read(Uint8List bytes, {String? password}) async {
    var json = _decode(bytes);
    if (ExportSeal.isSealed(json)) {
      if (password == null) throw ExportPasswordRequiredFailure();
      json = _decode(
          await ExportSeal.open(json as Map<String, dynamic>, password));
    }
    return ExportFile.fromJson(json);
  }

  static Object? _decode(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (err) {
      throw ExportFormatFailure('not JSON: ${err.message}');
    }
  }

  /// Adds the content of [file] to the account, skipping what it already
  /// holds — so importing the same file twice changes nothing, and an
  /// interrupted import ([ImportInterruptedFailure]) is finished by running
  /// it again:
  ///
  /// - a category is the account's category of the same name, the `other`
  ///   one going to the account's Others whatever its name; a missing one is
  ///   created (the file's `date` category, if any, is ignored);
  /// - a tag is the tag of the same name in that category; a missing one is
  ///   created, a synonym under its main tag;
  /// - an event is skipped when the account has one with the same days,
  ///   description and tags (each such event covers one copy in the file).
  ///
  /// Nothing that exists is changed. [onProgress] gets the items handled so
  /// far out of the total (tags and events).
  Future<ImportReport> import(ExportFile file,
      {void Function(int done, int total)? onProgress}) async {
    if (await Outbox.instance.shouldQueue()) {
      throw ImportUnavailableFailure(
          pendingChanges: !ServerReachability.instance.isOffline);
    }

    final List<Category> categories;
    final List<Event> events;
    try {
      categories =
          await categoriesRepository.getCategories(cacheFallback: false);
      events = await eventsRepository.getEvents(cacheFallback: false);
    } catch (_) {
      if (ServerReachability.instance.isOffline) {
        throw const ImportUnavailableFailure(pendingChanges: false);
      }
      rethrow;
    }

    final report = ImportReport();
    final total = file.tagCount + file.events.length;
    var done = 0;
    void step() => onProgress?.call(++done, total);
    onProgress?.call(0, total);

    try {
      final run = _ImportRun(this, categories, report, step);
      final slots = await run.importCategories(file.categories);
      await run.importEvents(file.events, slots, events);
    } on _Interrupted {
      throw ImportInterruptedFailure(report);
    } finally {
      // One reload of the app for the whole import, not one per event.
      if (report.changedAnything) eventsRepository.notifyChanged();
    }
    return report;
  }
}

/// A category of the account during an import: its id and its tags by key,
/// growing as the import creates them.
class _Slot {
  final int id;
  final Map<String, Tag> tags;

  _Slot(this.id, Iterable<Tag> tags)
      : tags = {for (final tag in tags) transferKey(tag.tag): tag};
}

/// The state of one import.
class _ImportRun {
  final DataTransferRepository repository;
  final ImportReport report;
  final void Function() step;

  final Set<int> dateIds;
  final Category? dateCategory;
  final Category? otherCategory;

  /// The account's Others, where the file's `other` category goes.
  late final _Slot? otherSlot = otherCategory == null
      ? null
      : _Slot(otherCategory!.id, otherCategory!.tags);

  /// The account's categories other than Dates and Others, by name key.
  final Map<String, _Slot> byName = {};

  /// The date tags known so far, by name key (E2EE: the client makes them).
  final Map<String, int> dateTags = {};

  _ImportRun(this.repository, List<Category> categories, this.report, this.step)
      : dateIds = dateCategoryIds(categories),
        dateCategory = categories
            .where((category) => category.kind == CategoryKind.date)
            .firstOrNull,
        otherCategory = categories
            .where((category) => category.kind == CategoryKind.other)
            .firstOrNull {
    for (final category in categories) {
      if (dateIds.contains(category.id) ||
          category.kind == CategoryKind.other) {
        continue;
      }
      // Two categories of the same name: the import adds to the first.
      byName.putIfAbsent(transferKey(category.category),
          () => _Slot(category.id, category.tags));
    }
    for (final tag in dateCategory?.tags ?? const <Tag>[]) {
      dateTags[transferKey(tag.tag)] = tag.id;
    }
  }

  /// The kind of a file category. A file that does not give it (one written
  /// by hand) is read by the names of the account's Dates and Others, so it
  /// does not make a second Others, or a Dates category of refused tags.
  String? _kindOf(ExportCategory category) {
    if (category.kind != null) return category.kind;
    final key = transferKey(category.name);
    if (dateCategory != null && key == transferKey(dateCategory!.category)) {
      return CategoryKind.date.name;
    }
    if (otherCategory != null && key == transferKey(otherCategory!.category)) {
      return CategoryKind.other.name;
    }
    return null;
  }

  /// Matches or creates the file's categories and tags; returns the slot of
  /// each file category name key (null for an ignored date category).
  Future<Map<String, _Slot?>> importCategories(
      List<ExportCategory> categories) async {
    final slots = <String, _Slot?>{};
    void skipTags(ExportCategory category) {
      for (final tag in category.tags) {
        for (var i = 0; i <= tag.synonyms.length; i++) {
          step();
        }
      }
    }

    for (final category in categories) {
      final key = transferKey(category.name);
      final kind = _kindOf(category);
      if (kind == CategoryKind.date.name) {
        slots.putIfAbsent(key, () => null);
        skipTags(category);
        continue;
      }

      var slot = slots[key] ??
          (kind == CategoryKind.other.name ? otherSlot : null) ??
          byName[key];
      if (slot == null) {
        slot = await _createCategory(category);
        if (slot == null) {
          // Refused: its tags are left out with it, and the events lose them.
          report.skipped += 1 + category.tagCount;
          slots.putIfAbsent(key, () => null);
          skipTags(category);
          continue;
        }
        byName[key] = slot;
      }
      slots[key] = slot;

      for (final tag in category.tags) {
        final main = await _ensureTag(slot, tag.name, null);
        step();
        // A synonym hangs off the main tag of its group (one level deep).
        final parent = main?.idParentTag ?? main?.id;
        for (final synonym in tag.synonyms) {
          await _ensureTag(slot, synonym, parent);
          step();
        }
      }
    }
    return slots;
  }

  /// The new category, or null when the server refused it.
  Future<_Slot?> _createCategory(ExportCategory category) async {
    try {
      final id = await repository.categoriesRepository
          .createCategory(category.name, category.color);
      report.categoriesCreated++;
      return _Slot(id, const []);
    } on CategoriesRequestFailure {
      _checkConnection();
      return null;
    } on CategoriesNotFoundFailure {
      return null;
    }
  }

  /// The tag called [name] in [slot], created when missing; null when the
  /// server refused it (counted as skipped). A synonym whose main tag was
  /// refused ([parent] null) becomes a main tag.
  Future<Tag?> _ensureTag(_Slot slot, String name, int? parent) async {
    final key = transferKey(name);
    final existing = slot.tags[key];
    if (existing != null) return existing;

    final int id;
    try {
      id = await repository.tagsRepository
          .createTag(name, slot.id, idParentTag: parent);
    } on TagsBlacklistedFailure {
      report.skipped++;
      return null;
    } on TagNameConflictFailure {
      report.skipped++;
      return null;
    } on TagsRequestFailure {
      _checkConnection();
      report.skipped++;
      return null;
    }
    // A negative id was kept in the outbox: the server is gone.
    if (id < 0) throw _Interrupted();

    final tag =
        Tag(id: id, tag: name, idCategory: slot.id, idParentTag: parent);
    slot.tags[key] = tag;
    report.tagsCreated++;
    return tag;
  }

  Future<void> importEvents(List<ExportEvent> events, Map<String, _Slot?> slots,
      List<Event> existing) async {
    // How many copies of each event the account holds.
    final held = <String, int>{};
    for (final event in existing) {
      final signature = _signature(
          event.date,
          event.endDate,
          event.isOngoing,
          event.description,
          event.tags
              .where((tag) => !dateIds.contains(tag.idCategory))
              .map((tag) => tag.id));
      held[signature] = (held[signature] ?? 0) + 1;
    }

    for (final event in events) {
      final tagIds = <int>{
        for (final ref in event.tags)
          if (slots[transferKey(ref.category)]?.tags[transferKey(ref.tag)]
              case final tag?)
            tag.id
      };

      final signature = _signature(event.date, event.endDate, event.isOngoing,
          event.description, tagIds);
      final copies = held[signature] ?? 0;
      if (copies > 0) {
        held[signature] = copies - 1;
        report.eventsExisting++;
        step();
        continue;
      }

      try {
        // Under E2EE the backend cannot derive the date tags from the
        // encrypted event: the client attaches them, like the insert form.
        final dateTagIds =
            E2ee().enabled ? await _dateTagIds(event) : const <int>[];
        final outcome = await repository.eventsRepository.createEvent(
            description: event.description,
            date: event.date,
            endDate: event.endDate,
            isOngoing: event.isOngoing,
            tagsId: [...tagIds, ...dateTagIds],
            notify: false);
        if (outcome == WriteOutcome.queued) throw _Interrupted();
        report.eventsCreated++;
      } on EventsRequestFailure {
        _checkConnection();
        report.skipped++;
      } on TagsRequestFailure {
        _checkConnection();
        report.skipped++;
      } on TagNameConflictFailure {
        // A date tag another device created meanwhile: the next run has it.
        report.skipped++;
      }
      step();
    }
  }

  /// The ids of the date tags of [event]'s period, created when missing with
  /// the blacklist lifted (they ARE the reserved names).
  Future<List<int>> _dateTagIds(ExportEvent event) async {
    final category = dateCategory;
    if (category == null) return const [];

    final ids = <int>[];
    for (final name in periodDateTagNames(
        date: event.date, endDate: event.endDate, isOngoing: event.isOngoing)) {
      final key = transferKey(name);
      var id = dateTags[key];
      if (id == null) {
        id = await repository.tagsRepository
            .createTag(name, category.id, isDateTag: true);
        if (id < 0) throw _Interrupted();
        dateTags[key] = id;
      }
      ids.add(id);
    }
    return ids;
  }

  /// A refused write on a lost connection is an interruption, not a skip.
  void _checkConnection() {
    if (ServerReachability.instance.isOffline) throw _Interrupted();
  }

  static String _signature(DateTime date, DateTime? endDate, bool isOngoing,
      String description, Iterable<int> tagIds) {
    final tags = tagIds.toSet().toList()..sort();
    return jsonEncode([
      formatDay(date),
      endDate == null ? null : formatDay(endDate),
      isOngoing,
      description,
      tags,
    ]);
  }
}
