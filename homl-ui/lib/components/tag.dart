import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/helpers/colors.dart' as palette;

/// Tag chip: thin colored border, lightly tinted fill, radius 4.
/// The border uses a darkened version of the category color so the pastel
/// presets stay visible on white.
class Tag extends StatelessWidget {
  final int id;
  final String text;
  final String? color;

  /// Called on tap (e.g. open a date picker, insert the tag in a filter).
  final Function()? onTap;

  /// Called on long press. When null the tag is not removable (date tag).
  final Function(int id)? onDeleteTag;
  final bool isDate;

  const Tag(
      {required this.id,
      required this.text,
      this.color,
      this.onTap,
      this.onDeleteTag,
      this.isDate = false,
      super.key});

  @override
  Widget build(BuildContext context) {
    final Color base =
        color != null ? palette.colorFromHex(color!) : palette.yellow;
    final Color border = palette.darken(base);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        onLongPress: onDeleteTag == null ? null : () => onDeleteTag!(id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.12),
            border: Border.all(color: border, width: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDate) ...[
                FaIcon(FontAwesomeIcons.calendar, size: 12, color: border),
                const SizedBox(width: 5),
              ],
              Text(
                text,
                style: const TextStyle(fontSize: 14, color: palette.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
