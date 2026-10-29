import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/pending_changes.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(appBar: AppBar(actions: [child])),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

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
    Outbox.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  /// Lets the sheet's real asynchronous work (the outbox, sealed with real
  /// crypto) finish between frames, then the animations.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the button only shows while changes wait', (tester) async {
    await tester.pumpWidget(_app(PendingChangesButton(
        counts: const OutboxCounts(0, 0), onChanged: () {})));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);

    await tester.pumpWidget(_app(PendingChangesButton(
        counts: const OutboxCounts(2, 1), onChanged: () {})));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('the sheet lists the changes and can discard one',
      (tester) async {
    await tester.runAsync(() async {
      await Outbox.instance.createEvent({
        'description': 'on the train',
        'date': '2026-10-13T00:00:00.000Z',
        'tagsId': [10],
      });
      final tag = await Outbox.instance.createTag({'tag': 'Tram', 'idCategory': 3});
      final op = (await Outbox.instance.ops()).last;
      expect(op.target, tag);
      await Outbox.instance.park(op, ParkReason.refused);
    });

    var changed = 0;
    await tester.pumpWidget(_app(PendingChangesButton(
        counts: Outbox.instance.currentCounts, onChanged: () => changed++)));
    await tester.tap(find.byIcon(Icons.cloud_upload_outlined));
    await settle(tester);

    expect(find.text('Changes waiting'), findsOneWidget);
    expect(find.text('New event'), findsOneWidget);
    expect(find.textContaining('on the train'), findsOneWidget);
    expect(find.text('New tag'), findsOneWidget);
    expect(find.textContaining('Refused by the server'), findsOneWidget);

    await tester.tap(find.text('Discard').last);
    await settle(tester);

    expect(find.text('New tag'), findsNothing);
    expect(changed, 1);
    final left = await tester.runAsync(() => Outbox.instance.ops());
    expect(left!.single.kind, OpKind.createEvent);
  });

  testWidgets('category, tag and group changes are named too', (tester) async {
    await tester.runAsync(() async {
      final trips = await Outbox.instance
          .createCategory({'category': 'Trips', 'color': '#a7ffeb'});
      await Outbox.instance.createTag({'tag': 'Tram', 'idCategory': trips});
      await Outbox.instance.deleteTag(10, {'idParentTag': null},
          base: {'tag': 'Football', 'idCategory': 3, 'idParentTag': null});
      await Outbox.instance.updateGroup(30, {'name': 'Kin', 'members': [20]},
          base: {'name': 'Family', 'members': [20], 'idCategory': 2});
      await Outbox.instance.park(
          (await Outbox.instance.ops()).first, ParkReason.refused);
    });

    await tester.pumpWidget(_app(PendingChangesButton(
        counts: Outbox.instance.currentCounts, onChanged: () {})));
    await tester.tap(find.byIcon(Icons.cloud_upload_outlined));
    await settle(tester);

    expect(find.text('New category'), findsOneWidget);
    expect(find.textContaining('Trips'), findsOneWidget);
    expect(find.text('New tag'), findsOneWidget);
    expect(find.textContaining('Needs a category or group'), findsOneWidget);
    // A deletion is named as the server had it.
    expect(find.text('Deleted tag'), findsOneWidget);
    expect(find.textContaining('Football'), findsOneWidget);
    expect(find.text('Edited tag group'), findsOneWidget);
    expect(find.textContaining('Kin'), findsOneWidget);
  });
}
