import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_surface.dart';

class AppListTileCard extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  const AppListTileCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.card(
      margin: margin,
      padding: padding,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      boxShadow: context.isDark ? const [] : AppShadows.subtle,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (leading != null) ...[
            leading!,
            const AppGap.md(axis: Axis.horizontal),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const AppGap(4),
                  DefaultTextStyle.merge(
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.appTextSecondary,
                      height: 1.35,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const AppGap.sm(axis: Axis.horizontal),
            trailing!,
          ],
        ],
      ),
    );
  }
}
