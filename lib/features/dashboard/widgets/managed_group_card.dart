import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_compact_button.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/managed_group_summary.dart';

class ManagedGroupCard extends StatelessWidget {
  final ManagedGroupSummary group;
  final VoidCallback onManage;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onDelete;
  final bool manageLoading;
  final bool archiveLoading;
  final bool unarchiveLoading;
  final bool deleteLoading;

  const ManagedGroupCard({
    super.key,
    required this.group,
    required this.onManage,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
    this.manageLoading = false,
    this.archiveLoading = false,
    this.unarchiveLoading = false,
    this.deleteLoading = false,
  });

  Color _statusColor() {
    return group.isActive ? AppColors.success : AppColors.accent;
  }

  String _statusLabel() {
    return group.isActive
        ? tr('dashboard.group_status_active')
        : tr('dashboard.group_status_archived');
  }



  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return AppSurface.card(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColor,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge.circle(
                icon: Icons.groups_rounded,
                color: statusColor,
                backgroundColor: statusColor.withValues(alpha: 0.14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w700,

                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.department} • ${group.membersCount} ${tr('dashboard.group_members_count_suffix')}',
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
          Text(
            '${tr('dashboard.group_admin')}: ${group.adminName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${tr('dashboard.group_department')}: ${group.department}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${tr('dashboard.group_members_count')}: ${group.membersCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          if (group.recentMessage.isNotEmpty || group.recentMessageEn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('dashboard.group_recent_message')}: ${context.locale.languageCode == 'en' && group.recentMessageEn.isNotEmpty ? group.recentMessageEn : group.recentMessage}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppCompactButton(
                text: tr('dashboard.group_manage'),
                icon: Icons.edit_rounded,
                loading: manageLoading,
                onPressed: onManage,
              ),
              if (onArchive != null)
                AppCompactButton(
                  text: tr('dashboard.group_archive'),
                  icon: Icons.archive_rounded,
                  outlined: true,
                  loading: archiveLoading,
                  onPressed: onArchive,
                ),
              if (onUnarchive != null)
                AppCompactButton(
                  text: tr('dashboard.group_unarchive'),
                  icon: Icons.unarchive_rounded,
                  outlined: true,
                  loading: unarchiveLoading,
                  onPressed: onUnarchive,
                ),
              if (onDelete != null)
                AppCompactButton(
                  text: tr('dashboard.group_delete'),
                  icon: Icons.delete_forever_rounded,
                  backgroundColor: AppColors.error,
                  loading: deleteLoading,
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
