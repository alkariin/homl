import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';

/// Scripted HTTP adapter:
/// - GET /data returns 200 when the access token is the refreshed one,
///   401 otherwise.
/// - POST /refresh returns a new token pair (or 401 when [refreshSucceeds]
///   is false). An optional [refreshGate] holds the refresh response so
///   concurrent 401s can pile up on the single-flight guard.
class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter({this.refreshSucceeds = true});

  final bool refreshSucceeds;
  Completer<void>? refreshGate;

  int refreshCalls = 0;
  int dataCalls = 0;

  ResponseBody _json(Object data, int status) => ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/refresh')) {
      refreshCalls++;
      final gate = refreshGate;
      if (gate != null) await gate.future;
      if (refreshSucceeds) {
        return _json(
            {'refresh_token': 'new-refresh', 'access_token': 'new-access'},
            201);
      }
      return _json({
        'error': {'message': 'Refresh token is invalid'}
      }, 401);
    }

    if (options.path.endsWith('/data')) {
      dataCalls++;
      if (options.headers['Authorization'] == 'Bearer new-access') {
        return _json({'ok': true}, 200);
      }
      return _json({
        'error': {'message': 'Invalid JWT'}
      }, 401);
    }

    return _json({'error': 'not found'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

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
        case 'containsKey':
          return storage.containsKey(args!['key'] as String);
        case 'readAll':
          return storage;
        case 'deleteAll':
          storage.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Api buildApi(_FakeHttpAdapter adapter) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'expired-access';
    return api;
  }

  test('a 401 triggers a token refresh and the request is retried', () async {
    final adapter = _FakeHttpAdapter();
    final api = buildApi(adapter);

    final response = await api.api.get<Map<String, dynamic>>('/data');

    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});
    expect(adapter.refreshCalls, 1);
    expect(adapter.dataCalls, 2); // original request + retry
    expect(api.accessToken, 'new-access');
    expect(storage['refreshToken'], 'new-refresh');

    api.dispose();
  });

  test('a failed refresh propagates the 401 and logs the user out', () async {
    final adapter = _FakeHttpAdapter(refreshSucceeds: false);
    final api = buildApi(adapter);

    final statuses = <AuthenticationStatus>[];
    final subscription = api.status.listen(statuses.add);

    await expectLater(
      api.api.get<Map<String, dynamic>>('/data'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'statusCode', 401)),
    );

    expect(adapter.refreshCalls, 1);
    expect(adapter.dataCalls, 1); // no retry when the refresh failed
    expect(api.accessToken, isNull);
    expect(storage.containsKey('refreshToken'), isFalse);

    // Let the status stream deliver its events.
    await Future<void>.delayed(Duration.zero);
    expect(statuses, contains(AuthenticationStatus.unauthenticated));

    await subscription.cancel();
    api.dispose();
  });

  test('concurrent 401s share a single refresh request', () async {
    final adapter = _FakeHttpAdapter()..refreshGate = Completer<void>();
    final api = buildApi(adapter);

    final first = api.api.get<Map<String, dynamic>>('/data');
    final second = api.api.get<Map<String, dynamic>>('/data');

    // Give both requests the time to hit the 401 and queue on the refresh.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    adapter.refreshGate!.complete();

    final responses = await Future.wait([first, second]);

    expect(responses[0].statusCode, 200);
    expect(responses[1].statusCode, 200);
    expect(adapter.refreshCalls, 1);
    expect(adapter.dataCalls, 4); // two originals + two retries

    api.dispose();
  });
}
