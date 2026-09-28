import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';

/// A reusable status/metric chip used across pages, dashboards and sheets.
///
/// It keeps the same visual language for badges such as loading/ready states,
/// counters, import metrics and lightweight status labels without duplicating
/// decoration code in feature widgets.
class AppStatusChip extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final String? value;
  final Color? color;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool filled;
  final bool compact;
  final bool showBorder;
  final double? minWidth;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const AppStatusChip({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.value,
    this.color,
    this.backgroundColor,
    this.foregroundColor,
    this.filled = true,
    this.compact = true,
    this.showBorder = true,
    this.minWidth,
    this.padding,
    this.borderRadius,
  });

  const AppStatusChip.metric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.backgroundColor,
    this.foregroundColor,
    this.showBorder = true,
    this.minWidth = 145,
    this.borderRadius,
  })  : leading = null,
        filled = true,
        compact = false,
        padding = const EdgeInsets.all(AppSpacing.sm);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = foregroundColor ?? color ?? context.appPrimary;
    final effectiveBackground = backgroundColor ??
        (filled
            ? effectiveColor.withValues(alpha: context.isDark ? 0.16 : 0.10)
            : Colors.transparent);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: compact ? 10 : AppSpacing.sm,
          vertical: compact ? 7 : AppSpacing.sm,
        );

    return Container(
      constraints: minWidth == null
          ? const BoxConstraints()
          : BoxConstraints(minWidth: minWidth!),
      padding: effectivePadding,
      decoration: AppDecorations.surface(
        color: effectiveBackground,
        borderRadius: borderRadius ??
            AppDecorations.radius(compact ? AppRadii.pill : AppRadii.md),
        borderColor:
            showBorder ? effectiveColor.withValues(alpha: 0.18) : null,
      ),
      child: value == null
          ? _CompactContent(
              icon: icon,
              leading: leading,
              label: label,
              color: effectiveColor,
            )
          : _MetricContent(
              icon: icon,
              label: label,
              value: value!,
              color: effectiveColor,
            ),
    );
  }
}

class _CompactContent extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color color;

  const _CompactContent({
    required this.icon,
    required this.leading,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const AppGap.horizontal(8),
        ] else if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const AppGap.horizontal(6),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricContent extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color color;

  const _MetricContent({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: AppDecorations.rounded(
              color: color.withValues(alpha: 0.12),
              radius: AppRadii.sm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const AppGap.xs(axis: Axis.horizontal),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
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
                style: context.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
