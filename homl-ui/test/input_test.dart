import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/input.dart';

void main() {
  late TextEditingController controller;
  final changes = <String>[];

  setUp(() {
    controller = TextEditingController(text: 'Original text');
    changes.clear();
  });

  tearDown(() => controller.dispose());

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Input(
            labelText: 'Description',
            controller: controller,
            validator: (_) => null,
            onChange: changes.add,
          ),
          // Somewhere else to tap, to take the focus away from the field.
          const TextField(key: Key('elsewhere')),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a field the user emptied stays empty when it loses the focus',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    // The blur used to reset the field to its initial text, which both put
    // the old text back on screen and reported it as a change.
    expect(controller.text, '');
    expect(find.text('Original text'), findsNothing);
    expect(changes.last, '');
  });

  testWidgets('an edited field keeps its text when it loses the focus',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'New text');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    expect(controller.text, 'New text');
    expect(changes.last, 'New text');
  });
}
