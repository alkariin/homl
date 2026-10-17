import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/e2ee.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/e2ee.dart';

/// Serves one category holding a tag and a tag group, no event, and records
/// the migration body.
class _Server implements HttpClientAdapter {
  List<Map<String, dynamic>> categories = [];
  Map<String, dynamic>? migrated;

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/categories')) return _json(categories, 200);
    if (options.path.endsWith('/events')) return _json([], 200);
    if (options.path.endsWith('/e2ee/migrate')) {
      migrated = Map<String, dynamic>.from(options.data as Map);
      return ResponseBody.fromString('', 204);
    }
    return _json(null, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late _Server server;
  late E2eeRepository repository;

  Map<String, dynamic> persons(String name, String tag, String group) => {
        'id': 3,
        'category': name,
        'color': '#60ccff',
        'isLocked': false,
        'kind': 'person',
        'tags': [
          {'id': 10, 'tag': tag, 'idParentTag': null}
        ],
        'groups': [
          {
            'id': 6,
            'name': group,
            'members': [10]
          }
        ],
      };

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

    server = _Server();
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    api.api.httpClientAdapter = server;
    api.accessToken = 'access';
    repository = E2eeRepository(api: api);
  });

  tearDown(() {
    E2ee().lock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('enabling encrypts the group names and sends their index', () async {
    server.categories = [persons('Persons', 'Alice', 'Family')];
    await E2ee().prepareEnable();

    await repository.enable();

    final groups =
        (server.migrated!['tagGroups'] as List).cast<Map<String, dynamic>>();
    expect(groups, hasLength(1));
    expect(groups.single['id'], 6);
    expect(groups.single['name'], startsWith(E2ee.prefix));
    expect(await E2ee().decrypt(groups.single['name'] as String), 'Family');
    expect(groups.single['nameIndex'], await E2ee().tagIndex('Family'));
  });

  test('disabling sends the group names back in clear', () async {
    await E2ee().prepareEnable();
    await E2ee().commitEnable();
    final e2ee = E2ee();
    server.categories = [
      persons(await e2ee.encrypt('Persons'), await e2ee.encrypt('Alice'),
          await e2ee.encrypt('Family'))
    ];

    await repository.disable();

    expect(server.migrated!['tagGroups'], [
      {'id': 6, 'name': 'Family'}
    ]);
  });
}
