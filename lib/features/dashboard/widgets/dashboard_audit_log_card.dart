import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/constants/app_audit_filters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/dashboard_audit_log.dart';

class DashboardAuditLogCard extends StatelessWidget {
  final DashboardAuditLog log;

  const DashboardAuditLogCard({super.key, required this.log});

  static const Map<String, String> _actionTitles = {
    'event.created': 'audit.action.event_created',
    'event.updated': 'audit.action.event_updated',
    'event.cancelled': 'audit.action.event_cancelled',
    'student.created': 'audit.action.student_created',
    'bulk_import.started': 'audit.action.bulk_import_started',
    'bulk_import.finished': 'audit.action.bulk_import_finished',
    'user.suspended': 'audit.action.user_suspended',
    'user.unsuspended': 'audit.action.user_unsuspended',
    'user.unfrozen': 'audit.action.user_unsuspended',
    'user.removed': 'audit.action.user_removed',
    'user.deleted': 'audit.action.user_deleted',
    'user.restored': 'audit.action.user_restored',
    'user.profile.updated': 'audit.action.user_profile_updated',
    'user.password.reset': 'audit.action.user_password_reset',
    'user.pin.reset': 'audit.action.user_pin_reset',
    'group.created': 'audit.action.group_created',
    'group.members.added': 'audit.action.group_members_added',
    'group.member.removed': 'audit.action.group_member_removed',
    'group.member.kicked': 'audit.action.group_member_kicked',
    'group.archived': 'audit.action.group_archived',
    'group.unarchived': 'audit.action.group_unarchived',
    'group.deleted': 'audit.action.group_deleted',
    'group.profile.updated': 'audit.action.group_profile_updated',
    'group.icon.updated': 'audit.action.group_icon_updated',
    'notification.campaign.created': 'audit.action.notification_campaign_created',
  };

  Color _levelColor() {
    switch (log.level) {
      case AppAuditLevels.critical:
        return AppColors.error;
      case AppAuditLevels.warning:
        return AppColors.accent;
      default:
        return AppColors.info;
    }
  }

  String _levelLabel() {
    switch (log.level) {
      case AppAuditLevels.critical:
        return AppAuditLevels.labelKey(AppAuditLevels.critical).tr();
      case AppAuditLevels.warning:
        return AppAuditLevels.labelKey(AppAuditLevels.warning).tr();
      case AppAuditLevels.info:
      default:
        return AppAuditLevels.labelKey(AppAuditLevels.info).tr();
    }
  }

  String _title() {
    final action = log.action.trim();
    final directTitle = _actionTitles[action];
    if (directTitle != null) return directTitle.tr();

    final translationKey = 'dashboard.audit_action_$action';
    final translated = translationKey.tr();
    if (translated != translationKey) return translated;

    return action.isEmpty ? 'audit.action.unknown'.tr() : action;
  }

  String _targetTypeLabel() {
    switch (log.targetType) {
      case 'user':
        return 'audit.target.user_or_student'.tr();
      case 'group':
        return 'audit.target.group'.tr();
      case 'event':
        return 'audit.target.event'.tr();
      case 'notification':
        return 'audit.target.notification'.tr();
      case 'system':
        return 'audit.target.system'.tr();
      default:
        return log.targetType;
    }
  }

  String _categoryLabel() => AppAuditCategories.labelKey(log.category).tr();

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool muted = false,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $trimmed',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium?.copyWith(
          color: muted ? context.appTextMuted : context.appTextSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();
    final created = log.createdAtMs > 0
        ? DateFormat('yyyy/MM/dd - HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(log.createdAtMs),
          )
        : '--';

    final actorParts = <String>[
      if (log.actorDisplayName.trim().isNotEmpty) log.actorDisplayName,
      localizedRoleLabel(log.actorRole),
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    final targetParts = <String>[
      _targetTypeLabel(),
      if (log.targetDisplayName.trim().isNotEmpty) log.targetDisplayName,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return AppSurface.card(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColorStrong,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      boxShadow: context.isDark ? const [] : AppShadows.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icons.history_rounded,
                size: 38,
                iconSize: 20,
                color: color,
                backgroundColor: color.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppStatusChip(
                label: _levelLabel(),
                color: color,
                backgroundColor: color.withValues(alpha: 0.10),
                showBorder: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line(context, 'common.department'.tr(), _categoryLabel()),
          _line(context, 'dashboard.audit_target'.tr(), targetParts),
          if (log.targetType == 'user')
            _line(
              context,
              'dashboard.audit_target_user_id'.tr(),
              log.targetUserId,
            ),
          _line(context, 'dashboard.audit_actor'.tr(), actorParts),
          _line(
            context,
            'dashboard.audit_actor_user_id'.tr(),
            log.actorUserId,
          ),
          _line(context, 'dashboard.audit_time'.tr(), created, muted: true),
          _line(context, 'dashboard.summary'.tr(), log.summary, muted: true),
        ],
      ),
    );
  }
}
