import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/date_tags.dart';

/// The server payloads with the waiting changes of the outbox applied, so the
/// screens show what was done offline as if the server had it already. Works
/// on the wire format (ciphertext for an E2EE account): the repositories
/// decrypt the result as they decrypt a server payload.

Map<String, dynamic> _copy(Object? json) =>
    Map<String, dynamic>.from(json as Map);

/// [categories] with the tags created offline in their category.
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
      }
  ];
  for (final op in ops) {
    if (op.kind != OpKind.createTag) continue;
    final idCategory = op.body['idCategory'];
    for (final category in projected) {
      if (category['id'] != idCategory) continue;
      (category['tags'] as List).add({
        'id': op.target,
        'tag': op.body['tag'],
        'idCategory': idCategory,
        if (op.body['idParentTag'] != null)
          'idParentTag': op.body['idParentTag'],
      });
    }
  }
  return projected;
}

/// [events] with the creations, edits and deletions made offline, in the
/// server's order (latest day first, latest created first). [categories]: the
/// projected categories, to turn tag ids back into tags. [clientDateTags]:
/// the account is end-to-end encrypted, so the date tags are among the
/// event's own tag ids; otherwise the server derives them from the period
/// and the projection does the same, so a month search finds the event
/// offline too.
List<Map<String, dynamic>> projectEvents(List<dynamic> events,
    List<Map<String, dynamic>> categories, List<OutboxOp> ops,
    {required bool clientDateTags}) {
  if (ops.isEmpty) return [for (final event in events) _copy(event)];

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
      case OpKind.createTag:
        break;
    }
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
