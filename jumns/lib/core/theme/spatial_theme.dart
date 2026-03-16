import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'spatial_colors.dart';

/// Spatial OS theme — clean sans-serif, soft shadows, glassmorphism.
ThemeData spatialTheme() {
  final body = GoogleFonts.plusJakartaSansTextTheme();
  final display = GoogleFonts.interTextTheme();

  final textTheme = body.copyWith(
    displayLarge: display.displayLarge?.copyWith(color: SpatialColors.textPrimary),
    displayMedium: display.displayMedium?.copyWith(color: SpatialColors.textPrimary),
    displaySmall: display.displaySmall?.copyWith(color: SpatialColors.textPrimary),
    headlineLarge: display.headlineLarge?.copyWith(color: SpatialColors.textPrimary, letterSpacing: -0.6),
    headlineMedium: display.headlineMedium?.copyWith(color: SpatialColors.textPrimary),
    headlineSmall: display.headlineSmall?.copyWith(color: SpatialColors.textPrimary),
    titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
    titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
    titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
    bodyLarge: body.bodyLarge?.copyWith(color: SpatialColors.textSecondary, height: 1.625),
    bodyMedium: body.bodyMedium?.copyWith(color: SpatialColors.textSecondary),
    bodySmall: body.bodySmall?.copyWith(color: SpatialColors.textTertiary),
    labelLarge: display.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2, color: SpatialColors.textTertiary),
    labelMedium: display.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: SpatialColors.textTertiary),
    labelSmall: display.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: SpatialColors.textMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SpatialColors.background,
    colorScheme: const ColorScheme.light(
      surface: SpatialColors.surface,
      surfaceContainer: SpatialColors.surfaceMuted,
      primary: SpatialColors.textPrimary,
      onPrimary: SpatialColors.surface,
      secondary: SpatialColors.agentViolet,
      tertiary: SpatialColors.agentPink,
      onSurface: SpatialColors.textPrimary,
      onSurfaceVariant: SpatialColors.textTertiary,
      outline: SpatialColors.surfaceMuted,
      error: Color(0xFFEF4444),
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: SpatialColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: SpatialColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: SpatialColors.surfaceSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SpatialColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(
        color: SpatialColors.textSecondary.withAlpha(77),
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SpatialColors.textPrimary,
        foregroundColor: SpatialColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: SpatialColors.surfaceMuted,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SpatialColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
