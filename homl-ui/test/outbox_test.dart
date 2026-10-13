import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/store/blob_store.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/server_reachability.dart';

class _BrokenBlobStore implements BlobStore {
  @override
  Future<Uint8List?> read(String name) async => null;
  @override
  Future<void> write(String name, Uint8List bytes) =>
      throw const FileSystemException('disk full');
  @override
  Future<void> delete(String name) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late Outbox outbox;

  setUp(() {
    storage = {'refreshToken': 'stored-refresh'};
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
    ServerReachability.instance.reset();
    LocalStore.instance = LocalStore.inMemory();
    outbox = Outbox();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Map<String, dynamic> event(String description, {List<int> tags = const [1]}) =>
      {
        'description': description,
        'date': '2026-10-13T00:00:00.000Z',
        'endDate': null,
        'isOngoing': false,
        'tagsId': tags,
      };

  final serverEvent = {
    'id': 7,
    'description': 'as the server had it',
    'date': '2026-10-01T00:00:00Z',
    'tags': [],
  };

  test('creations get decreasing temporary ids and survive a restart',
      () async {
    expect(await outbox.createEvent(event('first')), -2);
    expect(await outbox.createTag({'tag': 'Tram', 'idCategory': 3}), -3);

    final restarted = Outbox();
    final ops = await restarted.ops();
    expect(ops.map((op) => op.kind), [OpKind.createEvent, OpKind.createTag]);
    expect(await restarted.createEvent(event('second')), -4);
  });

  test('editing an event created offline rewrites its creation', () async {
    final id = await outbox.createEvent(event('typo'));

    await outbox.updateEvent(id, event('fixed'));

    final ops = await outbox.ops();
    expect(ops, hasLength(1));
    expect(ops.single.kind, OpKind.createEvent);
    expect(ops.single.body['description'], 'fixed');
  });

  test('deleting an event created offline leaves nothing to send', () async {
    final id = await outbox.createEvent(event('never mind'));
    await outbox.updateEvent(id, event('still never mind'));

    await outbox.deleteEvent(id);

    expect(await outbox.ops(), isEmpty);
  });

  test('two edits of an event make one, with the first base', () async {
    await outbox.updateEvent(7, event('first edit'), base: serverEvent);
    await outbox.updateEvent(7, event('second edit'),
        base: {...serverEvent, 'description': 'later snapshot'});

    final ops = await outbox.ops();
    expect(ops, hasLength(1));
    expect(ops.single.body['description'], 'second edit');
    expect(ops.single.base!['description'], 'as the server had it');
  });

  test('deleting an edited event replaces the edit, keeping its base',
      () async {
    await outbox.updateEvent(7, event('edit'), base: serverEvent);

    await outbox.deleteEvent(7,
        base: {...serverEvent, 'description': 'later snapshot'});

    final ops = await outbox.ops();
    expect(ops.single.kind, OpKind.deleteEvent);
    expect(ops.single.base!['description'], 'as the server had it');
  });

  test('a change made while its creation is being sent waits for its id',
      () async {
    final id = await outbox.createEvent(event('typo'));
    final sending = await outbox.nextToSend();
    expect(sending!.target, id);

    await outbox.updateEvent(id, event('fixed'));
    var ops = await outbox.ops();
    expect(ops, hasLength(2), reason: 'not folded into the op being sent');
    expect(ops.first.body['description'], 'typo');

    await outbox.complete(sending, serverId: 57);

    ops = await outbox.ops();
    expect(ops.single.kind, OpKind.updateEvent);
    expect(ops.single.target, 57);
    expect(outbox.resolve(id), 57);

    // A screen still holding the temporary id reaches the server id.
    await outbox.updateEvent(id, event('fixed again'));
    expect((await outbox.ops()).single.body['description'], 'fixed again');
  });

  test('a tag created offline is replaced by its id in the events using it',
      () async {
    final tag = await outbox.createTag({'tag': 'Tram', 'idCategory': 3});
    await outbox.createEvent(event('ride', tags: [1, tag]));

    final tagOp = await outbox.nextToSend();
    await outbox.complete(tagOp!, serverId: 12);

    expect((await outbox.ops()).single.body['tagsId'], [1, 12]);
  });

  test('parking a tag holds back the events using it, discarding drops them',
      () async {
    final tag = await outbox.createTag({'tag': 'Tram', 'idCategory': 3});
    await outbox.createEvent(event('ride', tags: [tag]));
    await outbox.createEvent(event('unrelated'));

    final tagOp = await outbox.nextToSend();
    await outbox.park(tagOp!, ParkReason.refused);

    final ops = await outbox.ops();
    expect(ops.map((op) => op.parked),
        [ParkReason.refused, ParkReason.missingTag, null]);
    expect((await outbox.nextToSend())!.body['description'], 'unrelated');
    expect(outbox.currentCounts.parked, 2);

    await outbox.discard(tagOp.id);
    expect((await outbox.ops()).map((op) => op.body['description']),
        ['unrelated']);
  });

  test('writes queue while offline or behind waiting changes', () async {
    expect(await outbox.shouldQueue(), isFalse);

    ServerReachability.instance.markOffline();
    expect(await outbox.shouldQueue(), isTrue);

    ServerReachability.instance.markOnline();
    await outbox.createEvent(event('waiting'));
    expect(await outbox.shouldQueue(), isTrue);

    // Only parked changes left: they do not hold new writes back.
    await outbox.park((await outbox.nextToSend())!, ParkReason.refused);
    expect(await outbox.shouldQueue(), isFalse);
  });

  test('a write that cannot be persisted fails and changes nothing', () async {
    LocalStore.instance = LocalStore(_BrokenBlobStore());
    final broken = Outbox();

    await expectLater(broken.createEvent(event('lost?')), throwsException);
    expect(broken.currentCounts.total, 0);
  });

  test('forget drops the in-memory copy, not what is persisted', () async {
    await outbox.createEvent(event('kept'));
    expect(outbox.currentCounts.pending, 1);

    outbox.forget();
    expect(outbox.currentCounts.total, 0);

    expect(await outbox.ops(), hasLength(1));
  });
}
