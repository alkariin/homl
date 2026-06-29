import 'package:flutter/material.dart';

class Tag extends StatefulWidget {
  final int id;
  final String text;
  final String? color;
  final Function()? updateDate;
  final Function(int id) onDeleteTag;
  final bool isDate;

  const Tag(
      {required this.id,
      required this.text,
      this.color,
      this.updateDate,
      required this.onDeleteTag,
      required this.isDate,
      super.key});

  @override
  State<Tag> createState() => _TagState();
}

class _TagState extends State<Tag> {
  void onPressed() {
    if (!widget.isDate) return;
    // open calendar

    // widget.updateDate()
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: onPressed,
            onLongPress: () => widget.onDeleteTag(widget.id),
            child: Container(
              height: 25,
              padding: const EdgeInsets.all(5),
              color: widget.color != null
                  ? Color(int.parse(widget.color!.replaceAll("#", "0xff")))
                  : const Color.fromRGBO(230, 230, 230, 0.5),
              child: Text(widget.text),
            ),
          ),
        ],
      ),
    ]);
  }
}
