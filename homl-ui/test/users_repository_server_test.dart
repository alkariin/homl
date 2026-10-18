import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/server_address.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const oldServer = 'http://192.168.1.10:8090/api';
  const newServer = 'https://homl.example.com/api';
  late Map<String, String> storage;
  late Api api;
  late ServerCheck answer;
  late UsersRepository repository;

  setUp(() async {
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
    ServerAddress.reset(oldServer);

    api = Api.internal(baseUrlOverride: oldServer, initFromStorage: false);
    answer = const ServerCheck(ServerCheckOutcome.ok, 'v0.5.0');
    repository = UsersRepository(api: api, checkServer: (_) async => answer);

    // Left by a session the old server turned down: the changes not sent
    // yet, kept for the same account's next sign-in there.
    await LocalStore.instance
        .save(StoreEntry.outbox, ['pending change'], strict: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    ServerAddress.reset();
  });

  test(
      'another server is kept and used, and what was saved for the old one '
      'goes', () async {
    final check = await repository.changeServer(newServer);

    expect(check.outcome, ServerCheckOutcome.ok);
    expect(ServerAddress.current, newServer);
    expect(storage[LocalStorageKey.serverUrl.name], newServer);
    expect(api.baseUrl, newServer);
    // Account ids repeat across servers: these must not reach an account
    // there that happens to share the id.
    expect(await LocalStore.instance.load(StoreEntry.outbox), isNull);
  });

  test('saving the same address again keeps what was saved', () async {
    await repository.changeServer(oldServer);

    expect(await LocalStore.instance.load(StoreEntry.outbox), isNotNull);
  });

  test('an address where no homl server answers changes nothing', () async {
    answer = const ServerCheck(ServerCheckOutcome.unreachable);

    final check = await repository.changeServer(newServer);

    expect(check.outcome, ServerCheckOutcome.unreachable);
    expect(ServerAddress.current, oldServer);
    expect(storage.containsKey(LocalStorageKey.serverUrl.name), isFalse);
    expect(api.baseUrl, oldServer);
    expect(await LocalStore.instance.load(StoreEntry.outbox), isNotNull);
  });
}
