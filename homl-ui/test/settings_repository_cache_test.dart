import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/server_reachability.dart';

/// GET /settings answers [payload], or fails like a lost network when
/// [online] is false.
class _SettingsBackend implements HttpClientAdapter {
  bool online = true;
  Map<String, dynamic> payload = {
    'language': 'fr',
    'defaultScreen': true,
    'isE2eeEnabled': true,
    'e2eeKeyCheck': 'a-key-check',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'network is unreachable');
    }
    return ResponseBody.fromString(jsonEncode(payload), 200, headers: {
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
  late _SettingsBackend backend;
  late Api api;
  late SettingsRepository repository;

  setUp(() {
    ServerReachability.instance.reset();
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

    backend = _SettingsBackend();
    api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = backend;
    repository = SettingsRepository(api: api);
  });

  tearDown(() {
    repository.dispose();
    api.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('the fetched settings are cached', () async {
    await repository.getSettings();

    final cached = jsonDecode(storage['settingsCache']!);
    expect(cached['language'], 'fr');
    expect(cached['e2eeKeyCheck'], 'a-key-check');
  });

  test('offline, the cached settings are served and streamed', () async {
    await repository.getSettings();
    backend.online = false;
    final streamed = <Settings>[];
    final subscription = repository.settingsStream.listen(streamed.add);

    final settings = await repository.getSettings();
    await Future<void>.delayed(Duration.zero);

    expect(settings, isNotNull);
    expect(settings!.language, Language.fr);
    expect(settings.defaultScreen, isTrue);
    expect(settings.isE2eeEnabled, isTrue);
    expect(settings.e2eeKeyCheck, 'a-key-check');
    expect(streamed.last.language, Language.fr);

    await subscription.cancel();
  });

  test('offline with nothing cached, the stream reports the failure',
      () async {
    backend.online = false;
    final errors = <Object>[];
    final subscription =
        repository.settingsStream.listen((_) {}, onError: errors.add);

    final settings = await repository.getSettings();
    await Future<void>.delayed(Duration.zero);

    expect(settings, isNull);
    expect(errors.single, isA<SettingsRequestFailure>());

    await subscription.cancel();
  });

  test('a cache that no longer parses is dropped', () async {
    storage['settingsCache'] = '{"language": 42}';

    expect(await repository.getCachedSettings(), isNull);
    expect(storage.containsKey('settingsCache'), isFalse);
  });
}
