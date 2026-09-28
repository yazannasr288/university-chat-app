import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_gap.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_surface.dart';

class DashboardQuickActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardQuickActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final color = context.appPrimary;

    return AppSurface.soft(
      width: compact ? 148 : 160,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appSurfaceSoft,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            size: 40,
            iconSize: 21,
            color: color,
            backgroundColor: color.withValues(alpha: 0.10),
          ),
          const AppGap.sm(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
