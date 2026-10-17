import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';

/// Answers /registration with a scripted status and JSON body, for both the
/// status check (GET) and the sign-up (POST).
class _RegistrationAdapter implements HttpClientAdapter {
  _RegistrationAdapter(this.status, this.body);

  final int status;
  final Object? body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!options.path.endsWith('/registration')) {
      return ResponseBody.fromString('', 404);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UsersRepository build(int status, Object? body) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = _RegistrationAdapter(status, body);
    return UsersRepository(api: api);
  }

  group('isRegistrationOpen', () {
    test('reads the server answer', () async {
      expect(await build(200, {'open': true}).isRegistrationOpen(), isTrue);
      expect(await build(200, {'open': false}).isRegistrationOpen(), isFalse);
    });

    test('cannot tell on a server without the route', () async {
      expect(
          await build(404, {
            'error': {'type': 'NOT_FOUND'}
          }).isRegistrationOpen(),
          isNull);
    });

    test('cannot tell from an answer of another shape', () async {
      expect(await build(200, {'open': 'yes'}).isRegistrationOpen(), isNull);
      expect(await build(200, ['open']).isRegistrationOpen(), isNull);
    });
  });

  group('register', () {
    test('a closed server is its own failure', () async {
      final repository = build(403, {
        'error': {
          'type': 'STATUS_FORBIDDEN',
          'message': 'Registration is closed on this server',
          'code': 'REGISTRATION_CLOSED',
        }
      });

      expect(repository.register('a@b.c', 'Secret1!', Language.en),
          throwsA(isA<RegistrationClosedFailure>()));
    });

    test('any other refusal stays an HTTP error', () async {
      final repository = build(409, {
        'error': {'type': 'CONFLICT', 'message': 'taken'}
      });

      expect(repository.register('a@b.c', 'Secret1!', Language.en),
          throwsA(isA<DioException>()));
    });
  });
}
