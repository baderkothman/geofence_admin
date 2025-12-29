// D:\geofence_project\geofence_admin\lib\core\theme\app_tokens.dart

import "package:flutter/material.dart";

/// Design tokens used to keep the app’s UI consistent.
///
/// This includes:
/// - shared radius values
/// - light/dark palette colors
/// - semantic colors (success/danger/warning)
class AppTokens {
  /// Base radius used across cards and containers.
  static const double radius = 20;

  // Light theme palette
  static const lightBackground = Color(0xFFFCFAF8);
  static const lightForeground = Color(0xFF1D2930);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF2999A3);
  static const lightSecondary = Color(0xFFEEF0F1);
  static const lightMuted = Color(0xFFE9EBED);
  static const lightMutedFg = Color(0xFF627884);
  static const lightBorder = Color(0xFFDCE2E5);
  static const lightSurfaceSoft = Color(0xFFF4F5F6);

  // Dark theme palette
  static const darkBackground = Color(0xFF0F1729);
  static const darkForeground = Color(0xFFF3F4F6);
  static const darkCard = Color(0xFF121B31);
  static const darkPrimary = Color(0xFF39BAC6);
  static const darkSecondary = Color(0xFF222C3A);
  static const darkMuted = Color(0xFF29313D);
  static const darkMutedFg = Color(0xFFA7B1BE);
  static const darkBorder = Color(0xFF394960);
  static const darkSurfaceSoft = Color(0xFF16213B);

  // Semantic colors
  static const success = Color(0xFF2BAB7C);
  static const danger = Color(0xFFD92626);
  static const warning = Color(0xFFFFC61A);
}
