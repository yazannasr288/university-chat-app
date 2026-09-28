import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_icon_badge.dart';
import 'app_surface.dart';

enum AppMetricCardLayout { horizontal, vertical }

/// Reusable visual card for numeric summaries and compact dashboard metrics.
class AppMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final double? width;
  final EdgeInsetsGeometry padding;
  final AppMetricCardLayout layout;
  final Color? surfaceColor;
  final List<BoxShadow>? boxShadow;

  const AppMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.width,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.layout = AppMetricCardLayout.horizontal,
    this.surfaceColor,
    this.boxShadow,
  });

  const AppMetricCard.horizontal({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.width,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.surfaceColor,
    this.boxShadow,
  }) : layout = AppMetricCardLayout.horizontal;

  const AppMetricCard.vertical({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.width,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.surfaceColor,
    this.boxShadow,
  }) : layout = AppMetricCardLayout.vertical;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.appPrimary;
    final effectiveShadow = boxShadow ??
        (context.isDark ? const <BoxShadow>[] : AppShadows.subtle);

    return AppSurface.card(
      width: width,
      padding: padding,
      color: surfaceColor ?? context.appCardColor,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      boxShadow: effectiveShadow,
      child: layout == AppMetricCardLayout.vertical
          ? _VerticalMetricContent(
              title: title,
              value: value,
              subtitle: subtitle,
              icon: icon,
              color: effectiveColor,
            )
          : _HorizontalMetricContent(
              title: title,
              value: value,
              subtitle: subtitle,
              icon: icon,
              color: effectiveColor,
            ),
    );
  }
}

class _HorizontalMetricContent extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _HorizontalMetricContent({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconBadge(
          icon: icon,
          size: 50,
          iconSize: 24,
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
          borderRadius: AppDecorations.radius(AppRadii.lg),
        ),
        const AppGap.md(axis: Axis.horizontal),
        Expanded(
          child: _MetricTexts(
            title: title,
            value: value,
            subtitle: subtitle,
            color: color,
            valueStyle: context.textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}

class _VerticalMetricContent extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _VerticalMetricContent({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: icon,
          size: 42,
          iconSize: 22,
          color: color,
          backgroundColor: color.withValues(alpha: 0.10),
        ),
        const AppGap.sm(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.headlineSmall?.copyWith(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const AppGap(6),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.appTextSecondary,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const AppGap(2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.appTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTexts extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final TextStyle? valueStyle;

  const _MetricTexts({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const AppGap(2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const AppGap(2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.appTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
