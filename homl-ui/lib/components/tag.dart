import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/helpers/colors.dart' as palette;

/// Tag chip: fully rounded pill tinted with the category color, label in
/// neutral ink so every pastel preset reads the same.
/// [large] bumps the paddings and font for prominent spots (the selected
/// tags above the search/insert inputs).
class Tag extends StatelessWidget {
  final int id;
  final String text;
  final String? color;

  /// Called on tap (e.g. open a date picker, insert the tag in a filter).
  final Function()? onTap;

  /// Called on long press. When null the tag is not removable (date tag).
  final Function(int id)? onDeleteTag;
  final bool isDate;
  final bool large;

  const Tag(
      {required this.id,
      required this.text,
      this.color,
      this.onTap,
      this.onDeleteTag,
      this.isDate = false,
      this.large = false,
      super.key});

  @override
  Widget build(BuildContext context) {
    final Color base =
        color != null ? palette.colorFromHex(color!) : palette.yellow;
    final Color label = palette.ink.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        onLongPress: onDeleteTag == null ? null : () => onDeleteTag!(id),
        child: Container(
          padding: large
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.35),
            // Hairline in a darkened shade of the category color: very light
            // pastels would otherwise melt into light backgrounds.
            border: Border.all(
                color: palette.darken(base, .3).withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDate) ...[
                FaIcon(FontAwesomeIcons.calendar,
                    size: large ? 13 : 12, color: label),
                const SizedBox(width: 5),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: large ? 15 : 13.5,
                  fontWeight: FontWeight.w500,
                  color: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
