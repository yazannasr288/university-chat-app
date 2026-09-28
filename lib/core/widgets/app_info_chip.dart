import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';

class AppInfoChip extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String value;
  final Color? color;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool showBorder;

  const AppInfoChip({
    super.key,
    this.icon,
    this.label,
    required this.value,
    this.color,
    this.maxWidth = 240,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.accent;
    final text = label == null || label!.trim().isEmpty
        ? value
        : '${label!.trim()}: $value';

    return Container(
      padding: padding,
      decoration: AppDecorations.pill(
        color: context.appSurfaceSoft,
        borderColor: showBorder ? context.appBorder : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: effectiveColor),
            const AppGap.horizontal(8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
