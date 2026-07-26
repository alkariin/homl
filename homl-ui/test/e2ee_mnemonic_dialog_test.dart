import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/view/e2ee_mnemonic_dialog.dart';

void main() {
  testWidgets('shows every one of the 12 words, numbered', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    const phrase =
        'protect humor book category wear stomach evil begin fade clip size fence';

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: E2eeMnemonicDialog(mnemonic: phrase)),
    ));
    await tester.pumpAndSettle();

    // First and, crucially, the last two words must be present.
    expect(find.textContaining('1. protect'), findsOneWidget);
    expect(find.textContaining('11. size'), findsOneWidget);
    expect(find.textContaining('12. fence'), findsOneWidget);
    expect(find.text('12 words'), findsOneWidget);
  });
}
