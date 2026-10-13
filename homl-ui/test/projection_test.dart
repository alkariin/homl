import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/projection.dart';

void main() {
  final categories = [
    {
      'id': 1,
      'category': 'Dates',
      'kind': 'date',
      'tags': [
        {'id': 50, 'tag': 'October'},
        {'id': 51, 'tag': '2026'},
      ],
    },
    {
      'id': 3,
      'category': 'Others',
      'kind': 'other',
      'tags': [
        {'id': 10, 'tag': 'Football'},
      ],
    },
  ];

  final events = [
    {
      'id': 5,
      'description': 'match',
      'date': '2026-10-13T00:00:00Z',
      'isOngoing': false,
      'tags': [
        {'id': 10, 'tag': 'Football', 'idCategory': 3},
      ],
    },
    {
      'id': 4,
      'description': 'older',
      'date': '2026-10-01T00:00:00Z',
      'isOngoing': false,
      'tags': [],
    },
  ];

  OutboxOp op(OpKind kind, int target, [Map<String, dynamic> body = const {}]) =>
      OutboxOp(id: newClientId(), kind: kind, target: target, body: body);

  Map<String, dynamic> body(String description, String date,
          {List<int> tags = const [10]}) =>
      {
        'description': description,
        'date': date,
        'endDate': null,
        'isOngoing': false,
        'tagsId': tags,
      };

  test('without waiting changes the server payload is unchanged', () {
    final projected = projectEvents(events, [], [], clientDateTags: false);
    expect(projected, events);
  });

  test('an event created offline comes first on its day, with its tags',
      () {
    final ops = [op(OpKind.createEvent, -2, body('new', '2026-10-13T00:00:00.000Z'))];
    final projected = projectEvents(
        events, projectCategories(categories, ops), ops,
        clientDateTags: false);

    expect(projected.map((e) => e['id']), [-2, 5, 4]);
    final created = projected.first;
    expect(created['pending'], isTrue);
    // Its own tag, then the date tags the server would derive: the existing
    // ones, and a placeholder for one it would create.
    expect((created['tags'] as List).map((t) => t['tag']),
        ['Football', 'October', '2026']);
  });

  test('a month the server has no tag for yet shows as a placeholder', () {
    final ops = [op(OpKind.createEvent, -2, body('new', '2026-11-02T00:00:00.000Z'))];
    final projected = projectEvents(
        events, projectCategories(categories, ops), ops,
        clientDateTags: false);

    final tags = (projected.first['tags'] as List).cast<Map>();
    expect(tags.map((t) => t['tag']), ['Football', 'November', '2026']);
    expect(tags[1]['id'], -1);
    expect(tags[1]['idCategory'], 1);
  });

  test('an encrypted account carries its date tags itself', () {
    final ops = [
      op(OpKind.createEvent, -2,
          body('new', '2026-10-13T00:00:00.000Z', tags: [10, 50]))
    ];
    final projected = projectEvents(
        events, projectCategories(categories, ops), ops,
        clientDateTags: true);

    expect((projected.first['tags'] as List).map((t) => t['id']), [10, 50]);
  });

  test('edits replace, deletions remove', () {
    final ops = [
      op(OpKind.updateEvent, 4, body('edited', '2026-10-01T00:00:00Z')),
      op(OpKind.deleteEvent, 5),
    ];
    final projected =
        projectEvents(events, categories, ops, clientDateTags: true);

    expect(projected.map((e) => e['id']), [4]);
    expect(projected.single['description'], 'edited');
    expect(projected.single['pending'], isTrue);
  });

  test('an edit of an event deleted elsewhere still shows (the edit wins)',
      () {
    final ops = [op(OpKind.updateEvent, 99, body('mine', '2026-09-01T00:00:00Z'))];
    final projected =
        projectEvents(events, categories, ops, clientDateTags: true);

    expect(projected.map((e) => e['id']), [5, 4, 99]);
  });

  test('a tag created offline shows in its category and on its events', () {
    final ops = [
      op(OpKind.createTag, -3, {'tag': 'Tram', 'idCategory': 3}),
      op(OpKind.createEvent, -4,
          body('ride', '2026-10-13T00:00:00.000Z', tags: [-3])),
    ];
    final projectedCategories = projectCategories(categories, ops);

    expect((projectedCategories[1]['tags'] as List).last,
        {'id': -3, 'tag': 'Tram', 'idCategory': 3});
    expect(categories[1]['tags'], hasLength(1), reason: 'input untouched');

    final projected = projectEvents(events, projectedCategories, ops,
        clientDateTags: true);
    expect((projected.first['tags'] as List).single['tag'], 'Tram');
  });
}
