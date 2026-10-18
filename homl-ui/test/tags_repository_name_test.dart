import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/e2ee.dart';

/// Records the tag writes and answers them as created.
class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
        options.method == 'POST' ? jsonEncode({'id': 12}) : '',
        options.method == 'POST' ? 201 : 204,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Adapter adapter;
  late TagsRepository repository;

  setUp(() {
    storage = {};
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
    LocalStore.instance = LocalStore.inMemory();
    Outbox.resetForTesting();
    E2ee().lock();

    adapter = _Adapter();
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'access';
    repository = TagsRepository(api: api);
  });

  tearDown(() {
    E2ee().lock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Map<String, dynamic> sent() =>
      adapter.requests.single.data as Map<String, dynamic>;

  // A tag reads the same wherever it was typed: the insert form, the
  // categories tab, a rename.
  test('a created tag is sent in its canonical form', () async {
    await repository.createTag('movie NIGHT', 2);

    expect(sent()['tag'], 'Movie Night');
  });

  test('a renamed tag too', () async {
    await repository.updateTag(12, 'jean-PIERRE', 2);

    expect(sent()['tag'], 'Jean-Pierre');
  });

  group('E2EE account', () {
    setUp(() async {
      await E2ee().prepareEnable();
      await E2ee().commitEnable();
    });

    // The backend cannot title-case a blob: the app does it before sealing.
    test('the name is normalized before it is encrypted', () async {
      await repository.createTag('movie NIGHT', 2);

      expect(await E2ee().decrypt(sent()['tag'] as String), 'Movie Night');
      expect(sent()['tagIndex'], await E2ee().tagIndex('Movie Night'));
    });
  });
}
