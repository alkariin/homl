import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/tag.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/helpers/colors.dart';

const football = TagChipData(
    id: 1,
    name: 'Football',
    color: '#f28b82',
    highlightColor: '#f28b82',
    category: 'Hobbies');
const info = TagChipData(
    id: 2,
    name: 'Info',
    color: '#aecbfa',
    highlightColor: '#aecbfa',
    category: 'Work');

/// A free-typed tag of the Others category: suggested, but never highlighted.
const other =
    TagChipData(id: 3, name: 'Fondue', color: '#f2e5c2', category: 'Others');

/// A month date tag: stored in English, displayed in the app language.
const july = TagChipData(
    id: 4,
    name: 'July',
    displayName: 'juillet',
    color: '#ffff60',
    highlightColor: '#ffff60');

/// A category name wider than the whole suggestion row.
const swimming = TagChipData(
    id: 5,
    name: 'Swimming',
    color: '#a7ffeb',
    highlightColor: '#a7ffeb',
    category: 'Sports and weekend leisure activities');

/// Two tags of the Persons category and a group of both.
const alice = TagChipData(
    id: 6,
    name: 'Alice',
    color: '#60ccff',
    highlightColor: '#60ccff',
    category: 'Persons');
const bob = TagChipData(
    id: 7,
    name: 'Bob',
    color: '#60ccff',
    highlightColor: '#60ccff',
    category: 'Persons');
const family = TagChipData(
    id: 1,
    name: 'Family',
    color: '#60ccff',
    highlightColor: '#60ccff',
    members: ['Alice', 'Bob']);

/// Last value reported to [TagInput.onSuggestionChanged] — what the app bar
/// mark follows.
String? suggested;
int browsed = 0;

Widget wrap(
    {List<TagChipData> tags = const [],
    List<TagChipData> suggestions = const [info, football, other, july],
    void Function(String name)? onAddTag,
    bool browsable = true,
    bool allowExclusion = false}) {
  suggested = null;
  browsed = 0;
  return MaterialApp(
    home: Scaffold(
      body: TagInput(
        labelText: 'Filter',
        hintText: '"beach", -Bob',
        tags: tags,
        suggestions: suggestions,
        onAddTag: onAddTag ?? (_) {},
        browseLabel: 'Browse tags',
        onBrowse: browsable ? () => browsed++ : null,
        allowExclusion: allowExclusion,
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

  testWidgets('suggests each tag as its chip, with its category named',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextField), 'foot');
    await tester.pumpAndSettle();

    final row = find.widgetWithText(ListTile, 'Football');
    expect(row, findsOneWidget);
    final chip = tester
        .widget<Tag>(find.descendant(of: row, matching: find.byType(Tag)));
    expect(chip.color, '#f28b82');
    expect(find.descendant(of: row, matching: find.text('Hobbies')),
        findsOneWidget);
  });

  testWidgets('cuts a long category name instead of breaking the row',
      (tester) async {
    await tester.pumpWidget(wrap(suggestions: const [swimming]));
    await tester.enterText(find.byType(TextField), 'swim');
    await tester.pumpAndSettle();

    // Wrapped across the whole tile, the name failed the ListTile layout and
    // took the dropdown down with it.
    expect(tester.takeException(), isNull);
    final row = find.widgetWithText(ListTile, 'Swimming');
    expect(row, findsOneWidget);
    final name =
        find.descendant(of: row, matching: find.text(swimming.category!));
    expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
    // The chip keeps most of the row.
    expect(tester.getSize(name).width, lessThan(tester.getSize(row).width / 2));
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

  group('a tag group', () {
    const suggestions = [alice, bob, family, football];

    testWidgets('is suggested with the tags it adds', (tester) async {
      await tester.pumpWidget(wrap(suggestions: suggestions));
      await tester.enterText(find.byType(TextField), 'fam');
      await tester.pumpAndSettle();

      final row = find.widgetWithText(ListTile, 'Family');
      expect(row, findsOneWidget);
      final chip = tester
          .widget<Tag>(find.descendant(of: row, matching: find.byType(Tag)));
      expect(chip.isGroup, isTrue);
      expect(chip.color, '#60ccff');
      expect(find.descendant(of: row, matching: find.text('Alice, Bob')),
          findsOneWidget);
      // The app bar mark follows a member, which shares the group's category.
      expect(suggested, 'Alice');
      expect(enabledBorderColor(tester), darken(colorFromHex('#60ccff')));
    });

    testWidgets('typed in full adds its tags, never itself', (tester) async {
      final added = <String>[];
      await tester
          .pumpWidget(wrap(suggestions: suggestions, onAddTag: added.add));

      await tester.enterText(find.byType(TextField), 'family');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(added, ['Alice', 'Bob']);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
    });

    testWidgets('picked in the dropdown adds the tags not chipped yet',
        (tester) async {
      final added = <String>[];
      await tester.pumpWidget(wrap(
          tags: const [bob], suggestions: suggestions, onAddTag: added.add));

      await tester.enterText(find.byType(TextField), 'fam');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Family'));
      await tester.pumpAndSettle();

      expect(added, ['Alice']);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('is not offered once all its tags are chipped', (tester) async {
      await tester
          .pumpWidget(wrap(tags: const [alice, bob], suggestions: suggestions));
      await tester.enterText(find.byType(TextField), 'fam');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Family'), findsNothing);
      expect(suggested, isNull);
    });

    testWidgets('loses to a tag of the same name on enter', (tester) async {
      // A tag and a group may share a name (the server allows it): enter
      // adds the tag that was typed, the group stays one tap away.
      const familyTag = TagChipData(
          id: 8, name: 'Family', color: '#f2e5c2', category: 'Others');
      final added = <String>[];
      await tester.pumpWidget(wrap(
          suggestions: const [family, familyTag, alice, bob],
          onAddTag: added.add));

      await tester.enterText(find.byType(TextField), 'Family');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Family'), findsNWidgets(2));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(added, ['Family']);
    });
  });

  group('the search field', () {
    testWidgets('shows its hint once focused', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('"beach", -Bob'), findsOneWidget);
    });

    testWidgets('an excluded chip wears the ban icon', (tester) async {
      await tester.pumpWidget(wrap(tags: const [
        TagChipData(
            id: 1,
            name: '-Football',
            displayName: 'Football',
            color: '#f28b82',
            excluded: true),
      ]));

      expect(tester.widget<Tag>(find.byType(Tag)).excluded, isTrue);
    });
  });

  group('a leading -', () {
    testWidgets('suggests the tags without it, and adds them with it',
        (tester) async {
      final added = <String>[];
      await tester.pumpWidget(wrap(allowExclusion: true, onAddTag: added.add));

      await tester.enterText(find.byType(TextField), '-foo');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Football'), findsOneWidget);
      // A tag being excluded is no tag for the mark to wear.
      expect(suggested, isNull);

      await tester.tap(find.widgetWithText(ListTile, 'Football'));
      await tester.pumpAndSettle();
      expect(added, ['-Football']);
    });

    testWidgets('resolves a label typed in full, then keeps the -',
        (tester) async {
      final added = <String>[];
      await tester.pumpWidget(wrap(allowExclusion: true, onAddTag: added.add));

      await tester.enterText(find.byType(TextField), '- juillet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '-beach');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(added, ['-July', '-beach']);
    });

    testWidgets('excludes every tag of a group', (tester) async {
      final added = <String>[];
      await tester.pumpWidget(wrap(
          allowExclusion: true,
          suggestions: const [alice, bob, family],
          onAddTag: added.add));

      await tester.enterText(find.byType(TextField), '-fam');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Family'));
      await tester.pumpAndSettle();

      expect(added, ['-Alice', '-Bob']);
    });

    testWidgets('an excluded tag is offered again to ask for it',
        (tester) async {
      const excluded = TagChipData(
          id: 1, name: '-Football', displayName: 'Football', excluded: true);
      await tester
          .pumpWidget(wrap(allowExclusion: true, tags: const [excluded]));

      await tester.enterText(find.byType(TextField), '-foo');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Football'), findsNothing);

      await tester.enterText(find.byType(TextField), 'foo');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Football'), findsOneWidget);
    });

    testWidgets('is plain text where exclusion is not allowed', (tester) async {
      final added = <String>[];
      await tester.pumpWidget(wrap(onAddTag: added.add));

      await tester.enterText(find.byType(TextField), '-foo');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(added, ['-foo']);
    });
  });
}
