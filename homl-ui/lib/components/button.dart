import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/theme.dart';

/// The main action of a form, as wide as the form. It wears the pastel gold
/// of the theme (`elevatedButtonTheme`); [entrance] gives it the full gold
/// of the entrance screens instead (login, register, forgot password), see
/// [entranceButtonStyle]. [icon] goes before the label.
class Button extends StatelessWidget {
  final String text;
  final Function() onPressed;
  final IconData? icon;
  final bool entrance;

  const Button(
      {required this.text,
      required this.onPressed,
      this.icon,
      this.entrance = false,
      super.key});

  @override
  Widget build(BuildContext context) {
    final style = entrance ? entranceButtonStyle(context) : null;
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? ElevatedButton(
              style: style, onPressed: onPressed, child: Text(text))
          : ElevatedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(text)),
    );
  }
}
