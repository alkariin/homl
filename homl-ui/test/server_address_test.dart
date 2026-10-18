import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/server_address.dart';

/// Answers every request with [answer], or throws what it returns.
class _Adapter implements HttpClientAdapter {
  final Object Function(RequestOptions options) answer;
  final requested = <Uri>[];

  _Adapter(this.answer);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri);
    final result = answer(options);
    if (result is ResponseBody) return result;
    throw result;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('apiBaseUrlFor', () {
    test('a bare IPv4 address or localhost gets http and /api', () {
      expect(
          apiBaseUrlFor('192.168.1.10:8090'), 'http://192.168.1.10:8090/api');
      expect(apiBaseUrlFor('localhost:8080'), 'http://localhost:8080/api');
    });

    test('a bare host name gets https', () {
      expect(apiBaseUrlFor('homl.example.com'), 'https://homl.example.com/api');
    });

    test('the scheme typed is kept', () {
      expect(apiBaseUrlFor('https://192.168.1.10:8443'),
          'https://192.168.1.10:8443/api');
      expect(
          apiBaseUrlFor('http://nas.local:8090'), 'http://nas.local:8090/api');
    });

    test('/api is appended once, a proxy sub-path is kept', () {
      expect(apiBaseUrlFor('https://homl.example.com/'),
          'https://homl.example.com/api');
      expect(apiBaseUrlFor(' http://192.168.1.10:8090/api/ '),
          'http://192.168.1.10:8090/api');
      expect(apiBaseUrlFor('https://example.com/homl'),
          'https://example.com/homl/api');
    });

    test('what cannot be a server address is refused', () {
      for (final input in [
        '',
        '   ',
        'ftp://example.com',
        'http://',
        'http://user:secret@example.com',
        'https://example.com?next=1',
        'https://example.com#top',
      ]) {
        expect(apiBaseUrlFor(input), isNull, reason: input);
      }
    });
  });

  test('the address is shown without its /api suffix', () {
    expect(displayServerAddress('http://192.168.1.10:8090/api'),
        'http://192.168.1.10:8090');
    expect(displayServerAddress('https://example.com/homl/api'),
        'https://example.com/homl');
  });

  test('only http:// is cleartext', () {
    expect(isCleartext('http://192.168.1.10:8090/api'), isTrue);
    expect(isCleartext('https://homl.example.com/api'), isFalse);
  });

  group('checkServer', () {
    Future<ServerCheck> check(_Adapter adapter) =>
        checkServer('http://192.168.1.10:8090/api',
            dio: Dio()..httpClientAdapter = adapter);

    test('asks the /healthz next to the API and reads its version', () async {
      final adapter = _Adapter((_) =>
          _json({'mysql': 'ok', 'redis': 'ok', 'version': 'v0.5.0'}, 200));

      final result = await check(adapter);

      expect(result.outcome, ServerCheckOutcome.ok);
      expect(result.version, 'v0.5.0');
      expect(adapter.requested.single.toString(),
          'http://192.168.1.10:8090/healthz');
    });

    test('a homl server with a dependency down is still the right address',
        () async {
      final result = await check(_Adapter((_) =>
          _json({'mysql': 'down', 'redis': 'ok', 'version': 'v0.5.0'}, 503)));

      expect(result.outcome, ServerCheckOutcome.ok);
    });

    test('another web server is not taken for homl', () async {
      final result = await check(_Adapter((_) =>
          ResponseBody.fromString('<html>router admin</html>', 200, headers: {
            Headers.contentTypeHeader: ['text/html'],
          })));

      expect(result.outcome, ServerCheckOutcome.notHoml);
    });

    test('no answer reads as unreachable', () async {
      final result = await check(_Adapter((options) =>
          DioException.connectionError(
              requestOptions: options, reason: 'refused')));

      expect(result.outcome, ServerCheckOutcome.unreachable);
    });

    test('an untrusted certificate is told apart', () async {
      final result = await check(_Adapter(
          (options) => DioException.badCertificate(requestOptions: options)));

      expect(result.outcome, ServerCheckOutcome.untrustedCertificate);
    });
  });

  group('ServerAddress', () {
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    late Map<String, String> storage;

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
        }
        return null;
      });
      ServerAddress.reset('');
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, null);
      ServerAddress.reset();
    });

    test('a build without a default has no server until one is picked',
        () async {
      await ServerAddress.load();

      expect(ServerAddress.isSet, isFalse);
    });

    test('the picked address is kept for the next start', () async {
      await ServerAddress.save('http://192.168.1.10:8090/api');
      expect(storage[LocalStorageKey.serverUrl.name],
          'http://192.168.1.10:8090/api');

      ServerAddress.reset('');
      await ServerAddress.load();

      expect(ServerAddress.current, 'http://192.168.1.10:8090/api');
    });
  });
}
