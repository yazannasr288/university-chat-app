import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon_badge.dart';

class AppInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final Color? iconColor;
  final Color? valueColor;
  final EdgeInsetsGeometry padding;
  final int titleMaxLines;
  final int valueMaxLines;

  const AppInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.iconColor,
    this.valueColor,
    this.padding = const EdgeInsets.symmetric(vertical: 7),
    this.titleMaxLines = 2,
    this.valueMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.appPrimary;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            size: 34,
            iconSize: 18,
            color: effectiveIconColor,
            backgroundColor: effectiveIconColor.withValues(alpha: 0.10),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: trailing ??
                Text(
                  value,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? context.appTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
