import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/view/data_transfer_dialogs.dart';
import 'package:homl/pages/account/view/data_transfer_group.dart';

void main() {
  /// Opens the dialog from a button and returns a getter for its result.
  Future<ExportChoice? Function()> open(WidgetTester tester,
      {required bool isE2eeEnabled}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    ExportChoice? choice;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => choice =
              await ExportDialog.show(context, isE2eeEnabled: isE2eeEnabled),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => choice;
  }

  testWidgets('a plain account exports in clear by default', (tester) async {
    final choice = await open(tester, isE2eeEnabled: false);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('end-to-end encrypted'), findsNothing);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(choice(), isNotNull);
    expect(choice()!.password, isNull);
  });

  testWidgets(
      'an E2EE account is offered the password first, and warned '
      'when it turns it off', (tester) async {
    await open(tester, isE2eeEnabled: true);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('end-to-end encrypted'), findsOneWidget);
  });

  testWidgets('the password must be long enough and typed twice the same',
      (tester) async {
    final choice = await open(tester, isE2eeEnabled: true);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'short');
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.enterText(fields.at(0), 'long enough');
    await tester.enterText(fields.at(1), 'long enougH');
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text("Passwords aren't identical"), findsOneWidget);
    expect(choice(), isNull);

    await tester.enterText(fields.at(1), 'long enough');
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(choice()!.password, 'long enough');
  });

  test('the file name tells a protected export apart', () {
    final day = DateTime(2026, 10, 17, 23, 59);
    expect(exportFileName(day, sealed: false), 'homl-export-2026-10-17.json');
    expect(exportFileName(day, sealed: true),
        'homl-export-2026-10-17-encrypted.json');
  });
}
