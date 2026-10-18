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

  OutboxOp op(OpKind kind, int target,
          [Map<String, dynamic> body = const {}]) =>
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

  test('an event created offline comes first on its day, with its tags', () {
    final ops = [
      op(OpKind.createEvent, -2, body('new', '2026-10-13T00:00:00.000Z'))
    ];
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
    final ops = [
      op(OpKind.createEvent, -2, body('new', '2026-11-02T00:00:00.000Z'))
    ];
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

  test('an edit of an event deleted elsewhere still shows (the edit wins)', () {
    final ops = [
      op(OpKind.updateEvent, 99, body('mine', '2026-09-01T00:00:00Z'))
    ];
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

    final projected =
        projectEvents(events, projectedCategories, ops, clientDateTags: true);
    expect((projected.first['tags'] as List).single['tag'], 'Tram');
  });

  group('tags, categories and groups', () {
    // Persons (2): Alice (20) with her synonym Ally (21), Bob (22), the
    // group Family = Alice + Bob. Others (3): Football (10).
    final managed = [
      categories[0],
      {
        'id': 2,
        'category': 'Persons',
        'color': '#f28b82',
        'kind': 'person',
        'tags': [
          {'id': 20, 'tag': 'Alice'},
          {'id': 21, 'tag': 'Ally', 'idParentTag': 20},
          {'id': 22, 'tag': 'Bob'},
        ],
        'groups': [
          {
            'id': 30,
            'name': 'Family',
            'members': [20, 22]
          },
        ],
      },
      {...categories[1], 'groups': []},
    ];
    final withPeople = [
      {
        'id': 6,
        'description': 'dinner',
        'date': '2026-10-02T00:00:00Z',
        'isOngoing': false,
        'tags': [
          {'id': 21, 'tag': 'Ally', 'idCategory': 2, 'idParentTag': 20},
          {'id': 22, 'tag': 'Bob', 'idCategory': 2},
          {'id': 50, 'tag': 'October', 'idCategory': 1},
        ],
      },
    ];

    Map<String, dynamic> named(List<Map<String, dynamic>> projected, int id) =>
        projected.firstWhere((category) => category['id'] == id);
    List<String> tagNames(Map<String, dynamic> category) =>
        [for (final tag in category['tags'] as List) (tag as Map)['tag']];
    List<Object?> eventTags(List<Map<String, dynamic>> events) =>
        [for (final tag in events.single['tags'] as List) (tag as Map)['tag']];

    test('a category created, edited and deleted offline', () {
      final created = projectCategories(managed, [
        op(OpKind.createCategory, -2,
            {'category': 'Trips', 'color': '#ffffff'}),
        op(OpKind.updateCategory, 2,
            {'category': 'People', 'color': '#000000'}),
      ]);
      expect(named(created, -2)['kind'], 'custom');
      expect(named(created, -2)['tags'], isEmpty);
      expect(named(created, 2)['category'], 'People');

      final deleted = projectCategories(managed, [
        op(OpKind.deleteCategory, 2, {'moveTags': false})
      ]);
      expect(deleted.map((category) => category['id']), [1, 3]);
    });

    test('deleting a category moving its tags hands them to Others', () {
      final projected = projectCategories(managed, [
        op(OpKind.deleteCategory, 2, {'moveTags': true})
      ]);

      final others = named(projected, 3);
      expect(tagNames(others), ['Football', 'Alice', 'Ally', 'Bob']);
      expect((others['groups'] as List).single['name'], 'Family');
      expect((others['tags'] as List).last['idCategory'], 3);
    });

    test('a renamed tag is renamed on its events too', () {
      final ops = [
        op(OpKind.updateTag, 22, {'tag': 'Robert', 'idCategory': 2})
      ];
      final projected = projectCategories(managed, ops);

      expect(tagNames(named(projected, 2)), ['Alice', 'Ally', 'Robert']);
      expect(
          eventTags(projectEvents(withPeople, projected, ops,
              clientDateTags: false, serverCategories: managed)),
          ['Ally', 'Robert', 'October']);
    });

    test('a main tag moves with its synonyms and leaves its groups', () {
      final ops = [
        op(OpKind.updateTag, 20, {'tag': 'Alice', 'idCategory': 3})
      ];
      final projected = projectCategories(managed, ops);

      expect(tagNames(named(projected, 2)), ['Bob']);
      expect(tagNames(named(projected, 3)), ['Football', 'Alice', 'Ally']);
      expect((named(projected, 2)['groups'] as List).single['members'], [22]);
      final event = projectEvents(withPeople, projected, ops,
              clientDateTags: false, serverCategories: managed)
          .single;
      expect((event['tags'] as List).first['idCategory'], 3);
    });

    test('a member turned synonym hands its group place to its main tag', () {
      final projected = projectCategories(managed, [
        op(OpKind.updateTag, 22,
            {'tag': 'Bob', 'idCategory': 2, 'idParentTag': 20}),
      ]);

      // Alice is already a member: no duplicate.
      expect((named(projected, 2)['groups'] as List).single['members'], [20]);
    });

    test('a deleted synonym hands its events to its main tag', () {
      final ops = [
        op(OpKind.deleteTag, 21, {'idParentTag': 20})
      ];
      final projected = projectCategories(managed, ops);

      expect(tagNames(named(projected, 2)), ['Alice', 'Bob']);
      expect(
          eventTags(projectEvents(withPeople, projected, ops,
              clientDateTags: false, serverCategories: managed)),
          ['Alice', 'Bob', 'October']);
    });

    test('a deleted main tag takes its synonyms and leaves the events', () {
      final ops = [
        op(OpKind.deleteTag, 20, {'idParentTag': null})
      ];
      final projected = projectCategories(managed, ops);

      expect(tagNames(named(projected, 2)), ['Bob']);
      expect((named(projected, 2)['groups'] as List).single['members'], [22]);
      expect(
          eventTags(projectEvents(withPeople, projected, ops,
              clientDateTags: false, serverCategories: managed)),
          ['Bob', 'October']);
    });

    test('groups created, edited and deleted offline', () {
      final projected = projectCategories(managed, [
        op(OpKind.createGroup, -3, {
          'name': 'Friends',
          'idCategory': 2,
          'members': [22]
        }),
        op(OpKind.updateGroup, 30, {
          'name': 'Kin',
          'members': [20]
        }),
      ]);
      final groups = named(projected, 2)['groups'] as List;
      expect(groups.map((group) => (group as Map)['name']), ['Kin', 'Friends']);
      expect(groups.first['members'], [20]);

      final deleted = projectCategories(managed, [op(OpKind.deleteGroup, 30)]);
      expect(named(deleted, 2)['groups'], isEmpty);
    });

    test('a tag created in a category created offline shows in it', () {
      final projected = projectCategories(managed, [
        op(OpKind.createCategory, -2,
            {'category': 'Trips', 'color': '#ffffff'}),
        op(OpKind.createTag, -3, {'tag': 'Tram', 'idCategory': -2}),
      ]);

      expect(tagNames(named(projected, -2)), ['Tram']);
    });

    test('a tag the saved categories never had stays on its event', () {
      final ops = [
        op(OpKind.deleteTag, 20, {'idParentTag': null})
      ];
      final unknown = [
        {
          ...withPeople.single,
          'tags': [
            {'id': 99, 'tag': 'Newer', 'idCategory': 2},
          ],
        },
      ];

      expect(
          eventTags(projectEvents(unknown, projectCategories(managed, ops), ops,
              clientDateTags: false, serverCategories: managed)),
          ['Newer']);
    });

    test('the server payload itself is never changed', () {
      projectCategories(managed, [
        op(OpKind.updateTag, 22, {'tag': 'Robert', 'idCategory': 2}),
        op(OpKind.deleteGroup, 30),
      ]);

      expect(((managed[1]['tags'] as List)[2] as Map)['tag'], 'Bob');
      expect(managed[1]['groups'] as List, hasLength(1));
    });
  });
}
