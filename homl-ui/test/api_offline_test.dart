import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/encryption.dart' as encryption;
import 'package:homl/helpers/pin_verifier.dart';
import 'package:homl/helpers/server_reachability.dart';

/// Scripted backend: each test says how every path answers. [reply] returns a
/// response, or throws a [DioException] to simulate a network failure.
class _Backend implements HttpClientAdapter {
  _Backend(this.reply);

  Future<ResponseBody> Function(RequestOptions options) reply;
  final List<RequestOptions> requests = [];

  int callsTo(String path) =>
      requests.where((r) => r.path.endsWith(path)).length;

  RequestOptions lastTo(String path) =>
      requests.lastWhere((r) => r.path.endsWith(path));

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? data, int status) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Never _offline(RequestOptions options) => throw DioException.connectionError(
    requestOptions: options, reason: 'network is unreachable');

ResponseBody _tokens() =>
    _json({'refresh_token': 'new-refresh', 'access_token': 'new-access'}, 201);

ResponseBody _error(int status, String message, {String? code}) => _json({
      'error': {
        'message': message,
        if (code != null) 'code': code,
      }
    }, status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

  setUpAll(() {
    // Pure Dart PBKDF2 in the tests: keep it cheap.
    PinVerifier.iterations = 1000;
  });

  setUp(() {
    ServerReachability.instance.reset();
    storage = {
      'refreshToken': 'stored-refresh',
      'eventsCache': '[]',
      'categoriesCache': '[]',
      'settingsCache': '{}',
    };
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

  ({Api api, List<AuthenticationStatus> statuses}) build(_Backend backend,
      {Future<String> Function()? readBiometricKeyPair}) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test',
        initFromStorage: false,
        readBiometricKeyPair: readBiometricKeyPair);
    api.api.httpClientAdapter = backend;
    final statuses = <AuthenticationStatus>[];
    final subscription = api.status.listen(statuses.add);
    addTearDown(() async {
      await subscription.cancel();
      api.dispose();
    });
    return (api: api, statuses: statuses);
  }

  bool sessionKept() =>
      storage['refreshToken'] != null &&
      storage['eventsCache'] != null &&
      storage['categoriesCache'] != null &&
      storage['settingsCache'] != null;

  bool sessionWiped() =>
      !storage.containsKey('refreshToken') &&
      !storage.containsKey('eventsCache') &&
      !storage.containsKey('categoriesCache') &&
      !storage.containsKey('settingsCache');

  /// Lets the status stream and the unawaited work settle.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue, reason: 'condition not reached in time');
  }

  group('a server that cannot be reached keeps the session', () {
    test('on the refresh behind an expired access token', () async {
      final backend = _Backend((options) async {
        if (options.path.endsWith('/data')) {
          return _error(401, 'Invalid JWT');
        }
        return _offline(options);
      });
      final t = build(backend);
      t.api.accessToken = 'expired-access';

      await expectLater(t.api.api.get<dynamic>('/data'),
          throwsA(isA<DioException>()));
      await settle();

      expect(sessionKept(), isTrue);
      expect(ServerReachability.instance.value, Reachability.offline);
      expect(t.statuses, isNot(contains(AuthenticationStatus.unauthenticated)));
    });

    test('on a gateway error in front of the backend', () async {
      final backend = _Backend((options) async {
        if (options.path.endsWith('/data')) {
          return _error(401, 'Invalid JWT');
        }
        return _json('Bad gateway', 502);
      });
      final t = build(backend);
      t.api.accessToken = 'expired-access';

      await expectLater(t.api.api.get<dynamic>('/data'),
          throwsA(isA<DioException>()));
      await settle();

      expect(sessionKept(), isTrue);
      expect(ServerReachability.instance.value, Reachability.offline);
    });

    test('on a server error during the refresh', () async {
      final backend = _Backend((options) async {
        if (options.path.endsWith('/data')) {
          return _error(401, 'Invalid JWT');
        }
        return _error(500, 'Internal server error.');
      });
      final t = build(backend);
      t.api.accessToken = 'expired-access';

      await expectLater(t.api.api.get<dynamic>('/data'),
          throwsA(isA<DioException>()));
      await settle();

      expect(sessionKept(), isTrue);
      expect(t.statuses, isNot(contains(AuthenticationStatus.unauthenticated)));
    });

    test('but a session the server turns down still ends, data included',
        () async {
      await PinVerifier.store('1234');
      final backend = _Backend((options) async {
        if (options.path.endsWith('/data')) {
          return _error(401, 'Invalid JWT');
        }
        return _error(401, 'Not authorized');
      });
      final t = build(backend);
      t.api.accessToken = 'expired-access';

      await expectLater(t.api.api.get<dynamic>('/data'),
          throwsA(isA<DioException>()));
      await settle();

      expect(sessionWiped(), isTrue);
      expect(storage.containsKey('pinVerifier'), isFalse);
      expect(t.api.accessToken, isNull);
      expect(t.statuses, contains(AuthenticationStatus.unauthenticated));
    });
  });

  group('offline start', () {
    test('an account without second factor opens the saved data', () async {
      final backend = _Backend((options) async => _offline(options));
      final t = build(backend);

      await t.api.restoreSession();
      await settle();

      expect(t.statuses, contains(AuthenticationStatus.authenticated));
      expect(ServerReachability.instance.value, Reachability.offline);
      expect(sessionKept(), isTrue);
      expect(t.api.accessToken, isNull);
    });

    test('a fingerprint account opens once the fingerprint is read',
        () async {
      final (_, keyPair) = await encryption.generateKeyPair();
      storage['isFingerprintEnabled'] = 'true';
      var prompts = 0;
      final backend = _Backend((options) async => _offline(options));
      final t = build(backend, readBiometricKeyPair: () async {
        prompts++;
        return keyPair;
      });

      await t.api.restoreSession();
      await settle();

      expect(prompts, 1);
      expect(t.statuses, contains(AuthenticationStatus.authenticated));
      expect(ServerReachability.instance.value, Reachability.offline);
      expect(sessionKept(), isTrue);
    });

    test('a failed fingerprint prompt does not open anything', () async {
      storage['isFingerprintEnabled'] = 'true';
      final backend = _Backend((options) async => _offline(options));
      final t = build(backend,
          readBiometricKeyPair: () async => throw Exception('cancelled'));

      await t.api.restoreSession();
      await settle();

      expect(t.statuses, contains(AuthenticationStatus.biometricCheck));
      expect(t.statuses, isNot(contains(AuthenticationStatus.authenticated)));
      expect(backend.requests, isEmpty);
      expect(sessionKept(), isTrue);
    });
  });

  group('PIN account', () {
    late String pinKeypair;

    setUp(() async {
      final (_, keyPair) = await encryption.generateKeyPair();
      pinKeypair = keyPair;
      storage['pinKeypair'] = pinKeypair;
    });

    /// Online backend accepting [pin] (and any signature), with a scripted
    /// `/data` that wants the refreshed access token.
    _Backend onlineBackend({String pin = '1234'}) => _Backend((options) async {
          if (options.path.endsWith('/challenge')) {
            return _json('a-challenge', 200);
          }
          if (options.path.endsWith('/refresh')) {
            final body = (options.data as Map).cast<String, dynamic>();
            if (body['pin'] == null) {
              return _error(401, 'Pin must be provided',
                  code: 'SECOND_FACTOR_REQUIRED');
            }
            if (body['signature'] == null) {
              return _error(400, 'Bad request. Reason: Signature must be provided');
            }
            if (body['pin'] != pin) {
              return _json({
                'error': {
                  'message': 'Pin code not correct',
                  'code': 'PIN_INCORRECT',
                  'attemptsRemaining': 2,
                }
              }, 401);
            }
            return _tokens();
          }
          if (options.path.endsWith('/data')) {
            if (options.headers['Authorization'] == 'Bearer new-access') {
              return _json({'ok': true}, 200);
            }
            return _error(401, 'Invalid JWT');
          }
          if (options.path.endsWith('/healthz')) {
            return _json({'mysql': 'ok', 'redis': 'ok', 'version': 'v0'}, 200);
          }
          return _json({'error': 'not found'}, 404);
        });

    test('a PIN accepted online becomes the one checked offline', () async {
      final t = build(onlineBackend());

      final result = await t.api.sendPinAuth('1234');

      expect(result.success, isTrue);
      expect(storage.containsKey('pinVerifier'), isTrue);
      expect(await PinVerifier.verify('1234'), OfflinePinCheck.match);
    });

    test('the expired access token is renewed with the PIN of the session',
        () async {
      final backend = onlineBackend();
      final t = build(backend);
      await t.api.sendPinAuth('1234');
      t.api.accessToken = 'expired-access';

      final response = await t.api.api.get<dynamic>('/data');

      expect(response.statusCode, 200);
      final refresh =
          (backend.lastTo('/refresh').data as Map).cast<String, dynamic>();
      expect(refresh['pin'], '1234');
      expect(refresh['signature'], isNotNull);
      expect(sessionKept(), isTrue);
      expect(t.statuses, isNot(contains(AuthenticationStatus.unauthenticated)));
    });

    test('without the PIN of the session, it is asked again, nothing wiped',
        () async {
      final backend = onlineBackend();
      final t = build(backend);
      t.api.accessToken = 'expired-access';

      await expectLater(t.api.api.get<dynamic>('/data'),
          throwsA(isA<DioException>()));
      await settle();

      expect(backend.callsTo('/refresh'), 0);
      expect(t.statuses, contains(AuthenticationStatus.pinCheck));
      expect(sessionKept(), isTrue);
    });

    test('offline without a stored PIN says the server is unreachable',
        () async {
      final t = build(_Backend((options) async => _offline(options)));

      final result = await t.api.sendPinAuth('1234');

      expect(result.success, isFalse);
      expect(result.unreachable, isTrue);
      expect(sessionKept(), isTrue);
      expect(t.statuses, isNot(contains(AuthenticationStatus.authenticated)));
    });

    test('offline, the stored PIN opens the saved data', () async {
      await PinVerifier.store('1234');
      final t = build(_Backend((options) async => _offline(options)));

      final result = await t.api.sendPinAuth('1234');
      await settle();

      expect(result.success, isTrue);
      expect(t.statuses, contains(AuthenticationStatus.authenticated));
      expect(ServerReachability.instance.value, Reachability.offline);
      expect(sessionKept(), isTrue);
    });

    test('offline, three wrong PINs lock like the server does', () async {
      await PinVerifier.store('1234');
      final t = build(_Backend((options) async => _offline(options)));

      final first = await t.api.sendPinAuth('0000');
      final second = await t.api.sendPinAuth('1111');
      expect(first.attemptsRemaining, 2);
      expect(second.attemptsRemaining, 1);
      expect(sessionKept(), isTrue);

      final third = await t.api.sendPinAuth('2222');
      await settle();

      expect(third.locked, isTrue);
      expect(t.statuses, contains(AuthenticationStatus.pinLocked));
      expect(sessionWiped(), isTrue);
      expect(storage.containsKey('pinVerifier'), isFalse);
      // As after the server's lockout: the password login keeps the PIN.
      expect(storage['pinKeypair'], pinKeypair);
    });

    test('back online, the session reopens with the PIN given offline',
        () async {
      await PinVerifier.store('1234');
      final online = onlineBackend();
      final backend = _Backend((options) async => _offline(options));
      final t = build(backend);

      await t.api.sendPinAuth('1234');
      expect(ServerReachability.instance.value, Reachability.offline);
      expect(t.api.accessToken, isNull);

      backend.reply = online.reply;
      t.api.onAppResumed();
      await until(
          () => ServerReachability.instance.value == Reachability.online);

      expect(t.api.accessToken, 'new-access');
      final refresh =
          (backend.lastTo('/refresh').data as Map).cast<String, dynamic>();
      expect(refresh['pin'], '1234');
      expect(sessionKept(), isTrue);
    });
  });

  test('a factor the server wants and this device lacks ends the session',
      () async {
    final backend = _Backend((options) async {
      if (options.path.endsWith('/data')) {
        return _error(401, 'Invalid JWT');
      }
      return _error(401, 'Pin must be provided',
          code: 'SECOND_FACTOR_REQUIRED');
    });
    final t = build(backend);
    t.api.accessToken = 'expired-access';

    await expectLater(t.api.api.get<dynamic>('/data'),
        throwsA(isA<DioException>()));
    await settle();

    expect(t.statuses, contains(AuthenticationStatus.unauthenticated));
    expect(sessionWiped(), isTrue);
  });

  test('offline, requests fail at once instead of waiting for a timeout',
      () async {
    final backend = _Backend((options) async => _offline(options));
    final t = build(backend);

    await t.api.restoreSession();
    final before = backend.requests.length;

    await expectLater(
        t.api.api.get<dynamic>('/settings'),
        throwsA(isA<DioException>().having(
            (e) => e.type, 'type', DioExceptionType.connectionError)));

    expect(backend.requests.length, before,
        reason: 'the request must not reach the network');
  });

  test('back online, an account without second factor gets its token',
      () async {
    final backend = _Backend((options) async => _offline(options));
    final t = build(backend);
    await t.api.restoreSession();
    expect(ServerReachability.instance.value, Reachability.offline);

    backend.reply = (options) async {
      if (options.path.endsWith('/healthz')) {
        return _json({'mysql': 'ok', 'redis': 'ok', 'version': 'v0'}, 200);
      }
      if (options.path.endsWith('/refresh')) return _tokens();
      return _json({'error': 'not found'}, 404);
    };
    t.api.onAppResumed();
    await until(
        () => ServerReachability.instance.value == Reachability.online);

    expect(t.api.accessToken, 'new-access');
    expect(storage['refreshToken'], 'new-refresh');
  });

  group('after an offline blip, a regular request', () {
    late _Backend backend;
    late Api api;

    setUp(() async {
      backend = _Backend((options) async => _offline(options));
      api = build(backend).api;
      api.accessToken = 'valid-access';
      await expectLater(
          api.api.get<dynamic>('/data'), throwsA(isA<DioException>()));
      expect(ServerReachability.instance.value, Reachability.offline);
      // As if the fail-fast window had passed.
      ServerReachability.instance.noteAnswer();
    });

    test('answered by the server brings the app back online', () async {
      backend.reply = (options) async => _json({'ok': true}, 200);

      await api.api.get<dynamic>('/data');

      expect(ServerReachability.instance.value, Reachability.online);
    });

    test('answered by a captive portal does not', () async {
      backend.reply = (options) async =>
          ResponseBody.fromString('<html>Sign in to the Wi-Fi</html>', 200,
              headers: {
                Headers.contentTypeHeader: ['text/html'],
              });

      await api.api.get<dynamic>('/data');

      expect(ServerReachability.instance.value, Reachability.offline);
    });
  });

  test('a /healthz that is not ours keeps the app offline', () async {
    final backend = _Backend((options) async => _offline(options));
    final t = build(backend);
    await t.api.restoreSession();

    // A captive portal answering every URL with its login page.
    backend.reply = (options) async =>
        ResponseBody.fromString('<html>Sign in to the Wi-Fi</html>', 200,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            });
    t.api.onAppResumed();
    await settle();

    expect(ServerReachability.instance.value, Reachability.offline);
    expect(backend.callsTo('/refresh'), 1,
        reason: 'only the refresh of the offline start');
    expect(sessionKept(), isTrue);
  });
}
