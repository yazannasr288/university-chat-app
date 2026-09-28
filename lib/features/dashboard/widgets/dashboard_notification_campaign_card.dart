import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_info_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/notification_campaign.dart';

class DashboardNotificationCampaignCard extends StatelessWidget {
  final NotificationCampaign campaign;

  const DashboardNotificationCampaignCard({
    super.key,
    required this.campaign,
  });

  String _departmentLabel(String value) {
    if (value.trim().isEmpty) return '';
    return tr(AppDepartments.labelKey(value));
  }

  String _scopeLabel() {
    final targetDepartment = campaign.targetDepartment.trim();
    final targetDepartments = campaign.targetDepartments
        .map((department) => department.trim())
        .where((department) => department.isNotEmpty)
        .toSet()
        .toList();

    if (targetDepartment == 'all') {
      return tr('dashboard.all_departments');
    }

    if (targetDepartment.isNotEmpty) {
      return _departmentLabel(targetDepartment);
    }

    if (targetDepartments.isEmpty) return '';
    return targetDepartments.map(_departmentLabel).join('، ');
  }

  @override
  Widget build(BuildContext context) {
    final created = campaign.createdAtMs > 0
        ? DateFormat('yyyy/MM/dd - HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(campaign.createdAtMs),
          )
        : '--';
    final scopeLabel = _scopeLabel();

    return AppSurface.card(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColor,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaign.title,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            campaign.body,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppInfoChip(
                label: tr('dashboard.notification_recipients'),
                value: '${campaign.recipientsCount}',
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              AppInfoChip(
                label: tr('dashboard.notification_delivered'),
                value: '${campaign.deliveredTokenCount}',
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              if (scopeLabel.isNotEmpty)
                AppInfoChip(
                  label: tr('dashboard.notification_scope'),
                  value: scopeLabel,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              AppInfoChip(
                label: localizedRoleLabel(campaign.createdByRole),
                value: created,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
