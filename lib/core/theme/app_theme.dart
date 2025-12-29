// D:\geofence_project\geofence_admin\lib\core\theme\app_theme.dart

import "package:flutter/material.dart";
import "app_tokens.dart";

/// Theme builder for the app (Material 3).
///
/// Creates a consistent ThemeData for:
/// - Light mode
/// - Dark mode
///
/// Key customizations:
/// - ColorScheme tuned to your token palette
/// - Rounded “pill” inputs
/// - CardThemeData with borders (instead of elevation)
/// - NavigationBar indicator color based on alpha
class AppTheme {
  /// Light theme configuration.
  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: AppTokens.lightBackground,
    foreground: AppTokens.lightForeground,
    card: AppTokens.lightCard,
    primary: AppTokens.lightPrimary,
    secondary: AppTokens.lightSecondary,
    mutedFg: AppTokens.lightMutedFg,
    border: AppTokens.lightBorder,
    surfaceSoft: AppTokens.lightSurfaceSoft,
  );

  /// Dark theme configuration.
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: AppTokens.darkBackground,
    foreground: AppTokens.darkForeground,
    card: AppTokens.darkCard,
    primary: AppTokens.darkPrimary,
    secondary: AppTokens.darkSecondary,
    mutedFg: AppTokens.darkMutedFg,
    border: AppTokens.darkBorder,
    surfaceSoft: AppTokens.darkSurfaceSoft,
  );

  /// Internal theme builder shared by both light/dark.
  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color foreground,
    required Color card,
    required Color primary,
    required Color secondary,
    required Color mutedFg,
    required Color border,
    required Color surfaceSoft,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF0E1525) : Colors.white,
      secondary: secondary,
      onSecondary: foreground,
      error: AppTokens.danger,
      onError: Colors.white,
      surface: card,
      onSurface: foreground,
    );

    // Indicator alpha tuned separately for light/dark so it reads correctly.
    final navIndicatorAlpha = isDark ? 46 : 36;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // Cards are “flat” with border and radius; elevation removed for cleaner UI.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius + 8),
          side: BorderSide(color: border),
        ),
      ),

      // Pill-like inputs for consistent admin UI.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: TextStyle(color: mutedFg),
        labelStyle: TextStyle(color: mutedFg),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withAlpha(navIndicatorAlpha),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}
