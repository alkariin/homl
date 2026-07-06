import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    return ElevatedButton(
      onPressed: onTap,
      onLongPress: onDeleteTag == null ? null : () => onDeleteTag!(id),
      child: Container(
        height: 25,
        padding: const EdgeInsets.all(5),
        color: color != null
            ? Color(int.parse(color!.replaceAll("#", "0xff")))
            : const Color.fromRGBO(230, 230, 230, 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDate) ...[
              const FaIcon(FontAwesomeIcons.calendar, size: 14),
              const SizedBox(width: 5),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}
