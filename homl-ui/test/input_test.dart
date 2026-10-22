import 'package:material_ui/material_ui.dart';
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

  testWidgets('a textarea can ask the keyboard for sentence capitals',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Input(
          labelText: 'Description',
          maxLines: 10,
          minLines: 5,
          textCapitalization: TextCapitalization.sentences,
          validator: _noError,
        ),
      ),
    ));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.minLines, 5);
    expect(field.keyboardType, TextInputType.multiline);
  });

  testWidgets('a field asks for no capitals by default', (tester) async {
    await pumpForm(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.textCapitalization, TextCapitalization.none);
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

String? _noError(String _) => null;
