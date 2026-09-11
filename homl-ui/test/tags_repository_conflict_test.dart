import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/tags.repository.dart';

/// Answers POST /tags and PATCH /tags/:id with a scripted status, optionally
/// carrying an error code, so the failure mapping can be asserted.
class _TagsAdapter implements HttpClientAdapter {
  _TagsAdapter({this.status = 201, this.code});

  final int status;
  final String? code;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!options.path.contains('/tags')) {
      return ResponseBody.fromString('', 404);
    }

    if (status < 400) {
      return ResponseBody.fromString(jsonEncode({'id': 12}), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }

    return ResponseBody.fromString(
      jsonEncode({
        'error': {'message': 'refused', if (code != null) 'code': code}
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TagsRepository build({int status = 201, String? code}) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = _TagsAdapter(status: status, code: code);
    api.accessToken = 'an-access-token';
    return TagsRepository(api: api);
  }

  // Tag names are unique per category. Creating one that is taken, renaming
  // onto a taken name or moving into a category that already has it are all
  // refused with the same code, which the app must tell apart from a generic
  // failure to say what went wrong.
  group('a taken tag name is told apart from any other failure', () {
    test('createTag maps the coded 409 to a conflict', () async {
      final repository = build(status: 409, code: 'TAG_NAME_CONFLICT');

      await expectLater(repository.createTag('Football', 2),
          throwsA(isA<TagNameConflictFailure>()));
    });

    test('updateTag maps the coded 409 to a conflict', () async {
      final repository = build(status: 409, code: 'TAG_NAME_CONFLICT');

      await expectLater(repository.updateTag(12, 'Football', 2),
          throwsA(isA<TagNameConflictFailure>()));
    });

    test('a 409 without the code stays a generic failure', () async {
      final repository = build(status: 409);

      await expectLater(repository.createTag('Football', 2),
          throwsA(isA<TagsRequestFailure>()));
    });

    test('another failure stays a generic failure', () async {
      final repository = build(status: 422);

      await expectLater(repository.updateTag(12, 'Football', 2),
          throwsA(isA<TagsRequestFailure>()));
    });
  });

  test('a successful creation still returns the new id', () async {
    final repository = build();

    expect(await repository.createTag('Football', 2), 12);
  });
}
