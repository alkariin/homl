import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/e2ee.dart';

/// Records the tag group writes and answers them with a scripted status
/// (optionally carrying an error code); GET /categories answers [payload].
class _Adapter implements HttpClientAdapter {
  int status = 201;
  String? code;
  List<Map<String, dynamic>> payload = [];
  final List<RequestOptions> requests = [];

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'GET') return _json(payload, 200);

    requests.add(options);
    if (status >= 400) {
      return _json({
        'error': {'message': 'refused', if (code != null) 'code': code}
      }, status);
    }
    return status == 201 ? _json({'id': 6}, 201) : _json(null, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Adapter adapter;
  late CategoriesRepository repository;

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
      }
      return null;
    });
    LocalStore.instance = LocalStore.inMemory();
    Outbox.resetForTesting();
    E2ee().lock();

    adapter = _Adapter();
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'access';
    repository = CategoriesRepository(api: api);
  });

  tearDown(() {
    E2ee().lock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('a group is created with its name, category and members', () async {
    final id = await repository.createTagGroup('Family', 3, [10, 12]);

    expect(id, 6);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, endsWith('/tagGroups'));
    expect(request.data, {
      'name': 'Family',
      'members': [10, 12],
      'idCategory': 3,
    });
  });

  test('an update is full-state, a deletion targets the group', () async {
    adapter.status = 204;

    await repository.updateTagGroup(6, 'Family', [12]);
    await repository.deleteTagGroup(6);

    expect(adapter.requests.first.method, 'PATCH');
    expect(adapter.requests.first.path, endsWith('/tagGroups/6'));
    expect(adapter.requests.first.data, {
      'name': 'Family',
      'members': [12]
    });
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, endsWith('/tagGroups/6'));
  });

  test('a taken group name is told apart from any other failure', () async {
    adapter
      ..status = 409
      ..code = 'TAG_NAME_CONFLICT';
    await expectLater(repository.createTagGroup('Family', 3, [10]),
        throwsA(isA<TagGroupNameConflictFailure>()));
    await expectLater(repository.updateTagGroup(6, 'Family', [10]),
        throwsA(isA<TagGroupNameConflictFailure>()));

    adapter.code = null;
    await expectLater(repository.createTagGroup('Family', 3, [10]),
        throwsA(isA<CategoriesRequestFailure>()));
  });

  test('a group with a tag created offline waits behind it', () async {
    // A negative id is a tag waiting in the outbox: the server has no such
    // row to link yet, so the group waits too, under a temporary id.
    final id = await repository.createTagGroup('Family', 3, [10, -1]);

    expect(id, lessThan(0));
    expect(adapter.requests, isEmpty);
    final op = (await Outbox.instance.ops()).single;
    expect(op.kind, OpKind.createGroup);
    expect(op.body['members'], [10, -1]);
  });

  group('E2EE account', () {
    setUp(() async {
      await E2ee().prepareEnable();
      await E2ee().commitEnable();
    });

    test('the name is normalized, encrypted and indexed', () async {
      await repository.createTagGroup('close family', 3, [10]);

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['name'], startsWith(E2ee.prefix));
      expect(await E2ee().decrypt(body['name'] as String), 'Close Family');
      // The same blind index as a tag of that name.
      expect(body['nameIndex'], await E2ee().tagIndex('Close Family'));
      expect(body['members'], [10]);
    });

    test('a name reserved for the dates is refused before sending', () async {
      await expectLater(repository.createTagGroup('july', 3, [10]),
          throwsA(isA<TagsBlacklistedFailure>()));
      expect(adapter.requests, isEmpty);
    });

    test('the group names are decrypted on read', () async {
      adapter.payload = [
        {
          'id': 3,
          'category': await E2ee().encrypt('Persons'),
          'color': '#60ccff',
          'isLocked': false,
          'kind': 'person',
          'tags': [
            {
              'id': 10,
              'tag': await E2ee().encrypt('Alice'),
              'idParentTag': null
            }
          ],
          'groups': [
            {
              'id': 6,
              'name': await E2ee().encrypt('Family'),
              'members': [10]
            }
          ],
        }
      ];

      final categories = await repository.getCategories();

      final group = categories.single.groups.single;
      expect(group.name, 'Family');
      expect(group.members, [10]);
    });
  });
}
