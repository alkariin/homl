import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/categories.repository.dart';

/// Answers DELETE /categories/:id and GET /categories/:id/usage, recording
/// what was sent so the wire contract of the three delete options can be
/// asserted.
class _CategoriesAdapter implements HttpClientAdapter {
  _CategoriesAdapter({this.deleteStatus = 204, this.usage});

  final int deleteStatus;
  final Map<String, dynamic>? usage;
  final deleteBodies = <Map<String, dynamic>>[];
  String? lastMethod;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastMethod = options.method;
    lastPath = options.path;

    if (options.path.endsWith('/usage')) {
      if (usage == null) {
        return ResponseBody.fromString('', 404);
      }
      return ResponseBody.fromString(jsonEncode(usage), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }

    if (options.method == 'DELETE') {
      deleteBodies.add((options.data as Map).cast<String, dynamic>());
      if (deleteStatus == 204) {
        return ResponseBody.fromString('', 204);
      }
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'message': 'Forbidden'}
        }),
        deleteStatus,
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

  ({_CategoriesAdapter adapter, CategoriesRepository repository}) build(
      {int deleteStatus = 204, Map<String, dynamic>? usage}) {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    final adapter =
        _CategoriesAdapter(deleteStatus: deleteStatus, usage: usage);
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'an-access-token';
    return (adapter: adapter, repository: CategoriesRepository(api: api));
  }

  // The dialog picks one of three outcomes; the backend reads it from these
  // two booleans only, so both must always be on the wire, with these names.
  group('deleteCategory sends the option the user picked', () {
    test('moving the tags to the Others category', () async {
      final t = build();

      await t.repository.deleteCategory(7, moveTags: true);

      expect(t.adapter.lastMethod, 'DELETE');
      expect(t.adapter.lastPath, '/categories/7');
      expect(t.adapter.deleteBodies.single,
          {'moveTags': true, 'deleteEvents': false});
    });

    test('deleting the tags and keeping the events', () async {
      final t = build();

      await t.repository
          .deleteCategory(7, moveTags: false, deleteEvents: false);

      expect(t.adapter.deleteBodies.single,
          {'moveTags': false, 'deleteEvents': false});
    });

    test('deleting the tags with their events', () async {
      final t = build();

      await t.repository.deleteCategory(7, moveTags: false, deleteEvents: true);

      expect(t.adapter.deleteBodies.single,
          {'moveTags': false, 'deleteEvents': true});
    });

    test('the defaults destroy the least amount of data', () async {
      final t = build();

      await t.repository.deleteCategory(7);

      // A caller that forgets both flags must not delete any event.
      expect(t.adapter.deleteBodies.single['deleteEvents'], false);
    });
  });

  test('a refused deletion surfaces as a repository failure', () async {
    // The locked date/other categories answer 403: the cubit turns any
    // failure into its error modal, so it must not be swallowed here.
    final t = build(deleteStatus: 403);

    await expectLater(t.repository.deleteCategory(1, moveTags: true),
        throwsA(isA<CategoriesRequestFailure>()));
  });

  group('getCategoryUsage', () {
    test('reads the three counts the dialog is built from', () async {
      final t = build(usage: {'tags': 4, 'events': 9, 'exclusiveEvents': 2});

      final usage = await t.repository.getCategoryUsage(7);

      expect(t.adapter.lastPath, '/categories/7/usage');
      expect(usage.tags, 4);
      expect(usage.events, 9);
      expect(usage.exclusiveEvents, 2);
    });

    test('a failing request surfaces as a repository failure', () async {
      final t = build();

      await expectLater(t.repository.getCategoryUsage(7),
          throwsA(isA<CategoriesRequestFailure>()));
    });
  });
}
