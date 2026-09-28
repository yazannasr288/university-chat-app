import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTileCard(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      onTap: onTap,
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
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: context.appTextMuted,
      ),
    );
  }
}
