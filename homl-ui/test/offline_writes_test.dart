import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/server_reachability.dart';

/// Answers the reads from the saved state and records the writes; [reachable]
/// false fails every request like a lost network.
class _Backend implements HttpClientAdapter {
  bool reachable = true;
  final List<RequestOptions> writes = [];

  List<Map<String, dynamic>> events = [
    {
      'id': 5,
      'description': 'on the server',
      'date': '2026-10-01T00:00:00Z',
      'isOngoing': false,
      'tags': [
        {'id': 10, 'tag': 'Football', 'idCategory': 3}
      ],
    }
  ];
  final categories = [
    {
      'id': 3,
      'category': 'Others',
      'kind': 'other',
      'color': '#000',
      'isLocked': true,
      'tags': [
        {'id': 10, 'tag': 'Football'}
      ],
    }
  ];

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!reachable) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'network is unreachable');
    }
    if (options.method == 'GET' && options.path.endsWith('/events')) {
      return _json(events, 200);
    }
    if (options.method == 'GET' && options.path.endsWith('/categories')) {
      return _json(categories, 200);
    }
    writes.add(options);
    if (options.method == 'POST') return _json({'id': 77}, 201);
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Backend backend;
  late Api api;
  late EventsRepository events;
  late TagsRepository tags;

  setUp(() async {
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

    backend = _Backend();
    api = Api.internal(baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = backend;
    api.accessToken = 'access';
    // The engine is not under test here: it must not send anything behind
    // the test's back.
    SyncEngine.instance = SyncEngine(api: api);
    events = EventsRepository(api: api);
    tags = TagsRepository(api: api);

    // What the device saved the last time it was online.
    await LocalStore.instance.save(StoreEntry.events, backend.events);
    await LocalStore.instance.save(StoreEntry.categories, backend.categories);
  });

  tearDown(() {
    api.dispose();
    events.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  void goOffline() {
    backend.reachable = false;
    ServerReachability.instance.markOffline();
  }

  test('online, a creation goes straight to the server with a clientId',
      () async {
    final outcome = await events.createEvent(
        description: 'direct', date: DateTime(2026, 10, 13), tagsId: [10]);

    expect(outcome, WriteOutcome.sent);
    expect(backend.writes.single.data['clientId'], isA<String>());
    expect(await Outbox.instance.ops(), isEmpty);
  });

  test('offline, a creation is kept and shown at once, marked pending',
      () async {
    goOffline();

    final outcome = await events.createEvent(
        description: 'on the train', date: DateTime(2026, 10, 13), tagsId: [10]);

    expect(outcome, WriteOutcome.queued);
    expect(backend.writes, isEmpty);
    final shown = await events.getEvents();
    expect(shown.first.description, 'on the train');
    expect(shown.first.isPending, isTrue);
    expect(shown.first.id, lessThan(0));
    expect(shown.first.tags.map((t) => t.tag), ['Football']);
    expect(shown.last.isPending, isFalse);
  });

  test('a creation whose request failed on the way is kept under the same id',
      () async {
    backend.reachable = false;

    final outcome = await events.createEvent(
        description: 'maybe sent', date: DateTime(2026, 10, 13), tagsId: [10]);

    expect(outcome, WriteOutcome.queued);
    final op = (await Outbox.instance.ops()).single;
    // The failed attempt may have reached the server: the replay must be
    // recognised as the same creation.
    expect(op.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('editing an event created offline rewrites its pending creation',
      () async {
    goOffline();
    await events.createEvent(
        description: 'typo', date: DateTime(2026, 10, 13), tagsId: [10]);
    final id = (await events.getEvents()).first.id;

    await events.updateEvent(
        id: id, description: 'fixed', date: DateTime(2026, 10, 13), tagsId: [10]);

    final ops = await Outbox.instance.ops();
    expect(ops.single.kind, OpKind.createEvent);
    expect(ops.single.body['description'], 'fixed');
  });

  test('an offline edit of a server event keeps what the server had', () async {
    goOffline();

    await events.updateEvent(
        id: 5, description: 'edited', date: DateTime(2026, 10, 1), tagsId: [10]);

    final op = (await Outbox.instance.ops()).single;
    expect(op.kind, OpKind.updateEvent);
    expect(op.base!['description'], 'on the server');
    expect((await events.getEvents()).single.description, 'edited');
  });

  test('an offline deletion hides the event at once', () async {
    goOffline();

    final outcome = await events.deleteEvent(5);

    expect(outcome, WriteOutcome.queued);
    expect(await events.getEvents(), isEmpty);
  });

  test('a tag created offline gets a temporary id, usable at once', () async {
    goOffline();

    final id = await tags.createTag('Tram', 3);

    expect(id, lessThan(0));
    final categories = await CategoriesRepository(api: api).getCategories();
    expect(categories.single.tags.map((t) => t.tag), ['Football', 'Tram']);
  });

  test('a tag not on the server yet cannot be renamed or deleted', () async {
    goOffline();
    final id = await tags.createTag('Tram', 3);

    expect(() => tags.updateTag(id, 'Bus', 3), throwsA(isA<TagPendingFailure>()));
    expect(() => tags.deleteTag(id), throwsA(isA<TagPendingFailure>()));
  });

  test('behind waiting changes, an online write waits its turn', () async {
    goOffline();
    await events.createEvent(
        description: 'first', date: DateTime(2026, 10, 13), tagsId: [10]);
    // The app thinks the server is back, but the engine has not sent
    // anything yet (its own attempt fails: the network is still down).
    ServerReachability.instance.markOnline();

    final outcome = await events.createEvent(
        description: 'second', date: DateTime(2026, 10, 14), tagsId: [10]);

    expect(outcome, WriteOutcome.queued);
    expect((await Outbox.instance.ops()).map((op) => op.body['description']),
        ['first', 'second']);
  });
}
