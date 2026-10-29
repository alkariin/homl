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

  /// Reads go through, writes fail like a dropped connection.
  bool failWrites = false;
  final List<RequestOptions> failedWrites = [];

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
    if (failWrites) {
      failedWrites.add(options);
      throw DioException.connectionError(
          requestOptions: options, reason: 'connection reset');
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

  test('a tag not on the server yet can be renamed: its creation carries it',
      () async {
    goOffline();
    final id = await tags.createTag('Tram', 3);

    expect(await tags.updateTag(id, 'Bus', 3), WriteOutcome.queued);

    final op = (await Outbox.instance.ops()).single;
    expect(op.kind, OpKind.createTag);
    expect(op.body['tag'], 'Bus');
    final categories = await CategoriesRepository(api: api).getCategories();
    expect(categories.single.tags.map((t) => t.tag), ['Football', 'Bus']);
  });

  test('a tag not on the server yet can be deleted: created, then deleted',
      () async {
    goOffline();
    final id = await tags.createTag('Tram', 3);

    expect(await tags.deleteTag(id), WriteOutcome.queued);

    expect((await Outbox.instance.ops()).map((op) => op.kind),
        [OpKind.createTag, OpKind.deleteTag]);
    final categories = await CategoriesRepository(api: api).getCategories();
    expect(categories.single.tags.map((t) => t.tag), ['Football']);
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

  group('tags, categories and groups offline', () {
    late CategoriesRepository categories;
    setUp(() => categories = CategoriesRepository(api: api));

    test('a category created offline shows at once, a tag can go in it',
        () async {
      goOffline();

      final id = await categories.createCategory('Trips', '#a7ffeb');
      final tram = await tags.createTag('Tram', id);

      expect(id, lessThan(0));
      expect(tram, lessThan(0));
      final shown = await categories.getCategories();
      expect(shown.last.category, 'Trips');
      expect(shown.last.tags.single.tag, 'Tram');
      final ops = await Outbox.instance.ops();
      expect(ops.first.kind, OpKind.createCategory);
      expect(ops.last.body['idCategory'], id);
    });

    test('a category created offline shows in its stored casing', () async {
      goOffline();

      await categories.createCategory('family trips', '#a7ffeb');

      expect((await categories.getCategories()).last.category, 'Family Trips');
    });

    test('a tag created offline, then moved into a category created since',
        () async {
      goOffline();
      final rugby = await tags.createTag('Rugby', 3);
      await events.createEvent(
          description: 'match', date: DateTime(2026, 10, 20), tagsId: [rugby]);

      final sports = await categories.createCategory('Sports', '#ccff90');
      expect(await tags.updateTag(rugby, 'Rugby', sports), WriteOutcome.queued);

      final shown = await categories.getCategories();
      expect(shown.firstWhere((c) => c.id == sports).tags.map((t) => t.tag),
          ['Rugby']);
      expect(shown.firstWhere((c) => c.id == 3).tags.map((t) => t.tag),
          isNot(contains('Rugby')));
      final match = (await events.getEvents())
          .firstWhere((event) => event.description == 'match');
      expect(match.tags.map((t) => t.tag), ['Rugby']);
    });

    test('a category created online carries a clientId', () async {
      await categories.createCategory('Trips', '#a7ffeb');

      final body = backend.writes.single.data as Map;
      expect(body['clientId'], isA<String>());
      expect(await Outbox.instance.ops(), isEmpty);
    });

    test('a category the server could not get waits with the same clientId',
        () async {
      // Reachable for the reads, gone for the write: the creation is queued
      // under the id the direct attempt used (its answer may be lost).
      backend.failWrites = true;

      final id = await categories.createCategory('Trips', '#a7ffeb');

      expect(id, lessThan(0));
      final op = (await Outbox.instance.ops()).single;
      expect(op.id, (backend.failedWrites.single.data as Map)['clientId']);
    });

    test('a tag renamed offline is renamed on its events, with its base',
        () async {
      goOffline();

      expect(await tags.updateTag(10, 'Soccer', 3), WriteOutcome.queued);

      final op = (await Outbox.instance.ops()).single;
      expect(op.base, {'tag': 'Football', 'idCategory': 3, 'idParentTag': null});
      final shown = await events.getEvents();
      expect(shown.single.tags.single.tag, 'Soccer');
    });

    test('a deletion with its events cannot wait as it is', () async {
      goOffline();

      await expectLater(tags.deleteTag(10, deleteEvents: true),
          throwsA(isA<DeleteEventsOfflineFailure>()));
      await expectLater(
          categories.deleteCategory(3, deleteEvents: true),
          throwsA(isA<DeleteEventsOfflineFailure>()));
      expect(await Outbox.instance.ops(), isEmpty);

      // Moving the tags deletes nothing: it waits as it is.
      expect(await categories.deleteCategory(3, moveTags: true),
          WriteOutcome.queued);
    });

    test('a tag deleted offline leaves its events', () async {
      goOffline();

      expect(await tags.deleteTag(10), WriteOutcome.queued);

      final shown = await events.getEvents();
      expect(shown.single.description, 'on the server');
      expect(shown.single.tags, isEmpty);
      expect((await categories.getCategories()).single.tags, isEmpty);
    });

    test('groups wait offline, members created offline included', () async {
      goOffline();
      final tram = await tags.createTag('Tram', 3);

      final group = await categories.createTagGroup('Rails', 3, [10, tram]);
      expect(group, lessThan(0));
      expect(await categories.updateTagGroup(group, 'Trains', [tram]),
          WriteOutcome.queued);

      final ops = await Outbox.instance.ops();
      expect(ops.map((op) => op.kind), [OpKind.createTag, OpKind.createGroup]);
      expect(ops.last.body['name'], 'Trains');
      final shown = (await categories.getCategories()).single;
      expect(shown.groups.single.name, 'Trains');
      expect(shown.groups.single.members, [tram]);
    });
  });
}
