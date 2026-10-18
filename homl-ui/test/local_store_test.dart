import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/store/blob_store.dart';
import 'package:homl/data/store/blob_store_io.dart';
import 'package:homl/data/store/local_store.dart';

/// A refresh token carrying [userId], the only claim the store reads.
String tokenFor(int userId) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'user_id': userId})}.signature';
}

/// Fails every operation, like a store whose directory is unavailable.
class _BrokenBlobStore implements BlobStore {
  @override
  Future<Uint8List?> read(String name) => throw const FileSystemException();
  @override
  Future<void> write(String name, Uint8List bytes) =>
      throw const FileSystemException();
  @override
  Future<void> delete(String name) => throw const FileSystemException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late MemoryBlobStore blobs;
  late LocalStore store;

  setUp(() {
    storage = {'refreshToken': tokenFor(1)};
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
      }
      return null;
    });
    blobs = MemoryBlobStore();
    store = LocalStore(blobs);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  const events = [
    {'id': 1, 'description': 'Train to Bern', 'date': '2026-09-01T00:00:00Z'}
  ];

  test('saves and loads a payload, with the date it was fetched', () async {
    final before = DateTime.now();
    await store.save(StoreEntry.events, events);

    final loaded = await store.load(StoreEntry.events);

    expect(loaded!.payload, events);
    expect(loaded.savedAt!.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse);
  });

  test('keeps the server fingerprint of a payload with it', () async {
    await store.save(StoreEntry.events, events, etag: '"abc"');
    expect((await store.load(StoreEntry.events))!.etag, '"abc"');

    // A payload saved without one has none: the next read is a plain one.
    await store.save(StoreEntry.events, events);
    expect((await store.load(StoreEntry.events))!.etag, isNull);
  });

  test('keeps the entries sealed: nothing readable at rest', () async {
    await store.save(StoreEntry.events, events);

    final sealed = blobs.entries['events.bin']!;
    expect(utf8.decode(sealed, allowMalformed: true), isNot(contains('Bern')));
    expect(storage.containsKey('localStoreKey'), isTrue);
  });

  test('another account never sees the saved data, which goes for good',
      () async {
    await store.save(StoreEntry.events, events);
    await store.save(StoreEntry.categories, []);

    // Signed out without a wipe (back to the login screen from the PIN
    // dialog), then signed in as someone else.
    storage['refreshToken'] = tokenFor(2);

    expect(await store.load(StoreEntry.events), isNull);
    expect(blobs.entries, isEmpty);
    expect(storage.containsKey('localStoreKey'), isFalse);

    // Back as the first account: nothing left either.
    storage['refreshToken'] = tokenFor(1);
    expect(await store.load(StoreEntry.categories), isNull);
  });

  test('wipe deletes the key: a file left behind cannot be read', () async {
    await store.save(StoreEntry.events, events);
    final leftover = Uint8List.fromList(blobs.entries['events.bin']!);

    await store.wipe();
    expect(storage.containsKey('localStoreKey'), isFalse);
    expect(blobs.entries, isEmpty);

    // A deletion that failed: the bytes are still there.
    blobs.entries['events.bin'] = leftover;
    expect(await store.load(StoreEntry.events), isNull);
    expect(blobs.entries, isEmpty, reason: 'the unreadable entry is dropped');

    // The next save starts over with a new key.
    await store.save(StoreEntry.events, events);
    expect((await store.load(StoreEntry.events))!.payload, events);
  });

  test('an entry copied over another one does not open', () async {
    await store.save(StoreEntry.events, events);
    await store.save(StoreEntry.categories, []);

    blobs.entries['categories.bin'] = blobs.entries['events.bin']!;

    expect(await store.load(StoreEntry.categories), isNull);
    expect((await store.load(StoreEntry.events))!.payload, events);
  });

  test('carries the old cache keys over once, without a fetch date',
      () async {
    storage['eventsCache'] = jsonEncode(events);
    storage['settingsCache'] = 'not json';

    final loaded = await store.load(StoreEntry.events);

    expect(loaded!.payload, events);
    expect(loaded.savedAt, isNull);
    expect(storage.containsKey('eventsCache'), isFalse);
    expect(storage.containsKey('settingsCache'), isFalse,
        reason: 'unreadable: dropped, not carried over');
    expect(await store.load(StoreEntry.settings), isNull);
  });

  test('a store that fails reads as empty and never throws', () async {
    final broken = LocalStore(_BrokenBlobStore());

    await broken.save(StoreEntry.events, events);
    expect(await broken.load(StoreEntry.events), isNull);
    await broken.wipe();
  });

  test('concurrent first saves share one key', () async {
    await Future.wait([
      store.save(StoreEntry.events, events),
      store.save(StoreEntry.categories, ['a']),
      store.save(StoreEntry.settings, {'language': 'en'}),
    ]);

    expect((await store.load(StoreEntry.events))!.payload, events);
    expect((await store.load(StoreEntry.categories))!.payload, ['a']);
    expect((await store.load(StoreEntry.settings))!.payload,
        {'language': 'en'});
  });

  group('files', () {
    late Directory directory;
    late FileBlobStore files;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('homl-store-');
      files = FileBlobStore(directory: () async => directory);
    });

    tearDown(() => directory.delete(recursive: true));

    test('write, read and delete an entry, leaving no temporary file',
        () async {
      await files.write('events.bin', Uint8List.fromList([1, 2, 3]));
      await files.write('events.bin', Uint8List.fromList([4, 5]));

      expect(await files.read('events.bin'), [4, 5]);
      expect(directory.listSync().map((f) => f.uri.pathSegments.last),
          ['events.bin']);

      await files.delete('events.bin');
      expect(await files.read('events.bin'), isNull);
      await files.delete('events.bin');
    });

    test('a store on files round-trips through the encryption', () async {
      final onDisk = LocalStore(files);

      await onDisk.save(StoreEntry.events, events);

      expect((await onDisk.load(StoreEntry.events))!.payload, events);
    });
  });
}
