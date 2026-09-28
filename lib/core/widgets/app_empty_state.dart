import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_gap.dart';
import 'app_icon_badge.dart';
import 'app_loader.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final bool actionLoading;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge.circle(
                icon: icon,
                size: 96,
                iconSize: 44,
                gradient: context.appPrimaryGradient,
                color: context.appPrimary,
                borderColor: context.appBorder,
                boxShadow: AppShadows.subtle,
              ),
              const AppGap(18),
              Text(
                text,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.appTextSecondary,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const AppGap.lg(),
                OutlinedButton.icon(
                  onPressed: actionLoading ? null : onAction,
                  icon: actionLoading
                      ? const AppLoader.inline(size: 18, strokeWidth: 2)
                      : Icon(actionIcon),
                  label: Text(
                    actionLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
