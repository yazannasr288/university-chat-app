import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_icon_badge.dart';
import 'app_surface.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.gradient,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      width: double.infinity,
      padding: padding,
      gradient: gradient ?? context.appPrimaryGradient,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderColor: context.appBorder,
      boxShadow: context.isDark ? const [] : AppShadows.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 30 : 44,
            decoration: BoxDecoration(
              gradient: AppGradients.gold,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: context.isDark ? const [] : AppShadows.goldGlow,
            ),
          ),
          const AppGap.sm(axis: Axis.horizontal),
          if (icon != null) ...[
            AppIconBadge(
              icon: icon!,
              size: 46,
              iconSize: 24,
              color: context.appPrimary,
              backgroundColor: Colors.white.withValues(
                alpha: context.isDark ? 0.10 : 0.42,
              ),
              borderColor: Colors.white.withValues(alpha: 0.22),
              boxShadow: context.isDark ? const [] : AppShadows.subtle,
            ),
            const AppGap.md(axis: Axis.horizontal),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const AppGap(4),
                  Text(
                    subtitle!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const AppGap.md(axis: Axis.horizontal),
            trailing!,
          ],
        ],
      ),
    );
  }
}
