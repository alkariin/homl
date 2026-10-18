import 'package:material_ui/material_ui.dart';

/// Design palette of the app.
const Color yellow = Color(0xFFD3A934);

/// [yellow] as the backend "#RRGGBB" convention (e.g. the fixed color of the
/// Dates category).
const String yellowHex = "#D3A934";
const Color blue = Color(0xFF14B7EB);

// Ink, cards, the background and the rules depend on the brightness: they
// are the theme's (HomlColors in lib/helpers/theme.dart, `context.homl`).

/// Legacy header color, kept for the pastel category presets below.
const Color primary = Color(0xfff2e5c2);

/// Parses a backend "#RRGGBB" color string, falling back to the default
/// pastel when the value is malformed.
Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceAll("#", "0xff"));
  return value == null ? primary : Color(value);
}

/// Darkens a color so pastel category colors stay readable as thin borders.
Color darken(Color color, [double amount = .25]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Preset colors offered when creating/editing a category (hex strings,
/// stored as-is by the backend).
const List<String> categoryColors = [
  "#f2e5c2",
  "#f28b82",
  "#fbbc04",
  "#fff475",
  "#ccff90",
  "#a7ffeb",
  "#cbf0f8",
  "#aecbfa",
  "#d7aefb",
  "#fdcfe8",
  "#e6c9a8",
  "#e8eaed",
];
