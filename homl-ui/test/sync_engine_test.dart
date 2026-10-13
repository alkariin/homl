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
    {'id': 1, 'category': 'Dates', 'kind': 'date', 'isLocked': true, 'color': '#000', 'tags': <Map<String, dynamic>>[]},
    {
      'id': 3,
      'category': 'Others',
      'kind': 'other',
      'isLocked': true,
      'color': '#000',
      'tags': <Map<String, dynamic>>[
        {'id': 10, 'tag': 'Football'},
      ],
    },
  ];

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
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
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

  int seedEvent(String description, String date, {List<int> tags = const [10]}) {
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
      final category = categories.firstWhere((c) => c['id'] == body['idCategory']);
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
    api = Api.internal(baseUrlOverride: 'https://api.test', initFromStorage: false);
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
    expect((created['tags'] as List).map((t) => t['id']),
        containsAll([10, tram]));
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
    await outbox().createEvent(eventBody('before the restore',
        '2026-10-13T00:00:00.000Z'), generation: 'gen-0');

    await engine.sync();

    expect(server.events, isEmpty);
    expect((await outbox().ops()).single.parked, ParkReason.dataReplaced);
  });

  test('nothing to send, nothing asked', () async {
    await engine.sync();
    expect(server.log, isEmpty);
    expect(reports, isEmpty);
  });
}
