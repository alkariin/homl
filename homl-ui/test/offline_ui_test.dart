import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/pin_dialog.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/home/view/home.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(appBar: AppBar(actions: [child])),
    );

void main() {
  setUp(() => ServerReachability.instance.reset());

  group('offline indicator', () {
    testWidgets('stays hidden while the server answers', (tester) async {
      await tester.pumpWidget(_app(const OfflineIndicator()));

      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);

      ServerReachability.instance.markOnline();
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('shows up offline and explains itself', (tester) async {
      await tester.pumpWidget(_app(const OfflineIndicator()));

      ServerReachability.instance.markOffline();
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.cloud_off_outlined));
      await tester.pump();
      expect(find.textContaining('data saved on this device'), findsOneWidget);

      // Back online: gone again.
      ServerReachability.instance.markOnline();
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });
  });

  group('PIN dialog', () {
    Future<void> enterPin(WidgetTester tester, PinAuthResult result) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: PinDialogView((_) async => result, null)),
      ));
      await tester.enterText(find.byType(EditableText), '1234');
      await tester.pumpAndSettle();
    }

    testWidgets('says when the PIN cannot be checked offline yet',
        (tester) async {
      await enterPin(
          tester, const PinAuthResult(success: false, unreachable: true));

      expect(find.textContaining('Server unreachable'), findsOneWidget);
      expect(find.text('The PIN code is not correct'), findsNothing);
    });

    testWidgets('a wrong PIN offline counts down like online', (tester) async {
      await enterPin(
          tester, const PinAuthResult(success: false, attemptsRemaining: 2));

      expect(find.text('2 attempts remaining'), findsOneWidget);
    });
  });
}
