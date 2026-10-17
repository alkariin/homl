import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';

void main() {
  Future<MaterialLocalizations> materialStringsFor(
      WidgetTester tester, String languageCode) async {
    late MaterialLocalizations strings;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(languageCode),
      home: Builder(builder: (context) {
        strings = MaterialLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    return strings;
  }

  testWidgets('Material widgets speak every app language', (tester) async {
    expect((await materialStringsFor(tester, 'fr')).cancelButtonLabel,
        'Annuler');
    expect((await materialStringsFor(tester, 'de')).cancelButtonLabel,
        'Abbrechen');
    expect((await materialStringsFor(tester, 'en')).cancelButtonLabel,
        'Cancel');
  });
}
