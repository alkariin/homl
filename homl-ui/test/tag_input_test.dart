import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/tag_input.dart';
import 'package:homl/helpers/colors.dart';

const football = TagChipData(
    id: 1, name: 'Football', color: '#f28b82', highlightColor: '#f28b82');
const info = TagChipData(
    id: 2, name: 'Info', color: '#aecbfa', highlightColor: '#aecbfa');

/// A free-typed tag of the Others category: suggested, but never highlighted.
const other = TagChipData(id: 3, name: 'Fondue', color: '#f2e5c2');

/// A month date tag: stored in English, displayed in the app language.
const july = TagChipData(
    id: 4,
    name: 'July',
    displayName: 'juillet',
    color: '#ffff60',
    highlightColor: '#ffff60');

/// Last value reported to [TagInput.onSuggestionChanged] — what the app bar
/// mark follows.
String? suggested;
int browsed = 0;

Widget wrap(
    {List<TagChipData> tags = const [],
    void Function(String name)? onAddTag,
    bool browsable = true}) {
  suggested = null;
  browsed = 0;
  return MaterialApp(
    home: Scaffold(
      body: TagInput(
        labelText: 'Filter',
        tags: tags,
        suggestions: const [info, football, other, july],
        onAddTag: onAddTag ?? (_) {},
        browseLabel: 'Browse tags',
        onBrowse: browsable ? () => browsed++ : null,
        onSuggestionChanged: (name) => suggested = name,
      ),
    ),
  );
}

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

  testWidgets('tints the border with the top suggestion category',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();

    expect(enabledBorderColor(tester), darken(colorFromHex('#f28b82')));
    // The app bar mark follows the same suggestion, by name.
    expect(suggested, 'Football');
  });

  testWidgets(
      'keeps the default styling when the top suggestion is an Others tag',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'fond');
    await tester.pumpAndSettle();

    expect(find.text('Fondue'), findsOneWidget);
    // Default styling: the border falls back to the theme. The tag is still
    // reported — it is the mark that leaves an Others tag colorless.
    expect(enabledBorderColor(tester), isNull);
    expect(suggested, 'Fondue');
  });

  testWidgets('clears the highlight when the field is emptied', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();
    expect(enabledBorderColor(tester), isNotNull);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(enabledBorderColor(tester), isNull);
    expect(suggested, isNull);
  });

  testWidgets('the browse button is optional and reports its taps',
      (tester) async {
    await tester.pumpWidget(wrap(browsable: false));
    expect(find.byType(IconButton), findsNothing);

    await tester.pumpWidget(wrap());
    await tester.tap(find.byTooltip('Browse tags'));
    await tester.pumpAndSettle();
    expect(browsed, 1);
  });

  testWidgets('suggests a translated label but reports the stored name',
      (tester) async {
    final added = <String>[];
    await tester.pumpWidget(wrap(onAddTag: added.add));
    await tester.enterText(find.byType(TextField), 'juil');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'juillet'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'juillet'));
    await tester.pumpAndSettle();

    expect(added, ['July']);
  });

  testWidgets('resolves a translated label typed in full to the stored name',
      (tester) async {
    final added = <String>[];
    await tester.pumpWidget(wrap(onAddTag: added.add));

    // Submitted without picking the suggestion: it must still add the "July"
    // date tag instead of creating a second, untranslated tag.
    await tester.enterText(find.byType(TextField), 'juillet');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added, ['July']);
  });

  testWidgets('picking a suggestion leaves no stale dropdown on refocus',
      (tester) async {
    // Regression: RawAutocomplete ignores a synchronous clear made during its
    // onSelected (its _selecting guard), so its cached options stayed
    // non-empty and the dropdown reappeared over the emptied field when the
    // focus came back (e.g. after closing an event's detail sheet).
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Football'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);

    // Focus leaves the field (the event detail opens)…
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // …and comes back to it (the detail is closed).
    tester.widget<TextField>(find.byType(TextField)).focusNode!.requestFocus();
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('ignores suggestions already added as filters', (tester) async {
    await tester.pumpWidget(wrap(tags: const [football]));
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();

    // The chip in the Wrap still shows "Football": only the suggestion list
    // must not offer it again.
    expect(find.widgetWithText(ListTile, 'Football'), findsNothing);
    expect(suggested, isNull);
  });
}
