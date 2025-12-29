// D:\geofence_project\geofence_admin\lib\core\widgets\gradient_pill_button.dart

import "package:flutter/material.dart";

/// A reusable “pill” shaped button with a linear gradient background.
///
/// This widget:
/// - Draws the gradient + shadow using a wrapping Container.
/// - Uses an ElevatedButton with transparent background to preserve ripple/ink.
///
/// If `onPressed` is null, the widget renders at reduced opacity.
class GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final IconData? icon;

  const GradientPillButton({
    super.key,
    required this.label,
    required this.colors,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Shadow opacity tuned for a “soft glow” effect without looking heavy.
    const shadowAlpha = 102; // ~40%

    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              offset: const Offset(0, 10),
              color: colors.last.withAlpha(shadowAlpha),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
