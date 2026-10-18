import 'package:material_ui/material_ui.dart';
import 'package:homl/helpers/theme.dart';

/// White rounded card grouping settings rows (the drawer pages), hairline
/// dividers between rows — same card language as the category/event cards,
/// so Security and Settings look identical.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: context.homl.ink.withValues(alpha: 0.05),
        ));
      }
      rows.add(children[i]);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.homl.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.homl.hairline),
        boxShadow: [
          BoxShadow(
            color: context.homl.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // The rows paint their background and ink on the nearest Material: a
      // transparent one above the white card, or the card would hide them.
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: rows),
      ),
    );
  }
}
