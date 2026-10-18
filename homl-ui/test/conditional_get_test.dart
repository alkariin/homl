import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/store/conditional_get.dart';
import 'package:homl/data/store/local_store.dart';

/// Serves [body] with an ETag of it, and 304 to a request naming it.
class _Server implements HttpClientAdapter {
  Object? body = [
    {'id': 1, 'description': 'Train to Bern'}
  ];
  bool sendsETag = true;
  final List<String?> asked = [];
  int notModified = 0;

  String get etag => '"${base64Url.encode(utf8.encode(jsonEncode(body)))}"';

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final ifNoneMatch = options.headers['If-None-Match'] as String?;
    asked.add(ifNoneMatch);
    if (sendsETag && ifNoneMatch == etag) {
      notModified++;
      return ResponseBody.fromString('', 304, headers: {
        'etag': [etag],
      });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (sendsETag) 'etag': [etag],
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
  late _Server server;
  late Dio dio;

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
    LocalStore.instance = LocalStore.inMemory();
    server = _Server();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = server;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('a first read is plain, and saved with its fingerprint', () async {
    final payload = await fetchSaved(dio, '/events', StoreEntry.events);

    expect(payload, server.body);
    expect(server.asked, [null]);
    final saved = await LocalStore.instance.load(StoreEntry.events);
    expect(saved!.payload, server.body);
    expect(saved.etag, server.etag);
  });

  test('unchanged, the server sends nothing and the saved copy is used',
      () async {
    await fetchSaved(dio, '/events', StoreEntry.events);

    final payload = await fetchSaved(dio, '/events', StoreEntry.events);

    expect(payload, server.body);
    expect(server.asked.last, server.etag);
    expect(server.notModified, 1);
  });

  test('changed, the new body comes and replaces the saved one', () async {
    await fetchSaved(dio, '/events', StoreEntry.events);
    final before = server.etag;
    server.body = [
      {'id': 1, 'description': 'Train to Basel'}
    ];

    final payload = await fetchSaved(dio, '/events', StoreEntry.events);

    expect(server.asked.last, before);
    expect(payload, server.body);
    expect(
        (await LocalStore.instance.load(StoreEntry.events))!.etag, server.etag);
  });

  test('a server that gives no fingerprint gets plain reads', () async {
    server.sendsETag = false;

    await fetchSaved(dio, '/events', StoreEntry.events);
    await fetchSaved(dio, '/events', StoreEntry.events);

    expect(server.asked, [null, null]);
  });

  test('a body that is not a list is a failed read', () async {
    server.body = {'not': 'a list'};

    await expectLater(fetchSaved(dio, '/events', StoreEntry.events),
        throwsA(isA<DioException>()));
    expect(await LocalStore.instance.load(StoreEntry.events), isNull);
  });
}
