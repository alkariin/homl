import 'package:flutter/material.dart';
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
}
