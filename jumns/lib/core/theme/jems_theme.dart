import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'jems_colors.dart';

/// Charcoal Sketch theme — handwritten fonts, wobbly borders, paper texture.
ThemeData jemsTheme() {
  // Gloria Hallelujah = display/headings, Patrick Hand = body text
  final displayFont = GoogleFonts.gloriaHallelujahTextTheme();
  final bodyFont = GoogleFonts.patrickHandTextTheme();

  final textTheme = bodyFont.copyWith(
    displayLarge: displayFont.displayLarge?.copyWith(color: JemsColors.charcoal),
    displayMedium: displayFont.displayMedium?.copyWith(color: JemsColors.charcoal),
    displaySmall: displayFont.displaySmall?.copyWith(color: JemsColors.charcoal),
    headlineLarge: displayFont.headlineLarge?.copyWith(color: JemsColors.charcoal),
    headlineMedium: displayFont.headlineMedium?.copyWith(color: JemsColors.charcoal),
    headlineSmall: displayFont.headlineSmall?.copyWith(color: JemsColors.charcoal),
    titleLarge: displayFont.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: JemsColors.charcoal,
    ),
    titleMedium: displayFont.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: JemsColors.charcoal,
    ),
    titleSmall: displayFont.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: JemsColors.charcoal,
    ),
    bodyLarge: bodyFont.bodyLarge?.copyWith(color: JemsColors.charcoal),
    bodyMedium: bodyFont.bodyMedium?.copyWith(color: JemsColors.charcoal),
    bodySmall: bodyFont.bodySmall?.copyWith(color: JemsColors.ink),
    labelLarge: bodyFont.labelLarge?.copyWith(color: JemsColors.charcoal),
    labelMedium: bodyFont.labelMedium?.copyWith(color: JemsColors.charcoal),
    labelSmall: bodyFont.labelSmall?.copyWith(color: JemsColors.charcoal),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: JemsColors.paper,
    colorScheme: const ColorScheme.light(
      surface: JemsColors.surface,
      surfaceContainer: JemsColors.paperDark,
      primary: JemsColors.charcoal,
      onPrimary: JemsColors.paper,
      secondary: JemsColors.lavender,
      tertiary: JemsColors.coral,
      onSurface: JemsColors.charcoal,
      onSurfaceVariant: JemsColors.ink,
      outline: JemsColors.ink,
      error: JemsColors.error,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: JemsColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: JemsColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: JemsColors.ink, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: JemsColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: JemsColors.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: JemsColors.ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: JemsColors.charcoal, width: 2.5),
      ),
      hintStyle: TextStyle(
        color: JemsColors.ink.withAlpha(100),
        fontFamily: GoogleFonts.architectsDaughter().fontFamily,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: JemsColors.charcoal,
        foregroundColor: JemsColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          fontFamily: GoogleFonts.architectsDaughter().fontFamily,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: JemsColors.charcoal,
        side: const BorderSide(color: JemsColors.ink, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: JemsColors.ink,
      thickness: 2,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: JemsColors.paper,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: JemsColors.charcoal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
