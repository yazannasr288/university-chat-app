import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_icon_badge.dart';
import 'app_surface.dart';

class AppNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;
  final Color? textColor;

  const AppNotice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.textAlign = TextAlign.start,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.appPrimary;

    return AppSurface.soft(
      padding: padding,
      color: backgroundColor ?? effectiveColor.withValues(alpha: 0.10),
      borderColor: effectiveColor.withValues(alpha: context.isDark ? 0.34 : 0.30),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconBadge(
            icon: icon,
            size: 34,
            iconSize: 18,
            color: effectiveColor,
            backgroundColor: effectiveColor.withValues(alpha: 0.10),
          ),
          const AppGap.sm(axis: Axis.horizontal),
          Expanded(
            child: Text(
              text,
              textAlign: textAlign,
              style: context.textTheme.bodyMedium?.copyWith(
                color: textColor ?? context.appTextPrimary,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
