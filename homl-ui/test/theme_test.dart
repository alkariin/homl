import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/helpers/theme.dart';

void main() {
  testWidgets('the selected segment of a segmented control is grey',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: homlTheme(),
      home: Scaffold(
        body: SegmentedButton<int>(
          showSelectedIcon: false,
          // The period picker of the insert form passes a style of its own:
          // the theme still has to win on everything it leaves out.
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 0, label: Text('One day')),
            ButtonSegment(value: 1, label: Text('Period')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Material 3 fills the selected segment with the scheme's
    // secondaryContainer, which the black seed turns into a washed red.
    final selected = tester.widget<Material>(find
        .ancestor(of: find.text('One day'), matching: find.byType(Material))
        .first);
    expect(selected.color, const Color(0xFFE9E9E7));

    final unselected = tester.widget<Material>(find
        .ancestor(of: find.text('Period'), matching: find.byType(Material))
        .first);
    expect(unselected.color, Colors.transparent);
  });

  testWidgets('the dark theme fills the selected segment with its own grey',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: homlTheme(brightness: Brightness.dark),
      home: Scaffold(
        body: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('One day')),
            ButtonSegment(value: 1, label: Text('Period')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final selected = tester.widget<Material>(find
        .ancestor(of: find.text('One day'), matching: find.byType(Material))
        .first);
    expect(selected.color, HomlColors.dark.quiet);
  });

  test('each brightness carries its own colors', () {
    final light = homlTheme();
    expect(light.brightness, Brightness.light);
    expect(light.extension<HomlColors>(), same(HomlColors.light));
    expect(light.scaffoldBackgroundColor, const Color(0xFFFBFBFB));

    final dark = homlTheme(brightness: Brightness.dark);
    expect(dark.brightness, Brightness.dark);
    expect(dark.extension<HomlColors>(), same(HomlColors.dark));
    expect(dark.scaffoldBackgroundColor, HomlColors.dark.background);
    // The monochrome controls turn over: light ink on the dark cards.
    expect(dark.colorScheme.primary, HomlColors.dark.ink);
    expect(dark.colorScheme.surface, HomlColors.dark.card);
  });

  testWidgets('a widget reads the colors of the theme in play', (tester) async {
    late HomlColors colors;
    await tester.pumpWidget(MaterialApp(
      theme: homlTheme(),
      darkTheme: homlTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: Builder(builder: (context) {
        colors = context.homl;
        return const SizedBox();
      }),
    ));

    expect(colors, same(HomlColors.dark));
  });

  testWidgets('without the app theme, the colors are the light ones',
      (tester) async {
    late HomlColors colors;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        colors = context.homl;
        return const SizedBox();
      }),
    ));

    expect(colors, same(HomlColors.light));
  });
}
