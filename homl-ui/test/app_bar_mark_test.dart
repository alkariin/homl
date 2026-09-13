import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/app_bar_mark.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/helpers/colors.dart';

/// Category colors of the fixture tags; anything else leaves the mark at
/// rest, as the Dates and Others tags do in the app.
const accents = {'Marie': '#60ccff', 'Lisbon': '#d7aefb'};
String? accentColorOf(String name) => accents[name];

Color expected(String hex) => darken(colorFromHex(hex));

Color? markTint(WidgetTester tester) =>
    tester.widget<HomlMark>(find.byType(HomlMark)).tint;

Future<void> pumpMark(WidgetTester tester,
    {List<String> tagNames = const [], ValueNotifier<String?>? typedTag}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppBarMark(
          tagNames: tagNames, typedTag: typedTag, accentColorOf: accentColorOf),
    ),
  ));
}

void main() {
  testWidgets('rests in its own gold without tags', (tester) async {
    await pumpMark(tester);
    expect(markTint(tester), isNull);
  });

  testWidgets('takes the category color of the tag being typed',
      (tester) async {
    final typed = ValueNotifier<String?>(null);
    addTearDown(typed.dispose);
    await pumpMark(tester, typedTag: typed);

    typed.value = 'Marie';
    await tester.pump();
    expect(markTint(tester), expected('#60ccff'));
  });

  testWidgets('keeps the last chosen tag color, one at a time', (tester) async {
    await pumpMark(tester, tagNames: ['Marie']);
    expect(markTint(tester), expected('#60ccff'));

    // A second filter does not blend in: the mark wears the last one only.
    await pumpMark(tester, tagNames: ['Marie', 'Lisbon']);
    expect(markTint(tester), expected('#d7aefb'));
  });

  testWidgets('a typed tag without a category falls back to the chosen ones',
      (tester) async {
    final typed = ValueNotifier<String?>('July');
    addTearDown(typed.dispose);
    await pumpMark(tester, tagNames: ['Marie'], typedTag: typed);

    // "July" is a date tag here (no accent): the mark must not drop back to
    // rest in the middle of a word.
    expect(markTint(tester), expected('#60ccff'));
  });

  testWidgets('a chosen tag without a category leaves the mark at rest',
      (tester) async {
    await pumpMark(tester, tagNames: ['Fondue']);
    expect(markTint(tester), isNull);
  });

  testWidgets('sweeps a color in, fades from one color to the next',
      (tester) async {
    await pumpMark(tester);
    expect(find.byType(HomlLogoSweep), findsNothing);

    // Rest → color replays the splash reveal.
    await pumpMark(tester, tagNames: ['Marie']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomlLogoSweep), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(HomlLogoSweep), findsNothing);

    // Color → color is a plain cross-fade, not a second reveal.
    await pumpMark(tester, tagNames: ['Marie', 'Lisbon']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomlLogoSweep), findsNothing);
    expect(find.byType(Opacity), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
