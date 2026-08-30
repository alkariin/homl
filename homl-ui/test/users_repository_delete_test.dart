import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/local_storage_manager.dart';

/// Answers DELETE /account with the scripted status, recording what was sent.
///
/// It also serves /refresh, because a 401 on /account is first treated as an
/// expired access token by the Api interceptor (exactly like PUT /password):
/// the request is retried once with a fresh token before the 401 propagates.
class _DeleteAccountAdapter implements HttpClientAdapter {
  _DeleteAccountAdapter(this.status);

  final int status;
  int calls = 0;
  int refreshCalls = 0;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/refresh')) {
      refreshCalls++;
      return ResponseBody.fromString(
        jsonEncode(
            {'refresh_token': 'new-refresh', 'access_token': 'new-access'}),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.path.endsWith('/account')) {
      calls++;
      lastBody = options.data;
      if (status == 204) {
        return ResponseBody.fromString('', 204);
      }
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'message': 'Not authorized'}
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', 404);
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
    // Everything the app can persist: account deletion must leave none of it.
    storage = {
      for (final key in LocalStorageKey.values) key.name: 'value-${key.name}',
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

  ({Api api, _DeleteAccountAdapter adapter, UsersRepository repository}) build(
      int status) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    final adapter = _DeleteAccountAdapter(status);
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'an-access-token';
    return (
      api: api,
      adapter: adapter,
      repository: UsersRepository(api: api),
    );
  }

  test('a successful deletion wipes every local trace of the account',
      () async {
    final t = build(204);
    final statuses = <AuthenticationStatus>[];
    final subscription = t.api.status.listen(statuses.add);

    await t.repository.deleteAccount('Delete1234!');
    await Future<void>.delayed(Duration.zero);

    expect(t.adapter.calls, 1);
    expect(t.adapter.lastBody, {'password': 'Delete1234!'});
    // The E2EE seed and the PIN keypair are the ones logout keeps on purpose.
    expect(storage, isEmpty);
    expect(t.api.accessToken, isNull);
    expect(statuses, contains(AuthenticationStatus.accountDeleted));

    await subscription.cancel();
  });

  test('a wrong password throws and keeps the session intact', () async {
    final t = build(401);
    final statuses = <AuthenticationStatus>[];
    final subscription = t.api.status.listen(statuses.add);

    await expectLater(t.repository.deleteAccount('WrongPass123!'),
        throwsA(isA<UserRequestFailure>()));

    // The interceptor refreshed and retried once before giving up.
    expect(t.adapter.refreshCalls, 1);
    expect(t.adapter.calls, 2);
    // Nothing of the account was touched: it still exists.
    expect(storage.containsKey(LocalStorageKey.e2eeMasterKey.name), isTrue);
    expect(storage.containsKey(LocalStorageKey.refreshToken.name), isTrue);
    expect(storage.containsKey(LocalStorageKey.pinKeypair.name), isTrue);
    expect(t.api.accessToken, isNotNull);
    expect(statuses, isNot(contains(AuthenticationStatus.accountDeleted)));
    expect(statuses, isNot(contains(AuthenticationStatus.unauthenticated)));

    await subscription.cancel();
  });

  test('a server error surfaces as UserOtherFailure', () async {
    final t = build(500);

    await expectLater(t.repository.deleteAccount('Delete1234!'),
        throwsA(isA<UserOtherFailure>()));
    expect(storage, isNotEmpty);
  });
}
