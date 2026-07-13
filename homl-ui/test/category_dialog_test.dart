import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/categories/view/category_management.dart';

Widget wrap() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          child: const Text('open'),
          onPressed: () => categoryDialog(
            context,
            title: 'New category',
            onSubmit: (_, __) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Regression test: the dialog used to dispose its TextEditingController
  // from showDialog's future, which completes on pop while the TextField is
  // still animating out — cancelling then threw a used-after-dispose
  // assertion.
  testWidgets('cancelling the category dialog does not throw', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Trips');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('saving submits the trimmed name and the selected color',
      (tester) async {
    String? submittedName;
    String? submittedColor;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('open'),
            onPressed: () => categoryDialog(
              context,
              title: 'New category',
              onSubmit: (name, color) {
                submittedName = name;
                submittedColor = color;
              },
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  Trips  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(submittedName, 'Trips');
    expect(submittedColor, isNotNull);
  });
}
