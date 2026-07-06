import 'package:flutter/material.dart';

import 'package:homl/helpers/colors.dart';

/// Global theme derived from the Figma "Search Page" export: Encode Sans,
/// white surfaces with hairline grey borders and the yellow #D3A934 accent.
ThemeData homlTheme() {
  const fontFamily = 'Encode Sans';

  final colorScheme = ColorScheme.fromSeed(
    seedColor: yellow,
    primary: yellow,
    onPrimary: Colors.white,
    secondary: blue,
    surface: Colors.white,
    onSurface: ink,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: borderGrey, width: 0.5)),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: yellow, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: yellow, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: yellow, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: yellow, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: yellow, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: yellow,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: yellow),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: yellow,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: yellow),
    dividerTheme: DividerThemeData(
      color: Colors.black.withValues(alpha: 0.2),
      thickness: 0.5,
      space: 0.5,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: Colors.white),
      actionTextColor: yellow,
    ),
  );
}
