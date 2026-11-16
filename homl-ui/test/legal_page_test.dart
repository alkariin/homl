import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/legal/legal.dart';

void main() {
  Future<void> openLegal(WidgetTester tester, String languageCode) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(languageCode),
      home: const LegalPage(),
    ));
    await tester.pumpAndSettle();
  }

  /// Scrolls the page until [text] is built, then checks it is there.
  Future<void> expectReachable(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(text), findsOneWidget);
  }

  testWidgets('both texts, dated, in English', (tester) async {
    await openLegal(tester, 'en');

    expect(find.text('Terms & privacy'), findsOneWidget);
    expect(find.text('Last updated: November 16, 2026'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    await expectReachable(tester, 'Privacy policy');
    await expectReachable(tester, 'Your rights');
  });

  testWidgets('a "• " line is a list item, shown without its marker',
      (tester) async {
    await openLegal(tester, 'en');

    await tester.scrollUntilVisible(
        find.textContaining('Account: your email address'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('• Account'), findsNothing);
    expect(
        find.text('Account: your email address, your password (only ever '
            'stored hashed), your language and your preferences.'),
        findsOneWidget);
  });

  for (final (language, title, updated, privacy) in [
    (
      'fr',
      'Conditions et confidentialité',
      'Dernière mise à jour : 16 novembre 2026',
      'Protection des données'
    ),
    (
      'de',
      'Nutzungsbedingungen & Datenschutz',
      'Zuletzt aktualisiert: 16. November 2026',
      'Datenschutzerklärung'
    ),
  ]) {
    testWidgets('in $language too', (tester) async {
      await openLegal(tester, language);

      expect(find.text(title), findsOneWidget);
      expect(find.text(updated), findsOneWidget);
      await expectReachable(tester, privacy);
    });
  }
}
