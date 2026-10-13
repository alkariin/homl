import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/pending_changes.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets('a card made offline wears a clock', (tester) async {
    Widget card(bool pending) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: EventCard(
                event: Event(
                    id: pending ? -2 : 5,
                    description: 'note',
                    date: DateTime(2026, 10, 13),
                    isOngoing: false,
                    tags: [],
                    isPending: pending),
                tagColorResolver: (_) => null,
                isDateTag: (_) => false,
              ),
            ),
          ),
        );

    await tester.pumpWidget(card(false));
    expect(find.byIcon(Icons.schedule), findsNothing);

    await tester.pumpWidget(card(true));
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });
}
