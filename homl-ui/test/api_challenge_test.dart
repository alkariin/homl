import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/encryption.dart' as encryption;

/// Scripted backend for the challenge–response refresh:
/// - POST /challenge answers a bare JSON string, exactly like the Gin handler
///   (`c.JSON(200, challenge)`).
/// - POST /refresh verifies the ed25519 signature against the challenge it
///   handed out, the way the users service does, and only then rotates the
///   tokens. A signature over anything else — the raw body with its JSON
///   quotes, say — is rejected with a 401.
class _ChallengeAdapter implements HttpClientAdapter {
  _ChallengeAdapter(this.publicKeyBytes);

  final List<int> publicKeyBytes;
  static const challenge = 'KuOoHIwgU9_I096MFWXyH5qU7-c_lUupqff5aSvrIRg';

  /// What the client actually signed, recovered from the accepted signature.
  bool? signatureWasValid;

  ResponseBody _json(Object? data, int status) => ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/challenge')) {
      return _json(challenge, 200);
    }

    if (options.path.endsWith('/refresh')) {
      final body = (options.data as Map).cast<String, dynamic>();
      final signature = body['signature'] as String?;
      if (signature == null) {
        return _json({
          'error': {'message': 'Signature must be provided'}
        }, 401);
      }

      signatureWasValid = await Ed25519().verify(
        utf8.encode(challenge),
        signature: Signature(
          base64.decode(signature),
          publicKey:
              SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        ),
      );

      if (!signatureWasValid!) {
        return _json({
          'error': {'message': 'Not authorized'}
        }, 401);
      }

      return _json(
          {'refresh_token': 'new-refresh', 'access_token': 'new-access'}, 201);
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

  test('the challenge is signed decoded, without its JSON quotes', () async {
    final (publicKey, keyPairJson) = await encryption.generateKeyPair();
    storage['refreshToken'] = 'stored-refresh';
    storage['pinKeypair'] = keyPairJson;

    final adapter = _ChallengeAdapter(base64.decode(publicKey));
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = adapter;

    final result = await api.sendPinAuth('1234');

    expect(adapter.signatureWasValid, isTrue,
        reason: 'the signature must cover the decoded challenge');
    expect(result.success, isTrue);
    expect(api.accessToken, 'new-access');
    expect(storage['refreshToken'], 'new-refresh');

    api.dispose();
  });
}
