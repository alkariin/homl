import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/logo.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/helpers/colors.dart';

const football =
    TagChipData(id: 1, name: 'Football', color: '#f28b82', highlightColor: '#f28b82');
const info =
    TagChipData(id: 2, name: 'Info', color: '#aecbfa', highlightColor: '#aecbfa');

/// A free-typed tag of the Others category: suggested, but never highlighted.
const other = TagChipData(id: 3, name: 'Fondue', color: '#f2e5c2');

Widget wrap({List<TagChipData> tags = const []}) {
  return MaterialApp(
    home: Scaffold(
      body: TagInput(
        labelText: 'Filter',
        showLogo: true,
        tags: tags,
        suggestions: const [info, football, other],
        onAddTag: (_) {},
      ),
    ),
  );
}

Color? logoTint(WidgetTester tester) =>
    tester.widget<HomlLogo>(find.byType(HomlLogo)).tint;

Color? enabledBorderColor(WidgetTester tester) => tester
    .widget<TextField>(find.byType(TextField))
    .decoration
    ?.enabledBorder
    ?.borderSide
    .color;

void main() {
  testWidgets('suggests prefix matches before contains matches',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'fo');
    await tester.pumpAndSettle();

    // 'Info' only contains "fo": it must come after the prefix matches.
    final football = tester.getTopLeft(find.text('Football'));
    final fondue = tester.getTopLeft(find.text('Fondue'));
    final info = tester.getTopLeft(find.text('Info'));
    expect(football.dy, lessThan(info.dy));
    expect(fondue.dy, lessThan(info.dy));
  });

  testWidgets('tints the logo and the border with the top suggestion category',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();

    final expected = darken(colorFromHex('#f28b82'));
    expect(logoTint(tester), expected);
    expect(enabledBorderColor(tester), expected);
  });

  testWidgets('keeps the default styling when the top suggestion is an Others tag',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'fond');
    await tester.pumpAndSettle();

    expect(find.text('Fondue'), findsOneWidget);
    // Default styling: the logo falls back to its ink tint and the border
    // to the theme.
    expect(logoTint(tester), ink);
    expect(enabledBorderColor(tester), isNull);
  });

  testWidgets('clears the highlight when the field is emptied',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();
    expect(logoTint(tester), isNot(ink));

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(logoTint(tester), ink);
    expect(enabledBorderColor(tester), isNull);
  });

  testWidgets('ignores suggestions already added as filters', (tester) async {
    await tester.pumpWidget(wrap(tags: const [football]));
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();

    // The chip in the Wrap still shows "Football": only the suggestion list
    // must not offer it again.
    expect(find.widgetWithText(ListTile, 'Football'), findsNothing);
    expect(logoTint(tester), ink);
  });
}
