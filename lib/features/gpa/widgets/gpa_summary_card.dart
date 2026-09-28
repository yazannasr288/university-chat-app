import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_metric_card.dart';

class GpaSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const GpaSummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppMetricCard.horizontal(
      title: label,
      value: value,
      subtitle: subtitle,
      icon: icon,
      color: color,
      surfaceColor: context.appCardColor,
      boxShadow: context.isDark ? const [] : AppShadows.subtle,
    );
  }
}
