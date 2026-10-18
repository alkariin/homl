import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/server_reachability.dart';

/// A small stateful backend: ids, tags unique per category, date tags derived
/// from the period, creations replayed by `clientId`, and the failures a sync
/// meets (no network, a lost answer, a refusal).
class _Server implements HttpClientAdapter {
  Map<String, dynamic> settings = {
    'language': 'en',
    'defaultScreen': false,
    'isE2eeEnabled': false,
    'dataGeneration': 'gen-1',
  };

  final List<Map<String, dynamic>> categories = [
    {
      'id': 1,
      'category': 'Dates',
      'kind': 'date',
      'isLocked': true,
      'color': '#000',
      'tags': <Map<String, dynamic>>[],
      'groups': <Map<String, dynamic>>[]
    },
    {
      'id': 3,
      'category': 'Others',
      'kind': 'other',
      'isLocked': true,
      'color': '#000',
      'tags': <Map<String, dynamic>>[
        {'id': 10, 'tag': 'Football'},
      ],
      'groups': <Map<String, dynamic>>[],
    },
  ];
  final Map<String, int> categoryClientIds = {};

  final Map<int, Map<String, dynamic>> events = {};
  final Map<String, int> clientIds = {};
  final List<String> log = [];
  int _nextId = 100;

  bool offline = false;

  /// The next request whose "METHOD path" matches is applied, then its answer
  /// is lost (the connection drops on the way back).
  String? loseAnswerOf;

  /// Requests whose "METHOD path" matches are refused with this status.
  String? refuse;
  int refuseStatus = 400;

  /// Goes offline right after this many write requests went through.
  int? offlineAfterWrites;
  int _writes = 0;

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  Map<String, dynamic>? _tag(int id) {
    for (final category in categories) {
      for (final tag in category['tags'] as List) {
        if (tag['id'] == id) return {...tag, 'idCategory': category['id']};
      }
    }
    return null;
  }

  /// Plain-mode date tags: month and year of the start (enough here).
  List<Map<String, dynamic>> _dateTags(String date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final day = DateTime.parse(date);
    final dates = categories.first['tags'] as List<Map<String, dynamic>>;
    return [
      for (final name in [months[day.month - 1], '${day.year}'])
        dates.firstWhere((tag) => tag['tag'] == name, orElse: () {
          final created = {'id': _nextId++, 'tag': name};
          dates.add(created);
          return created;
        })
    ].map((tag) => {...tag, 'idCategory': 1}).toList();
  }

  Map<String, dynamic> _eventFrom(int id, Map body) => {
        'id': id,
        'description': body['description'] ?? '',
        'date': body['date'],
        'endDate': body['endDate'],
        'isOngoing': body['isOngoing'] ?? false,
        'tags': [
          for (final tagId in (body['tagsId'] as List))
            if (_tag(tagId as int) != null) _tag(tagId)!,
          ..._dateTags(body['date'] as String),
        ],
      };

  /// What another device changes directly on the server.
  void elsewhere(int id, Map<String, dynamic> changes) =>
      events[id] = {...events[id]!, ...changes};

  ResponseBody _notFound() => _json({
        'error': {'message': 'not found'}
      }, 404);

  Map<String, dynamic>? categoryById(int id) {
    for (final category in categories) {
      if (category['id'] == id) return category;
    }
    return null;
  }

  Map<String, dynamic>? _holderOf(int tagId) {
    for (final category in categories) {
      if ((category['tags'] as List).any((t) => t['id'] == tagId)) {
        return category;
      }
    }
    return null;
  }

  Map<String, dynamic>? groupById(int id) {
    for (final category in categories) {
      for (final group in category['groups'] as List) {
        if (group['id'] == id) return group as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// A category of this device's server, with [tags] (and their synonyms:
  /// a tag map may carry `idParentTag`) and [groups].
  int seedCategory(String name,
      {List<Map<String, dynamic>> tags = const [],
      List<Map<String, dynamic>> groups = const []}) {
    final id = _nextId++;
    categories.add({
      'id': id,
      'category': name,
      'color': '#f28b82',
      'kind': 'custom',
      'isLocked': false,
      'tags': [
        for (final tag in tags) {...tag}
      ],
      'groups': [
        for (final group in groups)
          {
            ...group,
            'members': [...group['members'] as List]
          }
      ],
    });
    return id;
  }

  int seedEvent(String description, String date,
      {List<int> tags = const [10]}) {
    final id = _nextId++;
    events[id] = _eventFrom(id, {
      'description': description,
      'date': date,
      'tagsId': tags,
    });
    return id;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = Uri.parse(options.path).path;
    final call = '${options.method} $path';
    if (offline) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'network is unreachable');
    }
    log.add(call);
    if (refuse != null && call.contains(refuse!)) {
      return _json({
        'error': {'message': 'Bad request'}
      }, refuseStatus);
    }

    final response = _handle(options.method, path, options.data);

    if (options.method != 'GET') {
      _writes++;
      if (offlineAfterWrites != null && _writes >= offlineAfterWrites!) {
        offline = true;
      }
    }
    if (loseAnswerOf != null && call.contains(loseAnswerOf!)) {
      loseAnswerOf = null;
      throw DioException.connectionError(
          requestOptions: options, reason: 'connection reset');
    }
    return response;
  }

  ResponseBody _handle(String method, String path, Object? data) {
    final body = data is Map ? data : const {};
    if (method == 'GET' && path.endsWith('/settings')) {
      return _json(settings, 200);
    }
    if (method == 'GET' && path.endsWith('/categories')) {
      return _json(categories, 200);
    }
    if (method == 'GET' && path.endsWith('/events')) {
      return _json(events.values.toList(), 200);
    }
    if (method == 'POST' && path.endsWith('/tags')) {
      final category =
          categories.firstWhere((c) => c['id'] == body['idCategory']);
      final tags = category['tags'] as List<Map<String, dynamic>>;
      if (tags.any((tag) => tag['tag'] == body['tag'])) {
        return _json({
          'error': {'message': 'taken', 'code': 'TAG_NAME_CONFLICT'}
        }, 409);
      }
      final id = _nextId++;
      tags.add({'id': id, 'tag': body['tag']});
      return _json({'id': id}, 201);
    }
    if (method == 'POST' && path.endsWith('/events')) {
      final clientId = body['clientId'] as String?;
      if (clientId != null && clientIds.containsKey(clientId)) {
        return _json({'id': clientIds[clientId]}, 200);
      }
      final id = _nextId++;
      events[id] = _eventFrom(id, body);
      if (clientId != null) clientIds[clientId] = id;
      return _json({'id': id}, 201);
    }
    if (method == 'POST' && path.endsWith('/categories')) {
      final clientId = body['clientId'] as String?;
      if (clientId != null && categoryClientIds.containsKey(clientId)) {
        return _json({'id': categoryClientIds[clientId]}, 200);
      }
      final id = _nextId++;
      categories.add({
        'id': id,
        'category': body['category'],
        'color': body['color'],
        'kind': 'custom',
        'isLocked': false,
        'tags': <Map<String, dynamic>>[],
        'groups': <Map<String, dynamic>>[],
      });
      if (clientId != null) categoryClientIds[clientId] = id;
      return _json({'id': id}, 201);
    }
    final category = RegExp(r'/categories/(\d+)$').firstMatch(path);
    if (category != null) {
      final id = int.parse(category.group(1)!);
      final found = categoryById(id);
      if (found == null) return _notFound();
      if (method == 'PATCH') {
        found['category'] = body['category'];
        found['color'] = body['color'];
        return ResponseBody.fromString('', 204);
      }
      if (method == 'DELETE') {
        categories.remove(found);
        final tags = found['tags'] as List<Map<String, dynamic>>;
        if (body['moveTags'] == true) {
          (categories[1]['tags'] as List).addAll(tags);
          (categories[1]['groups'] as List).addAll(found['groups'] as List);
        } else {
          final gone = {for (final tag in tags) tag['id']};
          for (final event in events.values) {
            (event['tags'] as List).removeWhere((t) => gone.contains(t['id']));
          }
        }
        return ResponseBody.fromString('', 204);
      }
    }
    final tag = RegExp(r'/tags/(\d+)$').firstMatch(path);
    if (tag != null) {
      final id = int.parse(tag.group(1)!);
      final holder = _holderOf(id);
      if (holder == null) return _notFound();
      final tags = holder['tags'] as List<Map<String, dynamic>>;
      final current = tags.firstWhere((t) => t['id'] == id);
      if (method == 'PATCH') {
        final destination = categoryById(body['idCategory'] as int)!;
        final taken = (destination['tags'] as List)
            .any((t) => t['id'] != id && t['tag'] == body['tag']);
        if (taken) {
          return _json({
            'error': {'message': 'taken', 'code': 'TAG_NAME_CONFLICT'}
          }, 409);
        }
        current['tag'] = body['tag'];
        current['idParentTag'] = body['idParentTag'];
        if (destination != holder) {
          final moving = [
            current,
            ...tags.where((t) => t['idParentTag'] == id),
          ];
          tags.removeWhere(moving.contains);
          (destination['tags'] as List).addAll(moving);
        }
        return ResponseBody.fromString('', 204);
      }
      if (method == 'DELETE') {
        final parent = current['idParentTag'] as int?;
        final gone = {
          id,
          if (parent == null)
            for (final t in tags)
              if (t['idParentTag'] == id) t['id'],
        };
        tags.removeWhere((t) => gone.contains(t['id']));
        for (final event in events.values) {
          final eventTags = event['tags'] as List;
          final had = eventTags.any((t) => t['id'] == id);
          eventTags.removeWhere((t) => gone.contains(t['id']));
          // A synonym's events go to its main tag.
          if (had &&
              parent != null &&
              !eventTags.any((t) => t['id'] == parent)) {
            eventTags.add({..._tag(parent)!});
          }
        }
        for (final group in holder['groups'] as List) {
          (group['members'] as List).removeWhere(gone.contains);
        }
        return ResponseBody.fromString('', 204);
      }
    }
    if (method == 'POST' && path.endsWith('/tagGroups')) {
      final holder = categoryById(body['idCategory'] as int)!;
      final groups = holder['groups'] as List<Map<String, dynamic>>;
      if (groups.any((g) => g['name'] == body['name'])) {
        return _json({
          'error': {'message': 'taken', 'code': 'TAG_NAME_CONFLICT'}
        }, 409);
      }
      final id = _nextId++;
      groups.add({
        'id': id,
        'name': body['name'],
        'members': [...body['members'] as List]
      });
      return _json({'id': id}, 201);
    }
    final group = RegExp(r'/tagGroups/(\d+)$').firstMatch(path);
    if (group != null) {
      final id = int.parse(group.group(1)!);
      final found = groupById(id);
      if (found == null) return _notFound();
      if (method == 'PATCH') {
        found['name'] = body['name'];
        found['members'] = [...body['members'] as List];
        return ResponseBody.fromString('', 204);
      }
      if (method == 'DELETE') {
        for (final category in categories) {
          (category['groups'] as List).remove(found);
        }
        return ResponseBody.fromString('', 204);
      }
    }
    final match = RegExp(r'/events/(\d+)$').firstMatch(path);
    if (match != null) {
      final id = int.parse(match.group(1)!);
      if (!events.containsKey(id)) {
        return _json({
          'error': {'message': 'not found'}
        }, 404);
      }
      if (method == 'PATCH') {
        events[id] = _eventFrom(id, body);
        return ResponseBody.fromString('', 204);
      }
      if (method == 'DELETE') {
        events.remove(id);
        return ResponseBody.fromString('', 204);
      }
    }
    return _json({'error': 'unexpected $method $path'}, 500);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Server server;
  late Api api;
  late SyncEngine engine;
  late List<SyncReport> reports;

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

    server = _Server();
    api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = server;
    api.accessToken = 'access';
    engine = SyncEngine(api: api);
    reports = [];
    engine.reports.listen(reports.add);
  });

  tearDown(() {
    api.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Outbox outbox() => Outbox.instance;

  Map<String, dynamic> eventBody(String description, String date,
          {List<int> tags = const [10]}) =>
      {
        'description': description,
        'date': date,
        'endDate': null,
        'isOngoing': false,
        'tagsId': tags,
      };

  Map<String, dynamic> copyOf(int id) =>
      jsonDecode(jsonEncode(server.events[id])) as Map<String, dynamic>;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a tag created offline goes first and its id replaces the temporary one',
      () async {
    final tag = await outbox().createTag({'tag': 'Tram', 'idCategory': 3});
    await outbox().createEvent(
        eventBody('ride', '2026-10-13T00:00:00.000Z', tags: [10, tag]));

    await engine.sync();
    await settle();

    final tram = (server.categories[1]['tags'] as List)
        .firstWhere((t) => t['tag'] == 'Tram')['id'] as int;
    final created = server.events.values.single;
    expect(
        (created['tags'] as List).map((t) => t['id']), containsAll([10, tram]));
    expect(await outbox().ops(), isEmpty);
    expect(reports.single.sent, 2);
  });

  test('a lost answer does not create the event twice', () async {
    await outbox().createEvent(eventBody('once', '2026-10-13T00:00:00.000Z'));
    server.loseAnswerOf = 'POST /events';

    await engine.sync();
    expect(server.events, hasLength(1), reason: 'created, answer lost');
    expect(await outbox().ops(), hasLength(1), reason: 'still to confirm');

    ServerReachability.instance.markOnline();
    await engine.sync();

    expect(server.events, hasLength(1));
    expect(await outbox().ops(), isEmpty);
  });

  test('an edit merges with what changed on another device meanwhile',
      () async {
    final id = server.seedEvent('before', '2026-10-01T00:00:00Z');
    final base = copyOf(id);
    await outbox().updateEvent(
        id, eventBody('edited here', '2026-10-01T00:00:00.000Z'),
        base: base);
    server.elsewhere(id, {'date': '2026-10-05T00:00:00Z'});

    await engine.sync();
    await settle();

    expect(server.events[id]!['description'], 'edited here');
    expect(server.events[id]!['date'], '2026-10-05T00:00:00Z');
    expect(reports.single.conflicts, 0);
  });

  test('the same field changed on both sides: this device wins, and says so',
      () async {
    final id = server.seedEvent('before', '2026-10-01T00:00:00Z');
    final base = copyOf(id);
    await outbox().updateEvent(
        id, eventBody('mine', '2026-10-01T00:00:00.000Z'),
        base: base);
    server.elsewhere(id, {'description': 'theirs'});

    await engine.sync();
    await settle();

    expect(server.events[id]!['description'], 'mine');
    expect(reports.single.conflicts, 1);
  });

  test('an edit of an event deleted elsewhere brings it back (the edit wins)',
      () async {
    final id = server.seedEvent('before', '2026-10-01T00:00:00Z');
    final base = copyOf(id);
    await outbox().updateEvent(
        id, eventBody('still wanted', '2026-10-01T00:00:00.000Z'),
        base: base);
    server.events.remove(id);

    await engine.sync();
    await settle();

    expect(server.events.values.single['description'], 'still wanted');
    expect(reports.single.restored, 1);
    expect(await outbox().ops(), isEmpty);
  });

  test('a deletion of an event edited elsewhere keeps it (the edit wins)',
      () async {
    final id = server.seedEvent('before', '2026-10-01T00:00:00Z');
    await outbox().deleteEvent(id, base: copyOf(id));
    server.elsewhere(id, {'description': 'changed elsewhere'});

    await engine.sync();
    await settle();

    expect(server.events[id]!['description'], 'changed elsewhere');
    expect(reports.single.kept, 1);
    expect(server.log, isNot(contains('DELETE /events/$id')));
  });

  test('a deletion of an untouched event deletes it', () async {
    final id = server.seedEvent('before', '2026-10-01T00:00:00Z');
    await outbox().deleteEvent(id, base: copyOf(id));

    await engine.sync();
    await settle();

    expect(server.events, isEmpty);
    expect(reports.single.sent, 1);
  });

  test('a tag that exists by now is reused, not created twice', () async {
    final tag = await outbox().createTag({'tag': 'Football', 'idCategory': 3});
    await outbox().createEvent(
        eventBody('match', '2026-10-13T00:00:00.000Z', tags: [tag]));

    await engine.sync();

    expect(server.log, isNot(contains('POST /tags')));
    expect((server.events.values.single['tags'] as List).first['id'], 10);
  });

  test('a refused op is parked with what needs it, the rest still goes',
      () async {
    final tag = await outbox().createTag({'tag': 'Tram', 'idCategory': 3});
    await outbox().createEvent(
        eventBody('ride', '2026-10-13T00:00:00.000Z', tags: [tag]));
    await outbox().createEvent(eventBody('other', '2026-10-12T00:00:00.000Z'));
    server.refuse = 'POST /tags';

    await engine.sync();
    await settle();

    final ops = await outbox().ops();
    expect(ops.map((op) => op.parked),
        [ParkReason.refused, ParkReason.missingTag]);
    expect(server.events.values.single['description'], 'other');
    expect(reports.single.parked, 2);
  });

  test('the server going away mid-way keeps what is left for next time',
      () async {
    await outbox().createEvent(eventBody('first', '2026-10-13T00:00:00.000Z'));
    await outbox().createEvent(eventBody('second', '2026-10-12T00:00:00.000Z'));
    server.offlineAfterWrites = 1;

    await engine.sync();

    expect(server.events, hasLength(1));
    final left = await outbox().ops();
    expect(left.single.body['description'], 'second');
    expect(left.single.parked, isNull);

    server.offline = false;
    server.offlineAfterWrites = null;
    ServerReachability.instance.markOnline();
    await engine.sync();
    expect(server.events, hasLength(2));
    expect(await outbox().ops(), isEmpty);
  });

  test('ops written for another encryption are held back', () async {
    await outbox().createEvent(eventBody('plain', '2026-10-13T00:00:00.000Z'));
    server.settings = {
      ...server.settings,
      'isE2eeEnabled': true,
      'e2eeKeyCheck': 'a-new-key',
    };

    await engine.sync();

    expect(server.events, isEmpty);
    expect((await outbox().ops()).single.parked, ParkReason.encryptionChanged);
  });

  test('ops written before the server data was replaced are held back',
      () async {
    await outbox().createEvent(
        eventBody('before the restore', '2026-10-13T00:00:00.000Z'),
        generation: 'gen-0');

    await engine.sync();

    expect(server.events, isEmpty);
    expect((await outbox().ops()).single.parked, ParkReason.dataReplaced);
  });

  test('nothing to send, nothing asked', () async {
    await engine.sync();
    expect(server.log, isEmpty);
    expect(reports, isEmpty);
  });

  group('tags, categories and groups', () {
    List<Map<String, dynamic>> tagsOf(int category) =>
        (server.categoryById(category)!['tags'] as List)
            .cast<Map<String, dynamic>>();
    int idOf(int category, String name) =>
        tagsOf(category).firstWhere((t) => t['tag'] == name)['id'] as int;

    test('a category created offline, a tag in it and an event with it',
        () async {
      final trips = await outbox()
          .createCategory({'category': 'Trips', 'color': '#a7ffeb'});
      final tram =
          await outbox().createTag({'tag': 'Tram', 'idCategory': trips});
      await outbox().createEvent(
          eventBody('ride', '2026-10-13T00:00:00.000Z', tags: [tram]));

      await engine.sync();
      await settle();

      final created = server.categories.last;
      expect(created['category'], 'Trips');
      final tramId = idOf(created['id'] as int, 'Tram');
      expect((server.events.values.single['tags'] as List).map((t) => t['id']),
          contains(tramId));
      expect(await outbox().ops(), isEmpty);
      expect(reports.single.sent, 3);
    });

    test('a category create replayed after a lost answer makes one', () async {
      await outbox().createCategory({'category': 'Trips', 'color': '#a7ffeb'});
      server.loseAnswerOf = 'POST /categories';

      await engine.sync();
      ServerReachability.instance.markOnline();
      await engine.sync();

      expect(server.categories.where((c) => c['category'] == 'Trips'),
          hasLength(1));
      expect(await outbox().ops(), isEmpty);
    });

    test('a category edit merges with a color changed elsewhere', () async {
      final id = server.seedCategory('Trips');
      final base = {'category': 'Trips', 'color': '#f28b82', 'tags': []};
      await outbox().updateCategory(
          id, {'category': 'Travels', 'color': '#f28b82'},
          base: base);
      server.categoryById(id)!['color'] = '#000000';

      await engine.sync();
      await settle();

      expect(server.categoryById(id)!['category'], 'Travels');
      expect(server.categoryById(id)!['color'], '#000000');
      expect(reports.single.conflicts, 0);
    });

    test('the same name changed on both sides: this device wins', () async {
      final id = server.seedCategory('Trips');
      await outbox().updateCategory(
          id, {'category': 'Travels', 'color': '#f28b82'},
          base: {'category': 'Trips', 'color': '#f28b82', 'tags': []});
      server.categoryById(id)!['category'] = 'Journeys';

      await engine.sync();
      await settle();

      expect(server.categoryById(id)!['category'], 'Travels');
      expect(reports.single.conflicts, 1);
    });

    test('an edit of something deleted elsewhere is dropped', () async {
      final category = server.seedCategory('Trips', tags: [
        {'id': 60, 'tag': 'Tram'},
      ], groups: [
        {
          'id': 70,
          'name': 'Rails',
          'members': [60]
        },
      ]);
      await outbox().updateCategory(category, {
        'category': 'Travels',
        'color': '#f28b82'
      }, base: {
        'category': 'Trips',
        'color': '#f28b82',
        'tags': [60]
      });
      await outbox().updateTag(60, {'tag': 'Bus', 'idCategory': category},
          base: {'tag': 'Tram', 'idCategory': category, 'idParentTag': null});
      await outbox().updateGroup(70, {
        'name': 'Rails',
        'members': [60]
      }, base: {
        'name': 'Rails',
        'members': [60],
        'idCategory': category
      });
      server.categories.remove(server.categoryById(category));
      server.log.clear();

      await engine.sync();
      await settle();

      expect(server.log.where((call) => !call.startsWith('GET')), isEmpty);
      expect(await outbox().ops(), isEmpty);
      expect(reports.single.dropped, 3);
    });

    test('a deletion of something edited elsewhere keeps it', () async {
      final renamed = server.seedCategory('Trips');
      final grown = server.seedCategory('Work', tags: [
        {'id': 61, 'tag': 'Office'},
      ]);
      await outbox().deleteCategory(renamed, {'moveTags': false},
          base: {'category': 'Trips', 'color': '#f28b82', 'tags': []});
      // A tag this device never showed was added there meanwhile.
      await outbox().deleteCategory(grown, {'moveTags': false},
          base: {'category': 'Work', 'color': '#f28b82', 'tags': []});
      server.categoryById(renamed)!['category'] = 'Journeys';

      await engine.sync();
      await settle();

      expect(server.categoryById(renamed), isNotNull);
      expect(server.categoryById(grown), isNotNull);
      expect(reports.single.kept, 2);
    });

    test('an untouched category is deleted, its tags moved as asked', () async {
      final id = server.seedCategory('Trips', tags: [
        {'id': 62, 'tag': 'Tram'},
      ]);
      await outbox().deleteCategory(id, {
        'moveTags': true
      }, base: {
        'category': 'Trips',
        'color': '#f28b82',
        'tags': [62]
      });

      await engine.sync();
      await settle();

      expect(server.categoryById(id), isNull);
      expect(tagsOf(3).map((t) => t['tag']), contains('Tram'));
      final call = server.log.firstWhere((c) => c.startsWith('DELETE'));
      expect(call, 'DELETE /categories/$id');
    });

    test('a tag rename merges with a move made elsewhere', () async {
      final persons = server.seedCategory('Persons', tags: [
        {'id': 63, 'tag': 'Ally'},
      ]);
      await outbox().updateTag(
          63, {'tag': 'Alice', 'idCategory': persons, 'idParentTag': null},
          base: {'tag': 'Ally', 'idCategory': persons, 'idParentTag': null});
      // Moved to Others on another device.
      final moving = tagsOf(persons).single;
      tagsOf(persons).clear();
      tagsOf(3).add(moving);

      await engine.sync();
      await settle();

      expect(tagsOf(3).map((t) => t['tag']), contains('Alice'));
      expect(tagsOf(persons), isEmpty);
      expect(reports.single.conflicts, 0);
    });

    test('a rename onto a name taken meanwhile is parked', () async {
      tagsOf(3).add({'id': 64, 'tag': 'Tram'});
      await outbox().updateTag(
          64, {'tag': 'Football', 'idCategory': 3, 'idParentTag': null},
          base: {'tag': 'Tram', 'idCategory': 3, 'idParentTag': null});

      await engine.sync();
      await settle();

      expect((await outbox().ops()).single.parked, ParkReason.refused);
      expect(reports.single.parked, 1);
    });

    test('a move into a category deleted elsewhere is parked', () async {
      final gone = server.seedCategory('Trips');
      tagsOf(3).add({'id': 65, 'tag': 'Tram'});
      await outbox().updateTag(
          65, {'tag': 'Tram', 'idCategory': gone, 'idParentTag': null},
          base: {'tag': 'Tram', 'idCategory': 3, 'idParentTag': null});
      server.categories.remove(server.categoryById(gone));

      await engine.sync();
      await settle();

      expect((await outbox().ops()).single.parked, ParkReason.refused);
    });

    test('a deleted tag is gone from what is sent after it', () async {
      tagsOf(3).add({'id': 66, 'tag': 'Tram'});
      final ride =
          server.seedEvent('ride', '2026-10-01T00:00:00Z', tags: [10, 66]);
      await outbox().deleteTag(66, {'idParentTag': null},
          base: {'tag': 'Tram', 'idCategory': 3, 'idParentTag': null});
      // Then edited here: its body still names the deleted tag.
      await outbox().updateEvent(ride,
          eventBody('ride home', '2026-10-01T00:00:00.000Z', tags: [10, 66]),
          base: copyOf(ride));

      await engine.sync();
      await settle();

      expect(tagsOf(3).map((t) => t['id']), isNot(contains(66)));
      final event = server.events[ride]!;
      expect(event['description'], 'ride home');
      expect((event['tags'] as List).map((t) => t['id']), isNot(contains(66)));
      expect(await outbox().ops(), isEmpty);
    });

    test('a tag deletion is never sent with its events', () async {
      tagsOf(3).add({'id': 67, 'tag': 'Tram'});
      await outbox().deleteTag(67, {'idParentTag': null},
          base: {'tag': 'Tram', 'idCategory': 3, 'idParentTag': null});
      Object? sent;
      server.log.clear();
      api.api.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
        if (options.method == 'DELETE') sent = options.data;
        h.next(options);
      }));

      await engine.sync();

      expect(sent, {'deleteEvents': false});
    });

    test('a group of a tag created offline gets the tag id', () async {
      final persons = server.seedCategory('Persons', tags: [
        {'id': 68, 'tag': 'Alice'},
      ]);
      final bob =
          await outbox().createTag({'tag': 'Bob', 'idCategory': persons});
      await outbox().createGroup({
        'name': 'Family',
        'idCategory': persons,
        'members': [68, bob]
      });

      await engine.sync();
      await settle();

      final group = (server.categoryById(persons)!['groups'] as List).single;
      expect(group['members'], [68, idOf(persons, 'Bob')]);
      expect(await outbox().ops(), isEmpty);
    });

    test('a group whose name exists by now is reused, not created twice',
        () async {
      final persons = server.seedCategory('Persons', tags: [
        {'id': 69, 'tag': 'Alice'},
      ], groups: [
        {
          'id': 71,
          'name': 'Family',
          'members': [69]
        },
      ]);
      await outbox().createGroup({
        'name': 'Family',
        'idCategory': persons,
        'members': [69]
      });

      await engine.sync();
      await settle();

      expect(server.categoryById(persons)!['groups'] as List, hasLength(1));
      expect(server.log.where((call) => call.startsWith('POST')), isEmpty);
    });

    test('a group edit keeps only the members still there', () async {
      final persons = server.seedCategory('Persons', tags: [
        {'id': 72, 'tag': 'Alice'},
        {'id': 73, 'tag': 'Bob'},
      ], groups: [
        {
          'id': 74,
          'name': 'Family',
          'members': [72]
        },
      ]);
      await outbox().updateGroup(74, {
        'name': 'Family',
        'members': [72, 73]
      }, base: {
        'name': 'Family',
        'members': [72],
        'idCategory': persons
      });
      tagsOf(persons).removeWhere((t) => t['id'] == 73);

      await engine.sync();
      await settle();

      expect(server.groupById(74)!['members'], [72]);
    });

    test('a group deletion keeps a group edited elsewhere', () async {
      final persons = server.seedCategory('Persons', tags: [
        {'id': 75, 'tag': 'Alice'},
      ], groups: [
        {
          'id': 76,
          'name': 'Family',
          'members': [75]
        },
      ]);
      await outbox().deleteGroup(76, base: {
        'name': 'Family',
        'members': [75],
        'idCategory': persons
      });
      server.groupById(76)!['name'] = 'Kin';

      await engine.sync();
      await settle();

      expect(server.groupById(76), isNotNull);
      expect(reports.single.kept, 1);
    });

    test('a change of something whose creation was discarded is parked',
        () async {
      final trips =
          await outbox().createCategory({'category': 'Trips', 'color': '#fff'});
      await outbox().deleteCategory(trips, {'moveTags': false});
      // The creation goes, the deletion of it stays behind.
      final ops = await outbox().ops();
      await outbox().park(ops.first, ParkReason.refused);

      await engine.sync();
      await settle();

      expect((await outbox().ops()).map((op) => op.parked),
          [ParkReason.refused, ParkReason.refused]);
      expect(server.log.where((call) => !call.startsWith('GET')), isEmpty);
    });
  });
}
