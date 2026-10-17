import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/tag_groups.dart';

/// A file that is not a homl export, or a damaged one. [reason] is for the
/// logs: the user only learns that the file cannot be read.
class ExportFormatFailure implements Exception {
  final String reason;

  const ExportFormatFailure(this.reason);

  @override
  String toString() => 'ExportFormatFailure: $reason';
}

/// A homl export written by a newer version of the app, in a format this one
/// does not know yet.
class ExportVersionFailure implements Exception {}

/// The key two names are matched on, in a file and against an account: case
/// and surrounding spaces do not count, like the backend's unique tag names
/// (stored title-cased, so "movie night" and "Movie Night" are one tag).
String transferKey(String name) => name.trim().toLowerCase();

/// The portable copy of an account's data: what "Export my data" writes and
/// "Import data" reads (homl-web/docs/data-export.md).
///
/// Everything is referenced by name, never by server id, so a file can go
/// into any account on any server. The date tags are left out: they follow
/// from the event periods and are rebuilt on import.
class ExportFile {
  static const format = 'homl-export';
  static const version = 1;

  final DateTime exportedAt;
  final List<ExportCategory> categories;

  /// Oldest first; the events of one day in the order they were created.
  final List<ExportEvent> events;

  const ExportFile(
      {required this.exportedAt,
      required this.categories,
      required this.events});

  /// Main tags and synonyms together.
  int get tagCount =>
      categories.fold(0, (sum, category) => sum + category.tagCount);

  int get groupCount =>
      categories.fold(0, (sum, category) => sum + category.groups.length);

  /// Builds the file from what the app shows: [categories] and [events] as
  /// the repositories hand them out (decrypted), [events] in the
  /// `GET /events` order (newest first).
  factory ExportFile.fromData(List<Category> categories, List<Event> events,
      {required DateTime exportedAt}) {
    final dateIds = dateCategoryIds(categories);
    final exported = <ExportCategory>[];
    // Tag id -> the name pair the events of the file point at. The date tags
    // are never in it, so they drop out of the events on their own.
    final refs = <int, ExportTagRef>{};

    for (final category in categories) {
      if (dateIds.contains(category.id)) continue;

      final ids = category.tags.map((tag) => tag.id).toSet();
      final tags = <ExportTag>[];
      for (final main in category.tags) {
        // A synonym whose main tag is missing is exported as a main tag.
        final parent = main.idParentTag;
        if (parent != null && parent != main.id && ids.contains(parent)) {
          continue;
        }
        final synonyms = category.tags
            .where((tag) => tag.idParentTag == main.id && tag.id != main.id)
            .toList();
        tags.add(ExportTag(
            name: main.tag, synonyms: [for (final s in synonyms) s.tag]));
        refs[main.id] =
            ExportTagRef(category: category.category, tag: main.tag);
        for (final synonym in synonyms) {
          refs[synonym.id] =
              ExportTagRef(category: category.category, tag: synonym.tag);
        }
      }

      exported.add(ExportCategory(
          name: category.category,
          kind: category.kind?.name,
          color: category.color,
          tags: tags,
          // A group with no tag left carries nothing worth keeping.
          groups: [
            for (final group in category.groups)
              if (tagGroupMemberNames(category, group) case final members
                  when members.isNotEmpty)
                ExportGroup(name: group.name, tags: members)
          ]));
    }

    // Newest first in, oldest first out: reversed, then a stable sort on the
    // day (the index breaks ties) in case the list was not strictly ordered.
    final ordered = events.reversed.toList().asMap().entries.toList()
      ..sort((a, b) {
        final byDay = _day(a.value.date).compareTo(_day(b.value.date));
        return byDay != 0 ? byDay : a.key.compareTo(b.key);
      });

    return ExportFile(
      exportedAt: exportedAt,
      categories: exported,
      events: [
        for (final entry in ordered)
          ExportEvent(
            date: _day(entry.value.date),
            endDate:
                entry.value.endDate == null ? null : _day(entry.value.endDate!),
            isOngoing: entry.value.isOngoing,
            description: entry.value.description,
            tags: {
              for (final tag in entry.value.tags)
                if (refs[tag.id] != null) refs[tag.id]!
            }.toList(),
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'categories': [for (final category in categories) category.toJson()],
        'events': [for (final event in events) event.toJson()],
      };

  /// Reads a decoded file, refusing anything that would not import cleanly:
  /// the whole file is checked before a single write is made.
  factory ExportFile.fromJson(Object? json) {
    final root = _map(json, 'the file');
    if (root['format'] != format) {
      throw const ExportFormatFailure('not a homl export');
    }
    final fileVersion = root['version'];
    if (fileVersion is! int || fileVersion < 1) {
      throw const ExportFormatFailure('no valid version');
    }
    if (fileVersion > version) throw ExportVersionFailure();

    final exportedAt = DateTime.tryParse(_string(root, 'exportedAt'));
    if (exportedAt == null) {
      throw const ExportFormatFailure('exportedAt is not a date');
    }

    final categories = [
      for (final category in _list(root['categories'], 'categories'))
        ExportCategory._fromJson(category)
    ];

    // Category key -> the keys of its tags, to check the events and the
    // groups against.
    final listed = <String, Set<String>>{};
    for (final category in categories) {
      final tags = listed.putIfAbsent(transferKey(category.name), () => {});
      for (final tag in category.tags) {
        tags.add(transferKey(tag.name));
        tags.addAll(tag.synonyms.map(transferKey));
      }
    }
    for (final category in categories) {
      for (final group in category.groups) {
        for (final tag in group.tags) {
          if (!listed[transferKey(category.name)]!.contains(transferKey(tag))) {
            throw ExportFormatFailure(
                'the group "${category.name}/${group.name}" holds "$tag", '
                'which the category does not list');
          }
        }
      }
    }

    final events = [
      for (final event in _list(root['events'], 'events'))
        ExportEvent._fromJson(event)
    ];
    for (final event in events) {
      for (final ref in event.tags) {
        final tags = listed[transferKey(ref.category)];
        if (tags == null || !tags.contains(transferKey(ref.tag))) {
          throw ExportFormatFailure(
              'an event points at "${ref.category}/${ref.tag}", '
              'which no category lists');
        }
      }
    }

    return ExportFile(
        exportedAt: exportedAt, categories: categories, events: events);
  }
}

class ExportCategory {
  final String name;

  /// `person`, `other`, `custom` (see homl-web/docs/default-categories.md);
  /// null when the server did not say.
  final String? kind;
  final String color;
  final List<ExportTag> tags;
  final List<ExportGroup> groups;

  const ExportCategory(
      {required this.name,
      this.kind,
      required this.color,
      required this.tags,
      this.groups = const []});

  /// Main tags and synonyms together.
  int get tagCount => tags.fold(0, (sum, tag) => sum + 1 + tag.synonyms.length);

  Map<String, dynamic> toJson() => {
        'name': name,
        if (kind != null) 'kind': kind,
        'color': color,
        'tags': [for (final tag in tags) tag.toJson()],
        if (groups.isNotEmpty)
          'groups': [for (final group in groups) group.toJson()],
      };

  /// What the backend accepts as a category color (go-playground hexcolor).
  static final _hexColor = RegExp(
      r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  factory ExportCategory._fromJson(Object? json) {
    final map = _map(json, 'a category');
    final color = _string(map, 'color');
    if (!_hexColor.hasMatch(color)) {
      throw ExportFormatFailure('"$color" is not a hex color');
    }
    final kind = map['kind'];
    if (kind != null && kind is! String) {
      throw const ExportFormatFailure('a category kind is not a string');
    }
    return ExportCategory(
      name: _name(map, 'name'),
      kind: kind as String?,
      color: color,
      tags: [
        for (final tag in _list(map['tags'], 'tags')) ExportTag._fromJson(tag)
      ],
      groups: [
        if (map['groups'] != null)
          for (final group in _list(map['groups'], 'groups'))
            ExportGroup._fromJson(group)
      ],
    );
  }
}

/// A tag group (homl-web/docs/tag-groups.md): its name and the tags it
/// stands for, by name, among the tags of its category.
class ExportGroup {
  final String name;
  final List<String> tags;

  const ExportGroup({required this.name, required this.tags});

  Map<String, dynamic> toJson() => {'name': name, 'tags': tags};

  factory ExportGroup._fromJson(Object? json) {
    final map = _map(json, 'a group');
    final tags = _list(map['tags'], 'group tags');
    if (tags.isEmpty) throw const ExportFormatFailure('a group has no tags');
    return ExportGroup(
      name: _name(map, 'name'),
      tags: [
        for (final tag in tags)
          if (tag is String && tag.trim().isNotEmpty)
            tag.trim()
          else
            throw const ExportFormatFailure('a group tag is not a name')
      ],
    );
  }
}

/// A main tag and its synonyms (homl-web/docs/tag-synonyms.md).
class ExportTag {
  final String name;
  final List<String> synonyms;

  const ExportTag({required this.name, this.synonyms = const []});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (synonyms.isNotEmpty) 'synonyms': synonyms,
      };

  factory ExportTag._fromJson(Object? json) {
    final map = _map(json, 'a tag');
    final synonyms = map['synonyms'] == null
        ? const <Object?>[]
        : _list(map['synonyms'], 'synonyms');
    return ExportTag(
      name: _name(map, 'name'),
      synonyms: [
        for (final synonym in synonyms)
          if (synonym is String && synonym.trim().isNotEmpty)
            synonym.trim()
          else
            throw const ExportFormatFailure('a synonym is not a name')
      ],
    );
  }
}

/// Points at a tag of the file by name: the tag (main or synonym) called
/// [tag] in the category called [category].
class ExportTagRef {
  final String category;
  final String tag;

  const ExportTagRef({required this.category, required this.tag});

  Map<String, dynamic> toJson() => {'category': category, 'tag': tag};

  factory ExportTagRef._fromJson(Object? json) {
    final map = _map(json, 'an event tag');
    return ExportTagRef(
        category: _name(map, 'category'), tag: _name(map, 'tag'));
  }

  @override
  bool operator ==(Object other) =>
      other is ExportTagRef &&
      transferKey(other.category) == transferKey(category) &&
      transferKey(other.tag) == transferKey(tag);

  @override
  int get hashCode => Object.hash(transferKey(category), transferKey(tag));
}

/// An event, with the period rules of the backend (homl-web/docs/api.md,
/// *Periods*): [date] is the start, [endDate] the inclusive end of a closed
/// period, [isOngoing] an open one. Days are UTC midnights.
class ExportEvent {
  final DateTime date;
  final DateTime? endDate;
  final bool isOngoing;
  final String description;
  final List<ExportTagRef> tags;

  const ExportEvent(
      {required this.date,
      this.endDate,
      this.isOngoing = false,
      this.description = '',
      required this.tags});

  Map<String, dynamic> toJson() => {
        'date': formatDay(date),
        if (endDate != null) 'endDate': formatDay(endDate!),
        if (isOngoing) 'isOngoing': true,
        if (description.isNotEmpty) 'description': description,
        'tags': [for (final tag in tags) tag.toJson()],
      };

  factory ExportEvent._fromJson(Object? json) {
    final map = _map(json, 'an event');
    final date = _parseDay(map['date']);
    var endDate = map['endDate'] == null ? null : _parseDay(map['endDate']);
    final isOngoing = map['isOngoing'] ?? false;
    final description = map['description'] ?? '';
    if (isOngoing is! bool) {
      throw const ExportFormatFailure('isOngoing is not a boolean');
    }
    if (description is! String) {
      throw const ExportFormatFailure('a description is not a string');
    }
    if (endDate != null && endDate.isBefore(date)) {
      throw const ExportFormatFailure('an event ends before it starts');
    }
    if (endDate != null && isOngoing) {
      throw const ExportFormatFailure('an event is both closed and ongoing');
    }
    // The backend stores an end on the start day as a single day: so does
    // the file, or an import could never recognize the event it created.
    if (endDate == date) endDate = null;

    return ExportEvent(
      date: date,
      endDate: endDate,
      isOngoing: isOngoing,
      description: description,
      tags: {
        for (final tag in map['tags'] == null
            ? const <Object?>[]
            : _list(map['tags'], 'event tags'))
          ExportTagRef._fromJson(tag)
      }.toList(),
    );
  }
}

/// `YYYY-MM-DD`: an event day is a calendar day, not an instant.
String formatDay(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);

final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime _parseDay(Object? value) {
  final match = value is String ? _dayPattern.firstMatch(value) : null;
  if (match != null) {
    final day = DateTime.utc(
        int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
    // DateTime rolls 2026-02-30 over to March: refuse it instead.
    if (formatDay(day) == value) return day;
  }
  throw ExportFormatFailure('"$value" is not a YYYY-MM-DD day');
}

Map<String, dynamic> _map(Object? json, String what) {
  if (json is Map<String, dynamic>) return json;
  throw ExportFormatFailure('$what is not an object');
}

List<Object?> _list(Object? json, String what) {
  if (json is List) return json;
  throw ExportFormatFailure('$what is not a list');
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw ExportFormatFailure('$key is not a string');
}

/// A non-blank name, trimmed.
String _name(Map<String, dynamic> map, String key) {
  final value = _string(map, key).trim();
  if (value.isEmpty) throw ExportFormatFailure('$key is blank');
  return value;
}
