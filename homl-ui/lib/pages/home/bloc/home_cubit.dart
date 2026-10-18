import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/local_usage.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:rxdart/rxdart.dart';

part 'home_state.dart';

// Common cubit to share state between views
class HomeCubit extends Cubit<HomeState> {
  final EventsRepository eventsRepository;
  final CategoriesRepository categoriesRepository;
  final TagsRepository tagsRepository;
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;
  late StreamSubscription<void> _eventsChangedSubscription;
  late StreamSubscription<List<Reachability>> _reachabilitySubscription;
  late StreamSubscription<SyncReport> _syncSubscription;
  late StreamSubscription<OutboxCounts> _outboxSubscription;

  HomeCubit(this.settingsRepository, this.eventsRepository,
      this.categoriesRepository, this.tagsRepository, String username)
      : super(HomeState.initial(username)) {
    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'HomeCubit');
      emit(state.copyWith(settings: settings));
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'HomeCubit', error: error);
      errorModal(AppMessage.requestFailed);
    });

    // Refresh the shared events/categories when another page (e.g. the
    // insert form) reports a change through the repository stream.
    _eventsChangedSubscription = eventsRepository.changes.listen((_) {
      init();
    });

    // Back online after an offline spell: fetch what changed meanwhile (and
    // rewrite the offline cache).
    _reachabilitySubscription = ServerReachability.instance.stream
        .pairwise()
        .where((pair) =>
            pair.first == Reachability.offline &&
            pair.last == Reachability.online)
        .listen((_) {
      init();
    });

    // The changes made offline reached the server (or some could not):
    // reload, and say what happened.
    _syncSubscription = SyncEngine.instance.reports.listen(_onSyncReport);

    // The badge of the app bar.
    _outboxSubscription = Outbox.instance.counts.listen((counts) {
      if (!isClosed) emit(state.copyWith(pendingChanges: counts));
    });

    init();
  }

  Future<void> _onSyncReport(SyncReport report) async {
    await _fetch();
    if (isClosed) return;
    // One message: the one that most needs the user's attention.
    final message = report.parked > 0
        ? AppMessage.syncParked
        : report.restored > 0
            ? AppMessage.syncRestored
            : report.dropped > 0
                ? AppMessage.syncDropped
                : report.kept > 0
                    ? AppMessage.syncKept
                    : report.conflicts > 0
                        ? AppMessage.syncConflicts
                        : AppMessage.syncSent;
    emit(state.copyWith(modal: message));
  }

  /// The Dates category always wears the logo gold, whatever the backend
  /// stored: its color is not editable and brands the date tags across the
  /// app. Purely cosmetic, so legacy backends without [Category.kind] keep
  /// their stored color rather than risk gilding the wrong category.
  List<Category> _withFixedDateColor(List<Category> categories) => [
        for (final category in categories)
          category.kind == CategoryKind.date
              ? Category(
                  id: category.id,
                  category: category.category,
                  color: yellowHex,
                  isLocked: category.isLocked,
                  kind: category.kind,
                  tags: category.tags,
                  groups: category.groups)
              : category,
      ];

  Map<String, TagView> _buildTagsMap(List<Category> categories) {
    Map<String, TagView> tagMap = {};

    for (var category in categories) {
      for (var tag in category.tags) {
        tagMap[tag.tag] = TagView(
            tag.id, category.color, tag.tag, category.id, tag.idParentTag);
      }
    }

    var sortedEntries = tagMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sortedEntries);
  }

  /// Re-fetches the categories (and the tags map) after any tag/category CRUD.
  Future<void> _refreshCategories() async {
    final categories =
        _withFixedDateColor(await categoriesRepository.getCategories());
    emit(state.copyWith(
        categories: categories, allTagsMap: _buildTagsMap(categories)));
  }

  Future<void> init() async {
    // Serve the saved snapshot first: the UI is usable immediately (and
    // offline); the network refresh below overwrites it when it lands.
    if (!state.initialized) {
      final cachedEvents = await eventsRepository.getCachedEvents();
      final cachedCategories = await categoriesRepository.getCachedCategories();

      if (isClosed) return;
      if (cachedEvents != null && cachedCategories != null) {
        final categories = _withFixedDateColor(cachedCategories);
        emit(state.copyWith(
            events: cachedEvents,
            categories: categories,
            allTagsMap: _buildTagsMap(categories),
            initialized: true,
            lastSyncedAt: eventsRepository.lastSyncedAt));
      }
    }

    // Offline with a snapshot on screen: stale data is fine.
    if (!await _fetch() && !isClosed && !state.initialized) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// Fetches the events and categories (the repositories fall back to the
  /// saved copy when the server cannot be reached). False when nothing could
  /// be loaded at all.
  Future<bool> _fetch() async {
    try {
      final events = await eventsRepository.getEvents();
      final categories =
          _withFixedDateColor(await categoriesRepository.getCategories());

      // A reconnection can land after the page was closed (logout).
      if (isClosed) return true;
      emit(state.copyWith(
          events: events,
          categories: categories,
          allTagsMap: _buildTagsMap(categories),
          initialized: true,
          lastSyncedAt: eventsRepository.lastSyncedAt));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pull to refresh: the user asked, so an unreachable server is said even
  /// with the saved data on screen. The changes waiting to be sent go first.
  Future<void> refresh() async {
    if (!ServerReachability.instance.isOffline) {
      await SyncEngine.instance.sync();
    }
    final fetched = await _fetch();
    if (isClosed) return;
    if (!fetched || ServerReachability.instance.isOffline) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// Back in the foreground: fetch again unless the data is fresh. Not while
  /// the server is known unreachable — the reconnection reloads then.
  Future<void> refreshIfStale(
      {Duration maxAge = const Duration(minutes: 1)}) async {
    if (ServerReachability.instance.isOffline) return;
    SyncEngine.instance.kick();
    final last = state.lastSyncedAt;
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    await _fetch();
  }

  Future<void> refreshEvents() async {
    try {
      final events = await eventsRepository.getEvents();
      emit(state.copyWith(events: events));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  Future<void> deleteEvent(int id) async {
    try {
      // The repository change stream triggers init(), which refreshes the
      // shared events (and rewrites the offline cache).
      if (await eventsRepository.deleteEvent(id) == WriteOutcome.queued) {
        emit(state.copyWith(modal: AppMessage.savedOffline));
      }
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// Returns true when the tag was created (false emits an error modal), so
  /// callers chaining on the creation (e.g. the insert page tagging its
  /// event with the new tag) know whether to proceed.
  Future<bool> createTag(String text, int idCategory,
      {int? idParentTag}) async {
    try {
      await tagsRepository.createTag(text, idCategory,
          idParentTag: idParentTag);
      await _refreshCategories();
      return true;
    } on TagNameConflictFailure {
      // The name is already taken in that category and nothing was created:
      // say so, so the user renames instead of retrying the same name.
      emit(state.copyWith(modal: AppMessage.tagNameConflict));
      return false;
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
      return false;
    }
  }

  /// The server is out of reach, or changes made offline still wait: what
  /// it would answer is not what the screens show.
  bool get _changesWait =>
      ServerReachability.instance.isOffline ||
      Outbox.instance.currentCounts.pending > 0;

  /// Says that a change waits on this device for the server.
  void _sayIfQueued(WriteOutcome outcome) {
    if (outcome == WriteOutcome.queued && !isClosed) {
      emit(state.copyWith(modal: AppMessage.savedOffline));
    }
  }

  /// Offline, a deletion "with its events" deletes the events this device
  /// shows, one ordinary deletion each (one edited elsewhere meanwhile is
  /// kept), before the tag or category goes alone: the server must not
  /// delete events added elsewhere that nobody here has seen
  /// (homl-web/docs/offline-sync.md).
  Future<void> _deleteShownEvents(Set<int> tags) async {
    final ids = [
      for (final event in state.events)
        if (event.tags.any((tag) => tags.contains(tag.id))) event.id,
    ];
    for (final id in ids) {
      await eventsRepository.deleteEvent(id, notify: false);
    }
    if (ids.isNotEmpty) eventsRepository.notifyChanged();
  }

  Future<void> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    try {
      final outcome = await tagsRepository.updateTag(id, text, idCategory,
          idParentTag: idParentTag);
      // Event payloads embed the tag's name and category: refresh them too.
      await refreshEvents();
      await _refreshCategories();
      _sayIfQueued(outcome);
    } on TagNameConflictFailure {
      // Renaming onto a taken name, or moving into a category that already
      // has one: nothing changed, the tag is still where it was.
      emit(state.copyWith(modal: AppMessage.tagNameConflict));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// [deleteEvents] only matters for main tags: it also deletes every event
  /// tagged with the deleted synonym group.
  Future<void> deleteTag(int id, {bool deleteEvents = false}) async {
    try {
      WriteOutcome outcome;
      try {
        outcome =
            await tagsRepository.deleteTag(id, deleteEvents: deleteEvents);
      } on DeleteEventsOfflineFailure {
        await _deleteShownEvents(synonymGroup(state.categories, id));
        outcome = await tagsRepository.deleteTag(id);
      }
      // The events changed too: deleted, or stripped of the removed tags.
      await refreshEvents();
      await _refreshCategories();
      _sayIfQueued(outcome);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// Moves a main tag (with its synonyms, handled by the backend) to another
  /// category, keeping its name and synonym links.
  Future<void> moveTag(Tag tag, int idCategory) =>
      updateTag(tag.id, tag.tag, idCategory, idParentTag: tag.idParentTag);

  /// Creates a tag group of [members] (main tags of the category).
  Future<void> createTagGroup(
      String name, int idCategory, List<int> members) async {
    try {
      final id =
          await categoriesRepository.createTagGroup(name, idCategory, members);
      await _refreshCategories();
      _sayIfQueued(id < 0 ? WriteOutcome.queued : WriteOutcome.sent);
    } catch (error) {
      emit(state.copyWith(modal: _tagGroupMessage(error)));
    }
  }

  /// Full-state update of a group: its name and its whole member list.
  Future<void> updateTagGroup(int id, String name, List<int> members) async {
    try {
      final outcome =
          await categoriesRepository.updateTagGroup(id, name, members);
      await _refreshCategories();
      _sayIfQueued(outcome);
    } catch (error) {
      emit(state.copyWith(modal: _tagGroupMessage(error)));
    }
  }

  /// Deletes the group only: its tags and their events stay.
  Future<void> deleteTagGroup(int id) async {
    try {
      final outcome = await categoriesRepository.deleteTagGroup(id);
      await _refreshCategories();
      _sayIfQueued(outcome);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  AppMessage _tagGroupMessage(Object error) => switch (error) {
        // Another group of the category has the name: nothing was written.
        TagGroupNameConflictFailure() => AppMessage.tagGroupNameConflict,
        _ => AppMessage.requestFailed,
      };

  /// Event counts for the tag's synonym group, or null when the request
  /// fails (an error modal is emitted instead). Without the server, they
  /// come from the events on this device.
  Future<TagUsage?> fetchTagUsage(int id) async {
    if (id < 0 || _changesWait) {
      return localTagUsage(state.events, state.categories, id);
    }
    try {
      return await tagsRepository.getTagUsage(id);
    } catch (_) {
      if (ServerReachability.instance.isOffline) {
        return localTagUsage(state.events, state.categories, id);
      }
      emit(state.copyWith(modal: AppMessage.requestFailed));
      return null;
    }
  }

  /// Tag/event counts for a category, or null when the request fails (an
  /// error modal is emitted instead). Without the server, they come from the
  /// data on this device.
  Future<CategoryUsage?> fetchCategoryUsage(int id) async {
    if (id < 0 || _changesWait) {
      return localCategoryUsage(state.events, state.categories, id);
    }
    try {
      return await categoriesRepository.getCategoryUsage(id);
    } catch (_) {
      if (ServerReachability.instance.isOffline) {
        return localCategoryUsage(state.events, state.categories, id);
      }
      emit(state.copyWith(modal: AppMessage.requestFailed));
      return null;
    }
  }

  Future<void> createCategory(String name, String color) async {
    try {
      final id = await categoriesRepository.createCategory(name, color);
      await _refreshCategories();
      _sayIfQueued(id < 0 ? WriteOutcome.queued : WriteOutcome.sent);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  Future<void> updateCategory(int id, String name, String color) async {
    try {
      final outcome =
          await categoriesRepository.updateCategory(id, name, color);
      await _refreshCategories();
      _sayIfQueued(outcome);
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  /// [moveTags] moves the tags to the Other category; otherwise the tags are
  /// deleted and [deleteEvents] also deletes every event tagged with one of
  /// them.
  Future<void> deleteCategory(int id,
      {bool moveTags = false, bool deleteEvents = false}) async {
    try {
      WriteOutcome outcome;
      try {
        outcome = await categoriesRepository.deleteCategory(id,
            moveTags: moveTags, deleteEvents: deleteEvents);
      } on DeleteEventsOfflineFailure {
        await _deleteShownEvents({
          for (final category in state.categories)
            if (category.id == id)
              for (final tag in category.tags) tag.id,
        });
        outcome = await categoriesRepository.deleteCategory(id);
      }
      // The events changed too: deleted, or stripped of the removed tags.
      await refreshEvents();
      await _refreshCategories();
      _sayIfQueued(outcome);
    } on CategoryTagNameConflictFailure {
      // Nothing was deleted: say why, so the user can rename the tag or pick
      // one of the two other options instead of retrying blindly.
      emit(state.copyWith(modal: AppMessage.categoryTagNameConflict));
    } catch (_) {
      emit(state.copyWith(modal: AppMessage.requestFailed));
    }
  }

  void errorModal(AppMessage error) {
    emit(state.copyWith(modal: error));
  }

  void endModal() {
    emit(state.copyWith(clearModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'HomeCubit');
    _settingsSubscription.cancel();
    _eventsChangedSubscription.cancel();
    _reachabilitySubscription.cancel();
    _syncSubscription.cancel();
    _outboxSubscription.cancel();
    return super.close();
  }
}
