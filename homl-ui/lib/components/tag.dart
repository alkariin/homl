import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/helpers/colors.dart' as palette;

/// Tag chip: rounded rectangle tinted with the category color, label in
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

  static const double _fontSize = 13.5;
  static const double _largeFontSize = 15;
  static const double _verticalPadding = 5;
  static const double _largeVerticalPadding = 7;

  /// Width of the hairline border, which a Container adds around its padding.
  static const double _borderWidth = 1;

  static TextStyle _labelStyle(Color color, {required bool large}) => TextStyle(
        fontSize: large ? _largeFontSize : _fontSize,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Laid-out height of a chip, under the ambient font and text scale. The
  /// event card needs it to fit whole tag rows in the room it can spare.
  static double heightOf(BuildContext context, {bool large = false}) {
    final painter = TextPainter(
      text: TextSpan(
        // Ascender + descender: the tallest line the label can produce.
        text: 'Hg',
        style: DefaultTextStyle.of(context)
            .style
            .merge(_labelStyle(Colors.black, large: large)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    return painter.height +
        2 * (large ? _largeVerticalPadding : _verticalPadding) +
        2 * _borderWidth;
  }

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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onDeleteTag == null ? null : () => onDeleteTag!(id),
        child: Container(
          padding: large
              ? const EdgeInsets.symmetric(
                  horizontal: 14, vertical: _largeVerticalPadding)
              : const EdgeInsets.symmetric(
                  horizontal: 12, vertical: _verticalPadding),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.35),
            // Hairline in a darkened shade of the category color: very light
            // pastels would otherwise melt into light backgrounds.
            border: Border.all(
                color: palette.darken(base, .3).withValues(alpha: 0.4),
                width: _borderWidth),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDate) ...[
                FaIcon(FontAwesomeIcons.calendar,
                    size: large ? 13 : 12, color: label),
                const SizedBox(width: 5),
              ],
              // A label longer than the room the chip is given (a narrow grid
              // card) is truncated instead of overflowing its container.
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(label, large: large),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
