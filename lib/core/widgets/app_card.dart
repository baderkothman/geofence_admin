// D:\geofence_project\geofence_admin\lib\core\widgets\app_card.dart

import "package:flutter/material.dart";

/// A custom card container with a consistent visual style across the app.
///
/// Differences from a plain `Card`:
/// - Uses a controlled shadow intensity depending on theme brightness.
/// - Applies a consistent border radius.
/// - Applies a border matching the current divider color.
///
/// Useful for layouts where you want the “card look” without Material elevation.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Shadow base color differs by theme for better realism.
    final shadowBase = theme.brightness == Brightness.dark
        ? Colors.black
        : const Color(0xFF0F172A);

    // Opacity tuned to keep shadows subtle, especially in light mode.
    final shadowAlpha = theme.brightness == Brightness.dark ? 140 : 20;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            blurRadius: theme.brightness == Brightness.dark ? 35 : 30,
            offset: Offset(0, theme.brightness == Brightness.dark ? 12 : 10),
            color: shadowBase.withAlpha(shadowAlpha),
          ),
        ],
      ),
      child: child,
    );
  }
}
