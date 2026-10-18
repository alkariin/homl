import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/date_tags.dart';

/// The server payloads with the waiting changes of the outbox applied, so the
/// screens show what was done offline as if the server had it already. Works
/// on the wire format (ciphertext for an E2EE account): the repositories
/// decrypt the result as they decrypt a server payload.

Map<String, dynamic> _copy(Object? json) =>
    Map<String, dynamic>.from(json as Map);

List<Map<String, dynamic>> _list(Map<String, dynamic> category, String key) =>
    (category[key] as List).cast<Map<String, dynamic>>();

/// [categories] with the category, tag and group changes made offline, the
/// way the server applies them (homl-web/docs/tag-groups.md, "Lifecycle").
List<Map<String, dynamic>> projectCategories(
    List<dynamic> categories, List<OutboxOp> ops) {
  final projected = [
    for (final category in categories)
      {
        ..._copy(category),
        'tags': [
          for (final tag in ((category as Map)['tags'] as List?) ?? const [])
            _copy(tag)
        ],
        'groups': [
          for (final group in (category['groups'] as List?) ?? const [])
            {
              ..._copy(group),
              'members': [...((group as Map)['members'] as List? ?? const [])],
            }
        ],
      }
  ];

  Map<String, dynamic>? categoryOf(Object? id) {
    for (final category in projected) {
      if (category['id'] == id) return category;
    }
    return null;
  }

  for (final op in ops) {
    switch (op.kind) {
      case OpKind.createCategory:
        projected.add({
          'id': op.target,
          'category': op.body['category'],
          'color': op.body['color'],
          'isLocked': false,
          'kind': 'custom',
          'tags': <Map<String, dynamic>>[],
          'groups': <Map<String, dynamic>>[],
        });
      case OpKind.updateCategory:
        final category = categoryOf(op.target);
        if (category == null) break;
        category['category'] = op.body['category'];
        category['color'] = op.body['color'];
      case OpKind.deleteCategory:
        final category = categoryOf(op.target);
        if (category == null) break;
        projected.remove(category);
        if (op.body['moveTags'] != true) break;
        // The tags (synonym links intact) and the groups go to Others.
        Map<String, dynamic>? others;
        for (final candidate in projected) {
          if (candidate['kind'] == 'other') others = candidate;
        }
        if (others == null) break;
        for (final tag in _list(category, 'tags')) {
          _list(others, 'tags').add({...tag, 'idCategory': others['id']});
        }
        _list(others, 'groups').addAll(_list(category, 'groups'));
      case OpKind.createTag:
        final category = categoryOf(op.body['idCategory']);
        if (category == null) break;
        _list(category, 'tags').add({
          'id': op.target,
          'tag': op.body['tag'],
          'idCategory': category['id'],
          if (op.body['idParentTag'] != null)
            'idParentTag': op.body['idParentTag'],
          if (op.body['tagIndex'] != null) 'tagIndex': op.body['tagIndex'],
        });
      case OpKind.updateTag:
        _updateTag(projected, op.target, op.body, categoryOf);
      case OpKind.deleteTag:
        _deleteTag(projected, op.target);
      case OpKind.createGroup:
        final category = categoryOf(op.body['idCategory']);
        if (category == null) break;
        _list(category, 'groups').add({
          'id': op.target,
          'name': op.body['name'],
          'members': [...(op.body['members'] as List? ?? const [])],
          if (op.body['nameIndex'] != null) 'nameIndex': op.body['nameIndex'],
        });
      case OpKind.updateGroup:
        final group = _findGroup(projected, op.target);
        if (group == null) break;
        group['name'] = op.body['name'];
        group['members'] = [...(op.body['members'] as List? ?? const [])];
        if (op.body['nameIndex'] != null) {
          group['nameIndex'] = op.body['nameIndex'];
        }
      case OpKind.deleteGroup:
        for (final category in projected) {
          _list(category, 'groups')
              .removeWhere((group) => group['id'] == op.target);
        }
      case OpKind.createEvent:
      case OpKind.updateEvent:
      case OpKind.deleteEvent:
        break;
    }
  }
  return projected;
}

(Map<String, dynamic>, Map<String, dynamic>)? _findTag(
    List<Map<String, dynamic>> categories, int id) {
  for (final category in categories) {
    for (final tag in _list(category, 'tags')) {
      if (tag['id'] == id) return (category, tag);
    }
  }
  return null;
}

Map<String, dynamic>? _findGroup(
    List<Map<String, dynamic>> categories, int id) {
  for (final category in categories) {
    for (final group in _list(category, 'groups')) {
      if (group['id'] == id) return group;
    }
  }
  return null;
}

/// Replaces [from] by [to] in the members of [category]'s groups (a member
/// turned synonym hands its place to its main tag), or drops it when [to]
/// is null (a member moved out or deleted). No duplicates.
void _replaceMember(Map<String, dynamic> category, int from, int? to) {
  for (final group in _list(category, 'groups')) {
    final members = (group['members'] as List).cast<int>();
    if (!members.contains(from)) continue;
    group['members'] = [
      for (final id in members)
        if (id != from) id else if (to != null && !members.contains(to)) to,
    ];
  }
}

/// A rename, a move (a main tag takes its synonyms along) or a synonym
/// link change, with the groups following their members.
void _updateTag(
    List<Map<String, dynamic>> categories,
    int id,
    Map<String, dynamic> body,
    Map<String, dynamic>? Function(Object? id) categoryOf) {
  final found = _findTag(categories, id);
  if (found == null) return;
  final (from, tag) = found;
  final destination = categoryOf(body['idCategory']) ?? from;
  final parent = body['idParentTag'] as int?;

  tag['tag'] = body['tag'];
  if (body['tagIndex'] != null) tag['tagIndex'] = body['tagIndex'];
  tag['idParentTag'] = parent;

  if (destination != from) {
    final moving = [
      tag,
      if (parent == null)
        ..._list(from, 'tags').where((other) => other['idParentTag'] == id),
    ];
    _list(from, 'tags').removeWhere(moving.contains);
    for (final moved in moving) {
      moved['idCategory'] = destination['id'];
      _list(destination, 'tags').add(moved);
      _replaceMember(from, moved['id'] as int, null);
    }
  }
  if (parent != null) _replaceMember(destination, id, parent);
}

/// A synonym goes alone; a main tag takes its synonyms along. They leave
/// their groups.
void _deleteTag(List<Map<String, dynamic>> categories, int id) {
  final found = _findTag(categories, id);
  if (found == null) return;
  final (category, tag) = found;
  final gone = {
    id,
    if (tag['idParentTag'] == null)
      for (final other in _list(category, 'tags'))
        if (other['idParentTag'] == id) other['id'] as int,
  };
  _list(category, 'tags').removeWhere((other) => gone.contains(other['id']));
  for (final member in gone) {
    _replaceMember(category, member, null);
  }
}

/// [events] with the creations, edits and deletions made offline, in the
/// server's order (latest day first, latest created first), and every tag as
/// the projected [categories] have it now: renamed, moved, a deleted synonym
/// replaced by its main tag, a deleted tag gone. [serverCategories]: the
/// categories as the server sent them — a tag counts as deleted only when
/// they had it and the projection removed it; one they do not know (a saved
/// copy missing or older than the events) is shown as the event carries it.
/// [clientDateTags]: the account is end-to-end encrypted, so the date tags
/// are among the event's own tag ids; otherwise the server derives them from
/// the period and the projection does the same, so a month search finds the
/// event offline too.
List<Map<String, dynamic>> projectEvents(List<dynamic> events,
    List<Map<String, dynamic>> categories, List<OutboxOp> ops,
    {required bool clientDateTags, List<dynamic> serverCategories = const []}) {
  if (ops.isEmpty) return [for (final event in events) _copy(event)];

  final serverTagIds = {
    for (final category in serverCategories)
      for (final tag in ((category as Map)['tags'] as List?) ?? const [])
        (tag as Map)['id'],
  };

  final tagsById = <int, Map<String, dynamic>>{};
  Map<String, dynamic>? dateCategory;
  for (final category in categories) {
    if (category['kind'] == 'date') dateCategory = category;
    for (final tag in category['tags'] as List) {
      final copy = _copy(tag);
      copy['idCategory'] ??= category['id'];
      tagsById[copy['id'] as int] = copy;
    }
  }

  // A deleted synonym hands its events to its main tag.
  final repoint = <int, int>{
    for (final op in ops)
      if (op.kind == OpKind.deleteTag && op.body['idParentTag'] is int)
        op.target: op.body['idParentTag'] as int,
  };

  List<Map<String, dynamic>> current(List<dynamic> tags) {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final tag in tags.cast<Map>()) {
      final id = tag['id'] as int;
      if (id == -1) {
        // A date tag the server creates with the event.
        result.add(_copy(tag));
        continue;
      }
      final now = tagsById[repoint[id] ?? id];
      if (now != null) {
        if (seen.add(now['id'] as int)) result.add(now);
      } else if (!serverTagIds.contains(id) && seen.add(id)) {
        // Unknown to the saved categories: shown as the event carries it.
        result.add(_copy(tag));
      }
    }
    return result;
  }

  List<Map<String, dynamic>> dateTags(Map<String, dynamic> body) {
    if (clientDateTags || dateCategory == null) return const [];
    final names = periodDateTagNames(
        date: DateTime.parse(body['date'] as String),
        endDate: body['endDate'] == null
            ? null
            : DateTime.parse(body['endDate'] as String),
        isOngoing: body['isOngoing'] == true);
    final existing = [
      for (final tag in dateCategory['tags'] as List) _copy(tag),
    ];
    return [
      for (final name in names)
        existing.firstWhere(
            (tag) => (tag['tag'] as String).toLowerCase() == name.toLowerCase(),
            // Not on the server yet: it will create it with the event.
            orElse: () => {'id': -1, 'tag': name})
          ..['idCategory'] = dateCategory['id'],
    ];
  }

  Map<String, dynamic> eventFrom(int id, Map<String, dynamic> body) => {
        'id': id,
        'description': body['description'] ?? '',
        'date': body['date'],
        'endDate': body['endDate'],
        'isOngoing': body['isOngoing'] ?? false,
        'tags': [
          for (final tagId in ((body['tagsId'] as List?) ?? const []))
            if (tagsById[tagId] != null) tagsById[tagId]!,
          ...dateTags(body),
        ],
        'pending': true,
      };

  final byId = <int, Map<String, dynamic>>{
    for (final event in events) (event as Map)['id'] as int: _copy(event),
  };
  for (final op in ops) {
    switch (op.kind) {
      case OpKind.createEvent:
      case OpKind.updateEvent:
        // An event deleted elsewhere and edited here shows too: the edit
        // wins, the event is created again when sent.
        byId[op.target] = eventFrom(op.target, op.body);
      case OpKind.deleteEvent:
        byId.remove(op.target);
      default:
        break;
    }
  }
  for (final event in byId.values) {
    event['tags'] = current(event['tags'] as List? ?? const []);
  }

  final projected = byId.values.toList()
    ..sort((a, b) {
      final byDate = DateTime.parse(b['date'] as String)
          .compareTo(DateTime.parse(a['date'] as String));
      if (byDate != 0) return byDate;
      final idA = a['id'] as int, idB = b['id'] as int;
      // Created offline first (the later, the more negative), then the
      // server's latest first.
      if ((idA < 0) != (idB < 0)) return idA < 0 ? -1 : 1;
      return idA < 0 ? idA.compareTo(idB) : idB.compareTo(idA);
    });
  return projected;
}
