import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class BulkImportStatusCard extends StatelessWidget {
  final String activeJobId;
  final String statusText;
  final double progressValue;
  final bool isJobRunning;
  final int totalStudents;
  final int processedChunks;
  final int totalChunks;
  final int successCount;
  final int failCount;
  final String jobStatus;

  const BulkImportStatusCard({
    super.key,
    required this.jobStatus,
    required this.activeJobId,
    required this.statusText,
    required this.progressValue,
    required this.isJobRunning,
    required this.totalStudents,
    required this.processedChunks,
    required this.totalChunks,
    required this.successCount,
    required this.failCount,
  });

  String get _jobLabel {
    if (activeJobId.length <= 12) return activeJobId;
    return '${activeJobId.substring(0, 12)}...';
  }

  @override
  Widget build(BuildContext context) {
    String stateLabel() {
      switch (jobStatus) {
        case 'partial_failed':
          return tr('auth.bulk_import.partially_completed');
        case 'failed':
          return tr('common.failed');
        case 'done':
          return tr('common.completed');
        default:
          return tr('common.in_progress');
      }
    }

    Color stateBackground() {
      final alpha = context.isDark ? 0.16 : 1.0;
      switch (jobStatus) {
        case 'partial_failed':
          return context.isDark
              ? AppColors.warning.withValues(alpha: alpha)
              : AppColors.warningSoft;
        case 'failed':
          return context.isDark
              ? AppColors.error.withValues(alpha: alpha)
              : AppColors.errorSoft;
        case 'done':
          return context.isDark
              ? AppColors.success.withValues(alpha: alpha)
              : AppColors.successSoft;
        default:
          return context.isDark
              ? AppColors.info.withValues(alpha: alpha)
              : AppColors.infoSoft;
      }
    }

    Color stateForeground() {
      switch (jobStatus) {
        case 'partial_failed':
          return context.isDark ? AppColors.accent : AppColors.warning;
        case 'failed':
          return AppColors.error;
        case 'done':
          return AppColors.success;
        default:
          return AppColors.info;
      }
    }

    if (activeJobId.isEmpty) {
      return const SizedBox.shrink();
    }

    final progress = progressValue.clamp(0.0, 1.0);
    final showIndeterminate = progressValue == 0 && isJobRunning;
    final progressText =
        showIndeterminate ? tr('common.initializing') : '${(progress * 100).round()}%';

    return AppSurface.card(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColorStrong,
      borderColor: context.appBorder,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      boxShadow: context.isDark ? const [] : AppShadows.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: isJobRunning
                    ? Icons.cloud_upload_rounded
                    : Icons.task_alt_rounded,
                size: 46,
                iconSize: 24,
                gradient: isJobRunning
                    ? AppGradients.primary
                    : AppGradients.accentGlow,
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'auth.bulk_import.status_title'.tr(),
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: AppStatusChip(
                  key: ValueKey(isJobRunning.toString() + jobStatus),
                  label: stateLabel(),
                  color: stateForeground(),
                  backgroundColor: stateBackground(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              tween: Tween(begin: 0, end: progress),
              builder: (context, animatedValue, _) {
                return LinearProgressIndicator(
                  value: showIndeterminate ? null : animatedValue,
                  minHeight: 12,
                  backgroundColor: context.isDark
                      ? context.appBorder
                      : AppColors.primarySoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.isDark ? AppColors.accent : AppColors.primary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                progressText,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.isDark ? AppColors.accent : AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              AppSurface.soft(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                color: context.appSurfaceSoft,
                borderColor: context.appBorder,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Text(
                  'Job: $_jobLabel',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppStatusChip.metric(
                icon: Icons.dataset_rounded,
                label: 'auth.bulk_import.total_records'.tr(),
                value: '$totalStudents',
                backgroundColor: context.isDark
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.primarySoft,
                color: AppColors.primary,
              ),
              AppStatusChip.metric(
                icon: Icons.layers_rounded,
                label: 'auth.bulk_import.completed_batches'.tr(),
                value: '$processedChunks / $totalChunks',
                backgroundColor: context.isDark
                    ? AppColors.warning.withValues(alpha: 0.16)
                    : AppColors.warningSoft,
                color: context.isDark ? AppColors.accent : AppColors.warning,
              ),
              AppStatusChip.metric(
                icon: Icons.check_circle_rounded,
                label: 'auth.bulk_import.added'.tr(),
                value: '$successCount',
                backgroundColor: context.isDark
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.successSoft,
                color: AppColors.success,
              ),
              AppStatusChip.metric(
                icon: Icons.cancel_rounded,
                label: 'common.failed'.tr(),
                value: '$failCount',
                backgroundColor: context.isDark
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.errorSoft,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
