import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/colors.dart';

/// The app's own colors, light and dark: what the widgets paint with instead
/// of white and black, read through [HomlColorsOf.homl].
@immutable
class HomlColors extends ThemeExtension<HomlColors> {
  /// Text, icons and the monochrome controls (buttons, focus, selection).
  final Color ink;

  /// Cards, sheets, dialogs, the app bar and the toasts.
  final Color card;

  /// Behind the cards.
  final Color background;

  /// The filled text fields.
  final Color field;

  /// The hairline around a card or a field.
  final Color hairline;

  /// The soft shadow under a card.
  final Color shadow;

  /// A quiet fill: the selected segment, the track of a switch turned off.
  final Color quiet;

  /// Thin rules and borders that must show (the app bar's bottom line).
  final Color rule;

  const HomlColors({
    required this.ink,
    required this.card,
    required this.background,
    required this.field,
    required this.hairline,
    required this.shadow,
    required this.quiet,
    required this.rule,
  });

  static const light = HomlColors(
    ink: Color(0xFF000000),
    card: Color(0xFFFFFFFF),
    background: Color(0xFFFBFBFB),
    field: Color(0xFFF4F4F2),
    hairline: Color(0x0F000000),
    shadow: Color(0x0A000000),
    quiet: Color(0xFFE9E9E7),
    rule: Color(0xFFB7B7B7),
  );

  /// Not black on white turned over: a soft white on deep greys, the cards
  /// a step above the background so they still read as cards.
  static const dark = HomlColors(
    ink: Color(0xFFECECEA),
    card: Color(0xFF1D1D1F),
    background: Color(0xFF121213),
    field: Color(0xFF29292B),
    hairline: Color(0x17FFFFFF),
    shadow: Color(0x40000000),
    quiet: Color(0xFF3A3A3C),
    rule: Color(0xFF4A4A4C),
  );

  @override
  HomlColors copyWith({
    Color? ink,
    Color? card,
    Color? background,
    Color? field,
    Color? hairline,
    Color? shadow,
    Color? quiet,
    Color? rule,
  }) =>
      HomlColors(
        ink: ink ?? this.ink,
        card: card ?? this.card,
        background: background ?? this.background,
        field: field ?? this.field,
        hairline: hairline ?? this.hairline,
        shadow: shadow ?? this.shadow,
        quiet: quiet ?? this.quiet,
        rule: rule ?? this.rule,
      );

  @override
  HomlColors lerp(HomlColors? other, double t) {
    if (other == null) return this;
    return HomlColors(
      ink: Color.lerp(ink, other.ink, t)!,
      card: Color.lerp(card, other.card, t)!,
      background: Color.lerp(background, other.background, t)!,
      field: Color.lerp(field, other.field, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      quiet: Color.lerp(quiet, other.quiet, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
    );
  }
}

extension HomlColorsOf on BuildContext {
  /// The app's colors for the current brightness; the light ones under a
  /// theme without them (a bare MaterialApp, in the tests).
  HomlColors get homl =>
      Theme.of(this).extension<HomlColors>() ?? HomlColors.light;
}

/// Global theme of the app: Encode Sans, plain surfaces, monochrome ink
/// controls (buttons, focus, selection); the gold #D3A934 stays confined to
/// the logo and small accents. [brightness] picks the light or the dark
/// colors ([HomlColors]); everything else is the same.
ThemeData homlTheme({Brightness brightness = Brightness.light}) {
  const fontFamily = 'Encode Sans';
  final colors =
      brightness == Brightness.dark ? HomlColors.dark : HomlColors.light;
  final ink = colors.ink;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: brightness,
    primary: ink,
    onPrimary: colors.background,
    secondary: yellow,
    surface: colors.card,
    onSurface: ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: fontFamily,
    colorScheme: colorScheme,
    extensions: [colors],
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.card,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: colors.rule, width: 0.5)),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.field,
      labelStyle: TextStyle(color: ink.withValues(alpha: 0.45), fontSize: 14),
      // Under the floating label, a size below the typed text: an example,
      // not a value.
      hintStyle: TextStyle(color: ink.withValues(alpha: 0.35), fontSize: 14),
      floatingLabelStyle:
          TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // Hairline on the filled fields: they melt into the background
      // otherwise.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: colors.background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: colors.background,
      shape: const StadiumBorder(),
      extendedTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    // Period picker of the insert form. Material 3 fills the selected segment
    // with the scheme's secondaryContainer, which the black seed turns into a
    // washed red — the only warm surface in the app. Back to the monochrome
    // ink of the other controls: the quiet grey of the switch track, under a
    // label the weight sets apart.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.quiet
                : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? ink
                : ink.withValues(alpha: 0.55)),
        overlayColor: WidgetStatePropertyAll(ink.withValues(alpha: 0.06)),
        side: WidgetStatePropertyAll(
            BorderSide(color: ink.withValues(alpha: 0.12))),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        )),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
    dividerTheme: DividerThemeData(
      color: ink.withValues(alpha: 0.2),
      thickness: 0.5,
      space: 0.5,
    ),
    // Notifications as floating toasts on the card color. They are always
    // shown through `showToast` (lib/helpers/toast.dart), which owns the
    // durations and makes the whole surface tappable to dismiss.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.card,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.hairline),
      ),
      contentTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      actionTextColor: ink,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? ink : colors.quiet),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? colors.card
              : const Color(0xFF9A9A96)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: ink.withValues(alpha: 0.65),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.5,
        color: ink.withValues(alpha: 0.45),
      ),
    ),
  );
}
