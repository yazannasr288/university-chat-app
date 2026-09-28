import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_metric_card.dart';

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return AppMetricCard.vertical(
      width: compact ? 155 : 175,
      title: title,
      value: value,
      icon: icon,
      color: context.appPrimary,
      surfaceColor: context.appCardColorStrong,
    );
  }
}
