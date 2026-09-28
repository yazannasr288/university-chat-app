import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTileCard(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      leading: AppIconBadge(
        icon: icon,
        size: 44,
        iconSize: 22,
        backgroundColor: context.isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primarySoft,
        color: context.isDark ? AppColors.accent : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}
