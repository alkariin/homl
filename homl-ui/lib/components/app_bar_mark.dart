import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:homl/components/logo.dart';
import 'package:homl/helpers/colors.dart';

/// The "#" mark of the app bar: the logo, tinted by the tags in play and
/// never tappable — browsing the categories is the button next to the tag
/// input.
///
/// Priority, highest first: the tag being typed, then the last chosen tag
/// that carries a category color, then the resting two-tone gold. A typed tag
/// that carries none (an Others tag, a date tag) falls through to the chosen
/// ones rather than dropping the mark back to rest in the middle of a word.
/// The mark never wears two colors at once.
class AppBarMark extends StatelessWidget {
  /// Chosen tags — the search filters, or the tags of the event being
  /// written — in the order they were added.
  final List<String> tagNames;

  /// Stored name of the tag being typed (the top suggestion of the input);
  /// null when the field is empty or nothing matches it.
  final ValueListenable<String?>? typedTag;

  /// Category color ("#RRGGBB") tinting the mark for a tag name, or null when
  /// that tag must leave the mark at rest (`HomeState.markAccentFor`).
  final String? Function(String tagName) accentColorOf;

  final double size;

  const AppBarMark(
      {required this.tagNames,
      required this.accentColorOf,
      this.typedTag,
      this.size = 30,
      super.key});

  /// Darkened like the input border and the chip hairlines, so the pastel
  /// category presets stay readable on the white app bar.
  Color? _accent(String tagName) {
    final color = accentColorOf(tagName);
    return color == null ? null : darken(colorFromHex(color));
  }

  Color? _tint() {
    final typed = typedTag?.value;
    if (typed != null) {
      final accent = _accent(typed);
      if (accent != null) return accent;
    }

    for (final name in tagNames.reversed) {
      final accent = _accent(name);
      if (accent != null) return accent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final typed = typedTag;
    if (typed == null) return HomlMark(size: size, tint: _tint());

    return ValueListenableBuilder<String?>(
      valueListenable: typed,
      builder: (context, _, __) => HomlMark(size: size, tint: _tint()),
    );
  }
}
