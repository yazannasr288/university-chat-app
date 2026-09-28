import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_badge.dart';

class HomeDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const HomeDrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.appPrimary;
    final titleColor = color ?? context.appTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppDecorations.rounded(
              color: color != null
                  ? color!.withValues(alpha: 0.10)
                  : context.appDrawerItemBackground,
              radius: AppRadii.md,
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppIconBadge.circle(
                icon: icon,
                size: 40,
                color: effectiveColor,
                backgroundColor: effectiveColor.withValues(alpha: 0.12),
              ),
              title: Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: effectiveColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
