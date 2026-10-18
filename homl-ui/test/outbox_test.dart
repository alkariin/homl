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

  Map<String, dynamic> event(String description,
          {List<int> tags = const [1]}) =>
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

  group('tags, categories and groups', () {
    Map<String, dynamic> tag(String name, int idCategory, {int? parent}) =>
        {'tag': name, 'idCategory': idCategory, 'idParentTag': parent};

    test('editing one created offline rewrites its creation', () async {
      final id = await outbox.createTag(tag('Tram', 3));
      await outbox.updateTag(id, tag('Bus', 3));
      final category = await outbox.createCategory(
          {'category': 'Trips', 'color': '#ffffff'},
          clientId: 'c1');
      await outbox.updateCategory(
          category, {'category': 'Travels', 'color': '#000000'});

      final ops = await outbox.ops();
      expect(
          ops.map((op) => op.kind), [OpKind.createTag, OpKind.createCategory]);
      expect(ops[0].body['tag'], 'Bus');
      expect(ops[1].id, 'c1');
      expect(ops[1].body['category'], 'Travels');
    });

    test('a detached synonym stays detached once folded', () async {
      final id = await outbox.createTag(tag('Foot', 3, parent: 10));
      await outbox.updateTag(id, tag('Foot', 3));

      expect((await outbox.ops()).single.body['idParentTag'], isNull);
    });

    test('two edits make one with the first base; a deletion replaces them',
        () async {
      await outbox.updateTag(12, tag('Bus', 3), base: tag('Tram', 3));
      await outbox.updateTag(12, tag('Coach', 3), base: tag('Bus', 3));
      var ops = await outbox.ops();
      expect(ops.single.body['tag'], 'Coach');
      expect(ops.single.base!['tag'], 'Tram');

      await outbox.deleteTag(12, {'idParentTag': null}, base: tag('Coach', 3));
      ops = await outbox.ops();
      expect(ops.single.kind, OpKind.deleteTag);
      expect(ops.single.base!['tag'], 'Tram');
    });

    test('one created offline and deleted is created, then deleted', () async {
      final id = await outbox.createGroup({
        'name': 'Family',
        'idCategory': 2,
        'members': [10]
      });
      await outbox.deleteGroup(id);

      final ops = await outbox.ops();
      expect(
          ops.map((op) => op.kind), [OpKind.createGroup, OpKind.deleteGroup]);
      expect(ops.last.target, id);
    });

    test('the same server id names different things in each kind', () async {
      await outbox.updateTag(5, tag('Bus', 3), base: tag('Tram', 3));
      await outbox.updateCategory(5, {'category': 'Trips', 'color': '#ffffff'});
      await outbox.updateEvent(5, event('edited'), base: serverEvent);
      // Deleting event 5 leaves tag 5 and category 5 alone.
      await outbox.deleteEvent(5, base: serverEvent);

      final ops = await outbox.ops();
      expect(ops.map((op) => op.kind), [
        OpKind.updateTag,
        OpKind.updateCategory,
        OpKind.deleteEvent,
      ]);
    });

    test('a category created offline gets its id everywhere it is used',
        () async {
      final category = await outbox
          .createCategory({'category': 'Trips', 'color': '#ffffff'});
      final tram = await outbox.createTag(tag('Tram', category));
      final group = await outbox.createGroup({
        'name': 'Rails',
        'idCategory': category,
        'members': [tram]
      });
      await outbox.createEvent(event('ride', tags: [tram]));

      var ops = await outbox.ops();
      await outbox.nextToSend();
      await outbox.complete(ops[0], serverId: 40);
      expect(outbox.resolve(category), 40);
      ops = await outbox.ops();
      expect(ops[0].body['idCategory'], 40);
      expect(ops[1].body['idCategory'], 40);

      await outbox.nextToSend();
      await outbox.complete(ops[0], serverId: 41);
      ops = await outbox.ops();
      expect(ops[0].body['members'], [41]);
      expect(ops[1].body['tagsId'], [41]);
      expect(outbox.resolve(group), group);
    });

    test('an event created again rewrites the events only', () async {
      await outbox.updateEvent(5, event('edited'), base: serverEvent);
      await outbox.createEvent(event('uses tag 5', tags: [5]));
      await outbox.updateTag(5, tag('Bus', 3), base: tag('Tram', 3));

      final op = await outbox.nextToSend();
      // Deleted elsewhere, created again under 90 with the edit.
      await outbox.complete(op!, serverId: 90);

      expect(outbox.resolveEvent(5), 90);
      expect(outbox.resolve(5), 5);
      final ops = await outbox.ops();
      expect(ops[0].body['tagsId'], [5]);
      expect(ops[1].target, 5);
    });

    test('a parked category holds back what needs it, for the right reason',
        () async {
      final category = await outbox
          .createCategory({'category': 'Trips', 'color': '#ffffff'});
      await outbox.updateCategory(
          category, {'category': 'Travels', 'color': '#ffffff'});
      final tram = await outbox.createTag(tag('Tram', category));
      await outbox.createEvent(event('ride', tags: [tram]));
      await outbox.createEvent(event('unrelated'));

      var ops = await outbox.ops();
      await outbox.park(ops[0], ParkReason.refused);

      ops = await outbox.ops();
      // The edit folded into the creation: one op for the category.
      expect(ops.map((op) => op.parked), [
        ParkReason.refused,
        ParkReason.missingParent,
        ParkReason.missingTag,
        null,
      ]);

      // A later change needing the parked category is parked at once.
      await outbox.createGroup({
        'name': 'Rails',
        'idCategory': category,
        'members': [10]
      });
      expect((await outbox.ops()).last.parked, ParkReason.missingParent);
    });

    test('discarding a category drops what was made with it, in turn',
        () async {
      final category = await outbox
          .createCategory({'category': 'Trips', 'color': '#ffffff'});
      final tram = await outbox.createTag(tag('Tram', category));
      await outbox.createEvent(event('ride', tags: [tram]));
      await outbox.createEvent(event('unrelated'));

      final ops = await outbox.ops();
      await outbox.discard(ops[0].id);

      expect((await outbox.ops()).map((op) => op.body['description']),
          ['unrelated']);
    });

    test('an older outbox still reads, and the new kinds round-trip', () async {
      await outbox.createCategory({'category': 'Trips', 'color': '#ffffff'});
      await outbox.deleteCategory(3, {
        'moveTags': true
      }, base: {
        'category': 'Old',
        'color': '#000000',
        'tags': [1]
      });
      outbox.forget();

      final ops = await outbox.ops();
      expect(ops.map((op) => op.kind),
          [OpKind.createCategory, OpKind.deleteCategory]);
      expect(ops.last.body['moveTags'], isTrue);
      expect(ops.last.base!['tags'], [1]);
    });
  });
}
