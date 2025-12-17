import 'package:flutter/material.dart';

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

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28), // web-like rounded card
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            blurRadius: theme.brightness == Brightness.dark ? 35 : 30,
            offset: Offset(0, theme.brightness == Brightness.dark ? 12 : 10),
            color:
                (theme.brightness == Brightness.dark
                        ? Colors.black
                        : const Color(0xFF0F172A))
                    .withOpacity(
                      theme.brightness == Brightness.dark ? 0.55 : 0.08,
                    ),
          ),
        ],
      ),
      child: child,
    );
  }
}
