import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/tag_group.dart';
import 'package:homl/data/transfer/export_file.dart';

final _categories = [
  Category(
      id: 1,
      category: 'Dates',
      color: '#ffff60',
      isLocked: true,
      kind: CategoryKind.date,
      tags: [
        Tag(id: 2, tag: '2026', idCategory: 1),
        Tag(id: 3, tag: 'July', idCategory: 1),
      ]),
  Category(
      id: 4,
      category: 'Persons',
      color: '#60ccff',
      isLocked: false,
      kind: CategoryKind.person,
      tags: [
        Tag(id: 5, tag: 'Alice', idCategory: 4),
        Tag(id: 6, tag: 'Ali', idCategory: 4, idParentTag: 5),
        Tag(id: 7, tag: 'Bob', idCategory: 4),
      ]),
  Category(
      id: 8,
      category: 'Others',
      color: '#999999',
      isLocked: true,
      kind: CategoryKind.other,
      tags: [Tag(id: 9, tag: 'Football', idCategory: 8)]),
];

Event _event(int id, DateTime date, List<Tag> tags,
        {String description = '', DateTime? endDate, bool isOngoing = false}) =>
    Event(
        id: id,
        description: description,
        date: date,
        endDate: endDate,
        isOngoing: isOngoing,
        tags: tags);

/// A valid file as JSON, for the parser tests to break one field at a time.
Map<String, dynamic> _validJson() => {
      'format': 'homl-export',
      'version': 1,
      'exportedAt': '2026-10-17T10:00:00.000Z',
      'categories': [
        {
          'name': 'Persons',
          'kind': 'person',
          'color': '#60ccff',
          'tags': [
            {
              'name': 'Alice',
              'synonyms': ['Ali']
            }
          ],
        }
      ],
      'events': [
        {
          'date': '2026-07-05',
          'tags': [
            {'category': 'Persons', 'tag': 'Ali'}
          ],
        }
      ],
    };

void main() {
  group('building the file from the app data', () {
    test('leaves the date category out and groups the synonyms', () {
      final file = ExportFile.fromData(_categories, const [],
          exportedAt: DateTime.utc(2026, 10, 17));

      expect(file.categories.map((c) => c.name), ['Persons', 'Others']);
      final persons = file.categories.first;
      expect(persons.kind, 'person');
      expect(persons.color, '#60ccff');
      expect(persons.tags.map((t) => t.name), ['Alice', 'Bob']);
      expect(persons.tags.first.synonyms, ['Ali']);
      expect(file.tagCount, 4);
    });

    test('events point at tags by name, without the date tags', () {
      final file = ExportFile.fromData(
          _categories,
          [
            _event(1, DateTime.utc(2026, 7, 5), [
              Tag(id: 6, tag: 'Ali', idCategory: 4),
              Tag(id: 9, tag: 'Football', idCategory: 8),
              Tag(id: 2, tag: '2026', idCategory: 1),
              Tag(id: 3, tag: 'July', idCategory: 1),
            ]),
          ],
          exportedAt: DateTime.utc(2026, 10, 17));

      final json = file.events.single.toJson();
      expect(json['tags'], [
        {'category': 'Persons', 'tag': 'Ali'},
        {'category': 'Others', 'tag': 'Football'},
      ]);
    });

    test('writes the events oldest first, same-day creation order kept', () {
      final tag = [Tag(id: 7, tag: 'Bob', idCategory: 4)];
      // GET /events order: newest day first, last created first.
      final file = ExportFile.fromData(
          _categories,
          [
            _event(4, DateTime.utc(2026, 8, 1), tag, description: 'august'),
            _event(3, DateTime.utc(2026, 7, 5), tag, description: 'second'),
            _event(2, DateTime.utc(2026, 7, 5), tag, description: 'first'),
            _event(1, DateTime.utc(2025, 1, 1), tag, description: 'oldest'),
          ],
          exportedAt: DateTime.utc(2026, 10, 17));

      expect(file.events.map((e) => e.description),
          ['oldest', 'first', 'second', 'august']);
    });

    test('keeps the period of each event', () {
      final file = ExportFile.fromData(
          _categories,
          [
            _event(2, DateTime.utc(2026, 9, 1), const [], isOngoing: true),
            _event(1, DateTime.utc(2026, 7, 5), const [],
                endDate: DateTime.utc(2026, 7, 9), description: 'holidays'),
          ],
          exportedAt: DateTime.utc(2026, 10, 17));

      expect(file.events.map((e) => e.toJson()), [
        {
          'date': '2026-07-05',
          'endDate': '2026-07-09',
          'description': 'holidays',
          'tags': <Object>[],
        },
        {'date': '2026-09-01', 'isOngoing': true, 'tags': <Object>[]},
      ]);
    });
  });

  group('reading a file', () {
    test('reads back what was written', () {
      final written = ExportFile.fromData(
          _categories,
          [
            _event(
                1,
                DateTime.utc(2026, 7, 5),
                [
                  Tag(id: 6, tag: 'Ali', idCategory: 4),
                ],
                description: 'café ☕',
                endDate: DateTime.utc(2026, 7, 9)),
          ],
          exportedAt: DateTime.utc(2026, 10, 17, 10));

      final read = ExportFile.fromJson(written.toJson());

      expect(read.toJson(), written.toJson());
      expect(read.exportedAt, DateTime.utc(2026, 10, 17, 10));
      expect(read.events.single.endDate, DateTime.utc(2026, 7, 9));
    });

    test('accepts a minimal file and trims the names', () {
      final json = _validJson();
      (json['categories'] as List).first['name'] = '  Persons ';
      final file = ExportFile.fromJson(json);

      expect(file.categories.single.name, 'Persons');
      expect(file.events.single.description, '');
      expect(file.events.single.isOngoing, isFalse);
    });

    test('matches the event tags without minding the case', () {
      final json = _validJson();
      (json['events'] as List).first['tags'] = [
        {'category': 'PERSONS', 'tag': 'ali'}
      ];
      expect(() => ExportFile.fromJson(json), returnsNormally);
    });

    test('stores an end on the start day as a single day', () {
      final json = _validJson();
      (json['events'] as List).first['endDate'] = '2026-07-05';
      expect(ExportFile.fromJson(json).events.single.endDate, isNull);
    });

    test('says a newer format apart from a broken file', () {
      final json = _validJson()..['version'] = 2;
      expect(() => ExportFile.fromJson(json),
          throwsA(isA<ExportVersionFailure>()));
    });

    final broken = <String, void Function(Map<String, dynamic>)>{
      'another format': (json) => json['format'] = 'something-else',
      'no version': (json) => json.remove('version'),
      'a bad export date': (json) => json['exportedAt'] = 'yesterday',
      'a bad color': (json) =>
          (json['categories'] as List).first['color'] = 'blue',
      'a blank tag name': (json) =>
          ((json['categories'] as List).first['tags'] as List)
            ..first['name'] = '  ',
      'a bad day': (json) =>
          (json['events'] as List).first['date'] = '2026-02-30',
      'an end before the start': (json) =>
          (json['events'] as List).first['endDate'] = '2026-07-01',
      'an end on an ongoing event': (json) => (json['events'] as List).first
        ..['endDate'] = '2026-07-09'
        ..['isOngoing'] = true,
      'a tag no category lists': (json) =>
          (json['events'] as List).first['tags'] = [
            {'category': 'Persons', 'tag': 'Carol'}
          ],
      'a category no one created': (json) =>
          (json['events'] as List).first['tags'] = [
            {'category': 'Work', 'tag': 'Ali'}
          ],
      'a group tag its category does not list': (json) =>
          (json['categories'] as List).first['groups'] = [
            {
              'name': 'Family',
              'tags': ['Alice', 'Carol']
            }
          ],
      'a group without tags': (json) =>
          (json['categories'] as List).first['groups'] = [
            {'name': 'Family', 'tags': []}
          ],
      'a blank group name': (json) =>
          (json['categories'] as List).first['groups'] = [
            {
              'name': ' ',
              'tags': ['Alice']
            }
          ],
    };
    for (final entry in broken.entries) {
      test('refuses a file with ${entry.key}', () {
        final json = _validJson();
        entry.value(json);
        expect(() => ExportFile.fromJson(json),
            throwsA(isA<ExportFormatFailure>()));
      });
    }

    test('refuses something that is not an object', () {
      expect(() => ExportFile.fromJson([1, 2]),
          throwsA(isA<ExportFormatFailure>()));
    });
  });

  group('tag groups', () {
    final persons = _categories[1];
    final withGroups = [
      _categories[0],
      Category(
          id: persons.id,
          category: persons.category,
          color: persons.color,
          isLocked: persons.isLocked,
          kind: persons.kind,
          tags: persons.tags,
          groups: [
            TagGroup(id: 1, name: 'Family', members: [5, 7]),
            // Its only tag was deleted: nothing to keep.
            TagGroup(id: 2, name: 'Gone', members: [99]),
          ]),
      _categories[2],
    ];

    test('are written by tag name, an empty one left out', () {
      final file = ExportFile.fromData(withGroups, const [],
          exportedAt: DateTime.utc(2026, 10, 17));
      final json = file.toJson();

      final personsJson = (json['categories'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['name'] == 'Persons');
      expect(personsJson['groups'], [
        {
          'name': 'Family',
          'tags': ['Alice', 'Bob']
        }
      ]);
      expect(file.groupCount, 1);
      // A category without groups writes no key at all.
      expect(
          (json['categories'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((c) => c['name'] == 'Others')
              .containsKey('groups'),
          isFalse);
    });

    test('are read back, a synonym being a fine group tag', () {
      final json = _validJson();
      (json['categories'] as List).first['groups'] = [
        {
          'name': 'Family',
          'tags': ['ali', 'Alice']
        }
      ];

      final group = ExportFile.fromJson(json).categories.first.groups.single;

      expect(group.name, 'Family');
      expect(group.tags, ['ali', 'Alice']);
    });
  });
}
