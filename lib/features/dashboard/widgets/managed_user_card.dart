import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/constants/app_account_statuses.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_compact_button.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/managed_user.dart';

class ManagedUserCard extends StatelessWidget {
  final ManagedUser user;
  final bool canManageAccount;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback? onManage;
  final VoidCallback? onFreeze;
  final VoidCallback? onUnfreeze;
  final VoidCallback? onRemove;
  final bool manageLoading;
  final bool freezeLoading;
  final bool unfreezeLoading;
  final bool removeLoading;

  const ManagedUserCard({
    super.key,
    required this.user,
    required this.canManageAccount,
    required this.isSelected,
    required this.onSelectionChanged,
    this.onManage,
    this.onFreeze,
    this.onUnfreeze,
    this.onRemove,
    this.manageLoading = false,
    this.freezeLoading = false,
    this.unfreezeLoading = false,
    this.removeLoading = false,
  });

  Color _statusColor() {
    switch (user.accountStatus) {
      case AppAccountStatuses.suspended:
        return AppColors.accent;
      case AppAccountStatuses.removed:
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  String _statusLabel() {
    switch (user.accountStatus) {
      case AppAccountStatuses.suspended:
        return tr('dashboard.status_suspended');
      case AppAccountStatuses.removed:
        return tr('dashboard.status_removed');
      default:
        return tr('dashboard.status_active');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return AppSurface.card(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColor,
      borderColor: isSelected ? AppColors.primary : context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      boxShadow: isSelected ? AppShadows.subtle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),
              AppIconBadge.circle(
                icon: Icons.person_rounded,
                color: statusColor,
                backgroundColor: statusColor.withValues(alpha: 0.14),
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0] : '?',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${localizedRoleLabel(user.role, accountType: user.accountType)}'
                      ' • ${user.department}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: _statusLabel(),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                tr('dashboard.student_id_label'),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                user.userId,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('dashboard.phone', args: [user.phone]),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onManage != null)
                AppCompactButton(
                  text: tr('dashboard.manage'),
                  icon: Icons.edit_rounded,
                  loading: manageLoading,
                  onPressed: onManage,
                ),
              if (canManageAccount && onFreeze != null)
                AppCompactButton(
                  text: tr('dashboard.freeze'),
                  icon: Icons.block_rounded,
                  outlined: true,
                  loading: freezeLoading,
                  onPressed: onFreeze,
                ),
              if (canManageAccount && onUnfreeze != null)
                AppCompactButton(
                  text: tr('dashboard.unfreeze'),
                  icon: Icons.restart_alt_rounded,
                  outlined: true,
                  loading: unfreezeLoading,
                  onPressed: onUnfreeze,
                ),
              if (canManageAccount && onRemove != null)
                AppCompactButton(
                  text: tr('dashboard.remove'),
                  icon: Icons.person_remove_rounded,
                  backgroundColor: AppColors.error,
                  loading: removeLoading,
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
