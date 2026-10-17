import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/data_transfer.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/data/transfer/export_seal.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/server_reachability.dart';

/// A small stateful backend: categories, tags (unique per category) and
/// events, created through the same routes as the app's. Like the real one,
/// it attaches a year tag to every event it creates for a plain account.
class _Server implements HttpClientAdapter {
  bool reachable = true;

  /// Writes answered before the connection drops.
  int? dropAfterWrites;

  /// Tag names refused like reserved names.
  Set<String> refusedTags = {};

  bool e2ee = false;
  int _nextId = 100;
  final List<Map<String, dynamic>> writes = [];

  final List<Map<String, dynamic>> categories = [
    {
      'id': 1,
      'category': 'Dates',
      'color': '#ffff60',
      'isLocked': true,
      'kind': 'date',
      'tags': [
        {'id': 2, 'tag': '2026', 'idParentTag': null}
      ],
    },
    {
      'id': 3,
      'category': 'Persons',
      'color': '#60ccff',
      'isLocked': false,
      'kind': 'person',
      'tags': <Map<String, dynamic>>[],
    },
    {
      'id': 4,
      'category': 'Others',
      'color': '#999999',
      'isLocked': true,
      'kind': 'other',
      'tags': [
        {'id': 5, 'tag': 'Football', 'idParentTag': null}
      ],
    },
  ];
  final List<Map<String, dynamic>> events = [];

  Map<String, dynamic>? _tag(int id) {
    for (final category in categories) {
      for (final tag in category['tags'] as List) {
        if (tag['id'] == id) return {...tag, 'idCategory': category['id']};
      }
    }
    return null;
  }

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  ResponseBody _error(int status, [String? code]) => _json({
        'error': {'message': 'refused', if (code != null) 'code': code}
      }, status);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (dropAfterWrites != null &&
        options.method != 'GET' &&
        writes.length >= dropAfterWrites!) {
      reachable = false;
    }
    if (!reachable) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'network is unreachable');
    }
    if (options.method == 'GET' && options.path.endsWith('/events')) {
      // Newest first, like the backend.
      return _json(events.reversed.toList(), 200);
    }
    if (options.method == 'GET' && options.path.endsWith('/categories')) {
      return _json(categories, 200);
    }

    final body = Map<String, dynamic>.from(options.data as Map);
    writes.add({'method': options.method, 'path': options.path, ...body});
    final id = _nextId++;

    if (options.path.endsWith('/categories')) {
      categories.add({
        'id': id,
        'category': body['category'],
        'color': body['color'],
        'isLocked': false,
        'kind': 'custom',
        'tags': <Map<String, dynamic>>[],
      });
      return _json({'id': id}, 201);
    }

    if (options.path.endsWith('/tags')) {
      final name = body['tag'] as String;
      if (refusedTags.contains(name)) return _error(422);
      final category =
          categories.firstWhere((c) => c['id'] == body['idCategory']);
      final tags = category['tags'] as List;
      final key = body['tagIndex'] ?? name.toLowerCase();
      if (tags.any((t) => (t['tagIndex'] ?? t['tag'].toLowerCase()) == key)) {
        return _error(409, 'TAG_NAME_CONFLICT');
      }
      tags.add({
        'id': id,
        'tag': name,
        'idParentTag': body['idParentTag'],
        if (body['tagIndex'] != null) 'tagIndex': body['tagIndex'],
      });
      return _json({'id': id}, 201);
    }

    if (options.path.endsWith('/tagGroups')) {
      final category =
          categories.firstWhere((c) => c['id'] == body['idCategory']);
      final groups = (category['groups'] ??= <Map<String, dynamic>>[]) as List;
      final key = body['nameIndex'] ?? (body['name'] as String).toLowerCase();
      if (groups
          .any((g) => (g['nameIndex'] ?? g['name'].toLowerCase()) == key)) {
        return _error(409, 'TAG_NAME_CONFLICT');
      }
      groups.add({
        'id': id,
        'name': body['name'],
        'members': body['members'],
        if (body['nameIndex'] != null) 'nameIndex': body['nameIndex'],
      });
      return _json({'id': id}, 201);
    }

    if (options.path.endsWith('/events')) {
      final tagIds = [
        ...(body['tagsId'] as List).cast<int>(),
        if (!e2ee) 2,
      ];
      events.add({
        'id': id,
        'description': body['description'] ?? '',
        'date': body['date'],
        'endDate': body['endDate'],
        'isOngoing': body['isOngoing'] ?? false,
        'tags': [for (final tagId in tagIds.toSet()) _tag(tagId)],
      });
      return _json({'id': id}, 201);
    }
    return _error(404);
  }

  @override
  void close({bool force = false}) {}
}

/// Persons with Alice (alias Ali) and Bob, a Work category, Football in the
/// Others bucket, and three events — one of them twice.
ExportFile _file() => ExportFile.fromJson({
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
            },
            {'name': 'Bob'},
          ],
        },
        {
          'name': 'Work',
          'kind': 'custom',
          'color': '#ff8800',
          'tags': [
            {'name': 'Acme'}
          ],
        },
        {
          'name': 'Others',
          'kind': 'other',
          'color': '#999999',
          'tags': [
            {'name': 'Football'}
          ],
        },
      ],
      'events': [
        {
          'date': '2026-07-05',
          'endDate': '2026-07-09',
          'description': 'holidays',
          'tags': [
            {'category': 'Persons', 'tag': 'Ali'},
            {'category': 'Others', 'tag': 'Football'},
          ],
        },
        {
          'date': '2026-08-01',
          'tags': [
            {'category': 'Work', 'tag': 'Acme'}
          ],
        },
        {
          'date': '2026-08-01',
          'tags': [
            {'category': 'Work', 'tag': 'Acme'}
          ],
        },
        {
          'date': '2026-09-01',
          'isOngoing': true,
          'description': 'new job',
          'tags': [
            {'category': 'Persons', 'tag': 'Bob'}
          ],
        },
      ],
    });

/// Persons with Alice (alias Ali) and Bob, and two groups: Family names the
/// synonym Ali, which stands for Alice; Friends is already in the account in
/// some tests.
ExportFile _fileWithGroups() => ExportFile.fromJson({
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
            },
            {'name': 'Bob'},
          ],
          'groups': [
            {
              'name': 'Family',
              'tags': ['Ali', 'Bob']
            },
            {
              'name': 'Friends',
              'tags': ['Bob']
            },
          ],
        },
      ],
      'events': [],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Server server;
  late Api api;
  late EventsRepository events;
  late DataTransferRepository repository;

  setUp(() {
    storage = {'refreshToken': 'stored-refresh'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      switch (call.method) {
        case 'read':
          return storage[args!['key'] as String];
        case 'write':
          storage[args!['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          storage.remove(args!['key'] as String);
          return null;
      }
      return null;
    });
    ServerReachability.instance.reset();
    LocalStore.instance = LocalStore.inMemory();
    Outbox.resetForTesting();
    E2ee().lock();

    server = _Server();
    api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = server;
    api.accessToken = 'access';
    // Nothing must be sent behind the test's back.
    SyncEngine.instance = SyncEngine(api: api);
    events = EventsRepository(api: api);
    repository = DataTransferRepository(
        categoriesRepository: CategoriesRepository(api: api),
        tagsRepository: TagsRepository(api: api),
        eventsRepository: events);
  });

  tearDown(() {
    E2ee().lock();
    api.dispose();
    events.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  List<Map<String, dynamic>> tagsOf(String name) =>
      (server.categories.firstWhere((c) => c['category'] == name)['tags']
              as List)
          .cast<Map<String, dynamic>>();

  group('import', () {
    test('creates what is missing and matches the rest', () async {
      final report = await repository.import(_file());

      // Persons and Others are the account's own; Work is new.
      expect(server.categories.map((c) => c['category']),
          ['Dates', 'Persons', 'Others', 'Work']);
      expect(server.categories.last['color'], '#ff8800');
      // Football already lived in Others: not created again.
      expect(tagsOf('Others').map((t) => t['tag']), ['Football']);
      // Ali is a synonym of Alice.
      final alice = tagsOf('Persons').firstWhere((t) => t['tag'] == 'Alice');
      final ali = tagsOf('Persons').firstWhere((t) => t['tag'] == 'Ali');
      expect(ali['idParentTag'], alice['id']);

      expect(server.events, hasLength(4));
      final holidays = server.events.first;
      expect(holidays['description'], 'holidays');
      expect(holidays['date'], '2026-07-05T00:00:00.000Z');
      expect(holidays['endDate'], '2026-07-09T00:00:00.000Z');
      expect((holidays['tags'] as List).map((t) => t['tag']),
          containsAll(['Ali', 'Football']));
      expect(server.events.last['isOngoing'], isTrue);

      expect(report.categoriesCreated, 1);
      expect(report.tagsCreated, 4); // Alice, Ali, Bob, Acme
      expect(report.eventsCreated, 4);
      expect(report.eventsExisting, 0);
      expect(report.skipped, 0);
    });

    test('importing the same file again changes nothing', () async {
      await repository.import(_file());
      final writes = server.writes.length;

      final report = await repository.import(_file());

      expect(server.writes, hasLength(writes));
      expect(report.changedAnything, isFalse);
      // The twin events count one copy each.
      expect(report.eventsExisting, 4);
    });

    test('matches names without minding the case', () async {
      tagsOf('Persons').add({'id': 50, 'tag': 'Alice', 'idParentTag': null});
      server.categories.add({
        'id': 51,
        'category': 'work',
        'color': '#000000',
        'isLocked': false,
        'kind': 'custom',
        'tags': [
          {'id': 52, 'tag': 'ACME', 'idParentTag': null}
        ],
      });

      final report = await repository.import(_file());

      expect(report.categoriesCreated, 0);
      expect(report.tagsCreated, 2); // Ali (under the existing Alice), Bob
      expect(
          tagsOf('Persons').firstWhere((t) => t['tag'] == 'Ali')['idParentTag'],
          50);
    });

    test('a file without kinds still finds Others and leaves Dates out',
        () async {
      final report = await repository.import(ExportFile.fromJson({
        'format': 'homl-export',
        'version': 1,
        'exportedAt': '2026-10-17T10:00:00.000Z',
        'categories': [
          {
            'name': 'others',
            'color': '#999999',
            'tags': [
              {'name': 'Chess'}
            ],
          },
          {
            'name': 'Dates',
            'color': '#ffff60',
            'tags': [
              {'name': 'July'}
            ],
          },
        ],
        'events': [
          {
            'date': '2026-07-05',
            'tags': [
              {'category': 'others', 'tag': 'Chess'},
              {'category': 'Dates', 'tag': 'July'},
            ],
          },
        ],
      }));

      expect(report.categoriesCreated, 0);
      expect(tagsOf('Others').map((t) => t['tag']), ['Football', 'Chess']);
      expect(
          server.events.single['tags'].map((t) => t['tag']), ['Chess', '2026']);
    });

    test('leaves out what the server refuses and goes on', () async {
      server.refusedTags = {'Acme'};

      final report = await repository.import(_file());

      expect(report.skipped, 1);
      // The two Acme events are imported without it (date tag only).
      expect(report.eventsCreated, 4);
      expect(server.events[1]['tags'].map((t) => t['tag']), ['2026']);
    });

    test('creates the groups of the file with their tags', () async {
      final report = await repository.import(_fileWithGroups());

      final persons =
          server.categories.firstWhere((c) => c['category'] == 'Persons');
      final alice = tagsOf('Persons').firstWhere((t) => t['tag'] == 'Alice');
      final bob = tagsOf('Persons').firstWhere((t) => t['tag'] == 'Bob');
      final groups = (persons['groups'] as List).cast<Map<String, dynamic>>();
      expect(groups.map((g) => g['name']), ['Family', 'Friends']);
      // Ali is a synonym: the group holds its main tag.
      expect(groups.first['members'], [alice['id'], bob['id']]);
      expect(report.groupsCreated, 2);
      expect(report.changedAnything, isTrue);

      // A second run finds them and writes nothing.
      final writes = server.writes.length;
      final again = await repository.import(_fileWithGroups());
      expect(server.writes, hasLength(writes));
      expect(again.groupsCreated, 0);
    });

    test('leaves a group of the account as it is', () async {
      tagsOf('Persons').add({'id': 60, 'tag': 'Carol', 'idParentTag': null});
      server.categories[1]['groups'] = <Map<String, dynamic>>[
        {
          'id': 61,
          'name': 'friends',
          'members': [60]
        }
      ];

      final report = await repository.import(_fileWithGroups());

      final groups =
          (server.categories[1]['groups'] as List).cast<Map<String, dynamic>>();
      expect(groups.map((g) => g['name']), ['friends', 'Family']);
      expect(groups.first['members'], [60]);
      expect(report.groupsCreated, 1);
    });

    test('a group whose tags were all refused is left out', () async {
      server.refusedTags = {'Bob'};

      final report = await repository.import(_fileWithGroups());

      final groups =
          (server.categories[1]['groups'] as List).cast<Map<String, dynamic>>();
      // Family keeps Alice; Friends had only Bob.
      expect(groups.map((g) => g['name']), ['Family']);
      expect(report.groupsCreated, 1);
      expect(report.skipped, 2); // Bob, Friends
    });

    test('counts the groups in the progress', () async {
      final steps = <int>[];
      await repository.import(_fileWithGroups(), onProgress: (done, total) {
        expect(total, 5); // 3 tags + 2 groups
        steps.add(done);
      });
      expect(steps.last, 5);
    });

    test('reports the progress up to the total', () async {
      final steps = <int>[];
      await repository.import(_file(), onProgress: (done, total) {
        expect(total, 9); // 5 tags + 4 events
        steps.add(done);
      });
      expect(steps.first, 0);
      expect(steps.last, 9);
    });

    test('tells the app once, at the end', () async {
      var notified = 0;
      final subscription = events.changes.listen((_) => notified++);
      await repository.import(_file());
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(notified, 1);
    });

    test('does not start offline', () async {
      ServerReachability.instance.markOffline();
      await expectLater(
          repository.import(_file()),
          throwsA(isA<ImportUnavailableFailure>()
              .having((f) => f.pendingChanges, 'pendingChanges', isFalse)));
      expect(server.writes, isEmpty);
    });

    test('does not start while offline changes wait', () async {
      await Outbox.instance.createTag({'tag': 'Queued', 'idCategory': 4});
      await expectLater(
          repository.import(_file()),
          throwsA(isA<ImportUnavailableFailure>()
              .having((f) => f.pendingChanges, 'pendingChanges', isTrue)));
      expect(server.writes, isEmpty);
    });

    test('a dropped connection stops it, and a second run finishes it',
        () async {
      server.dropAfterWrites = 6; // Work, 4 tags, then the first event
      await expectLater(
          repository.import(_file()), throwsA(isA<ImportInterruptedFailure>()));
      expect(server.events, hasLength(1));
      // At most the write that hit the drop waits in the outbox.
      expect((await Outbox.instance.ops()).length, lessThanOrEqualTo(1));

      // Back online, the write kept on the device dropped (sent or not, the
      // second run finishes the job): run it again.
      await Outbox.instance.discardAll();
      server
        ..dropAfterWrites = null
        ..reachable = true;
      ServerReachability.instance.reset();
      final report = await repository.import(_file());

      expect(server.events, hasLength(4));
      expect(report.eventsExisting, 1);
      expect(report.eventsCreated, 3);
      expect(report.categoriesCreated, 0);
    });
  });

  group('export', () {
    test('a file exported then imported elsewhere brings everything', () async {
      await repository.import(_file());
      final bytes = await repository.export();
      final exported = await repository.read(bytes);

      expect(exported.categories.map((c) => c.name),
          ['Persons', 'Others', 'Work']);
      expect(exported.events, hasLength(4));
      expect(exported.events.first.description, 'holidays');
      // The year tag the server added is not in the file.
      expect(
          exported.events
              .expand((e) => e.tags)
              .map((t) => t.tag)
              .contains('2026'),
          isFalse);
      expect(jsonDecode(utf8.decode(bytes))['format'], 'homl-export');
    });

    test('a password seals the file, and reading needs it', () async {
      final bytes =
          await repository.export(password: 'long enough', iterations: 1000);

      expect(utf8.decode(bytes), isNot(contains('Persons')));
      await expectLater(repository.read(bytes),
          throwsA(isA<ExportPasswordRequiredFailure>()));
      await expectLater(repository.read(bytes, password: 'not it'),
          throwsA(isA<ExportPasswordFailure>()));
      final file = await repository.read(bytes, password: 'long enough');
      expect(file.categories.map((c) => c.name), contains('Persons'));
    });

    test('reading something else is a format failure', () async {
      await expectLater(
          repository.read(Uint8List.fromList(utf8.encode('not json'))),
          throwsA(isA<ExportFormatFailure>()));
      await expectLater(
          repository.read(Uint8List.fromList(utf8.encode('{"a": 1}'))),
          throwsA(isA<ExportFormatFailure>()));
    });
  });

  group('E2EE account', () {
    setUp(() async {
      await E2ee().prepareEnable();
      await E2ee().commitEnable();
      server.e2ee = true;
    });

    test('the import encrypts like any write and attaches the date tags',
        () async {
      await repository.import(_file());

      final work = server.categories.last;
      expect(work['category'], startsWith(E2ee.prefix));
      final acme = (work['tags'] as List).single;
      expect(acme['tag'], startsWith(E2ee.prefix));
      expect(acme['tagIndex'], await E2ee().tagIndex('Acme'));
      expect(server.events.first['description'], startsWith(E2ee.prefix));

      // The client attached the date tags of the period: 2026 existed (id
      // 2), July was created, encrypted like any tag.
      final julyIndex = await E2ee().tagIndex('July');
      final july =
          tagsOf('Dates').singleWhere((t) => t['tagIndex'] == julyIndex);
      expect(july['tag'], startsWith(E2ee.prefix));
      final holidayTags =
          (server.events.first['tags'] as List).map((t) => t['id']);
      expect(holidayTags, containsAll([2, july['id']]));
      // Ongoing for the open period.
      final ongoingIndex = await E2ee().tagIndex('Ongoing');
      expect(tagsOf('Dates').where((t) => t['tagIndex'] == ongoingIndex),
          hasLength(1));
    });

    test('the group names are encrypted and indexed', () async {
      await repository.import(_fileWithGroups());

      final groups =
          (server.categories[1]['groups'] as List).cast<Map<String, dynamic>>();
      expect(groups.first['name'], startsWith(E2ee.prefix));
      expect(await E2ee().decrypt(groups.first['name'] as String), 'Family');
      expect(groups.first['nameIndex'], await E2ee().tagIndex('Family'));

      // Recognized by their index on a second run.
      final writes = server.writes.length;
      await repository.import(_fileWithGroups());
      expect(server.writes, hasLength(writes));
    });

    test('a second import recognizes the encrypted events', () async {
      await repository.import(_file());
      final writes = server.writes.length;

      final report = await repository.import(_file());

      expect(server.writes, hasLength(writes));
      expect(report.eventsExisting, 4);
    });

    test('the export holds the data in clear unless sealed', () async {
      await repository.import(_file());

      final file = await repository.read(await repository.export());
      expect(file.categories.map((c) => c.name), contains('Work'));
      expect(file.events.first.description, 'holidays');

      final sealed =
          await repository.export(password: 'long enough', iterations: 1000);
      expect(utf8.decode(sealed), isNot(contains('holidays')));
    });
  });
}
