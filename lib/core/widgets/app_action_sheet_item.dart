import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon_badge.dart';

class AppActionSheetItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;
  final bool vertical;

  const AppActionSheetItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
    this.enabled = true,
    this.dense = false,
    this.vertical = false,
  });

  const AppActionSheetItem.card({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
    this.enabled = true,
  })  : dense = false,
        vertical = true;

  const AppActionSheetItem.tile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
    this.enabled = true,
    this.dense = false,
  }) : vertical = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.appPrimary;
    final alpha = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: alpha,
      child: Material(
        color: effectiveColor.withValues(alpha: context.isDark ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: vertical
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
                : EdgeInsets.symmetric(
                    horizontal: dense ? 12 : 14,
                    vertical: dense ? 10 : 12,
                  ),
            decoration: AppDecorations.surface(
              color: Colors.transparent,
              borderRadius: AppDecorations.radius(AppRadii.lg),
              borderColor: effectiveColor.withValues(alpha: 0.18),
            ),
            child: vertical
                ? _VerticalContent(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    color: effectiveColor,
                  )
                : _HorizontalContent(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    color: effectiveColor,
                  ),
          ),
        ),
      ),
    );
  }
}

class _VerticalContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  const _VerticalContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionIcon(icon: icon, color: color, size: 48),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: context.appTextPrimary,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: context.appTextSecondary,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _HorizontalContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  const _HorizontalContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionIcon(icon: icon, color: color, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconBadge.circle(
      icon: icon,
      size: size,
      iconSize: size * 0.50,
      color: color,
      backgroundColor: color.withValues(alpha: context.isDark ? 0.22 : 0.13),
    );
  }
}
