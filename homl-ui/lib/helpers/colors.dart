import 'package:flutter/material.dart';

/// Design palette of the app.
const Color yellow = Color(0xFFD3A934);
const Color blue = Color(0xFF14B7EB);
const Color background = Color(0xFFFBFBFB);
const Color borderGrey = Color(0xFFB7B7B7);
const Color ink = Color(0xFF000000);

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
