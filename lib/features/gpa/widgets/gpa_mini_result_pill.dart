import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class GpaMiniResultPill extends StatelessWidget {
  final String label;
  final String value;

  const GpaMiniResultPill({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.pill(
        color: context.appCardColor,
        borderColor: context.appBorder,
      ),
      child: Text(
        '$label: $value',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.appTextSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
