import 'package:flutter/material.dart';

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
          color: Colors.black.withValues(alpha: 0.05),
        ));
      }
      rows.add(children[i]);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }
}
