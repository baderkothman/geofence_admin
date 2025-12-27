import "package:flutter/material.dart";

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

    final shadowBase = theme.brightness == Brightness.dark
        ? Colors.black
        : const Color(0xFF0F172A);

    // 0.55 * 255 ≈ 140, 0.08 * 255 ≈ 20
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
