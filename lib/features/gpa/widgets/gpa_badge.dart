import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class GpaCircularBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const GpaCircularBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: AppDecorations.circle(
        color: color.withValues(alpha: 0.12),
        borderColor: color.withValues(alpha: 0.35),
        borderWidth: 1.4,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.appTextSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
