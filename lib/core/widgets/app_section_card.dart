import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_icon_badge.dart';
import 'app_surface.dart';

/// Shared section container for feature pages and dashboard blocks.
class AppSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double headerSpacing;
  final Color? color;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool showHeader;

  const AppSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.headerSpacing = AppSpacing.lg,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBoxShadow = boxShadow ??
        (context.isDark ? const <BoxShadow>[] : AppShadows.card);

    return AppSurface.card(
      width: double.infinity,
      padding: padding,
      color: color ?? context.appCardColor,
      borderColor: borderColor ?? context.appBorder,
      borderRadius: borderRadius ?? AppDecorations.radius(AppRadii.xl),
      boxShadow: effectiveBoxShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            _SectionHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              trailing: trailing,
            ),
            AppGap(headerSpacing),
          ],
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          AppIconBadge(
            icon: icon!,
            size: 42,
            iconSize: 22,
            color: context.appPrimary,
            backgroundColor: context.appPrimary.withValues(alpha: 0.12),
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
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const AppGap(3),
                Text(
                  subtitle!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600,
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
    );
  }
}
