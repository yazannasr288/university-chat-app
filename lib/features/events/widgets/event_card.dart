import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_compact_button.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_info_chip.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/app_event.dart';

class EventCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool interestLoading;
  final AppEvent event;
  final bool isInterested;
  final Future<void> Function() onToggleInterest;

  const EventCard({
    super.key,
    this.onTap,
    required this.event,
    required this.isInterested,
    required this.onToggleInterest,
    required this.interestLoading,
  });

  String _scopeLabel() {
    switch (event.scopeType) {
      case 'university':
        return 'events.scope_university';
      case 'department':
        return 'events.scope_department';
      case 'group':
        return 'events.scope_group';
      default:
        return 'events.scope_event';
    }
  }

  Color _scopeColor() {
    switch (event.scopeType) {
      case 'university':
        return AppColors.primary;
      case 'department':
        return AppColors.supportEmerald;
      case 'group':
        return AppColors.supportPurple;
      default:
        return AppColors.info;
    }
  }

  String _formattedDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(event.eventAt);
    return DateFormat('yyyy/MM/dd - HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scopeColor = _scopeColor();

    return AppSurface.card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColorStrong,
      borderRadius: AppDecorations.radius(AppRadii.xl),
      boxShadow: AppShadows.card,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icons.event_note_rounded,
                size: 46,
                iconSize: 24,
                color: scopeColor,
                backgroundColor: scopeColor.withValues(alpha: 0.12),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AppStatusChip(
                      label: _scopeLabel().tr(),
                      color: scopeColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            event.details,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
              height: 1.65,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppInfoChip(
                icon: Icons.schedule_rounded,
                value: _formattedDate(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
              AppInfoChip(
                icon: Icons.place_rounded,
                value: event.location,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
              AppInfoChip(
                icon: Icons.favorite_rounded,
                value: tr(
                  'events.interested_count',
                  args: ['${event.interestedCount}'],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
            ],
          ),
          if (event.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              text: event.notes,
              icon: Icons.sticky_note_2_rounded,
              backgroundColor: context.appSurfaceSoft,
              color: context.appPrimary,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppCompactButton(
              text: isInterested
                  ? 'events.interested'.tr()
                  : 'events.mark_interested'.tr(),
              icon: isInterested
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              outlined: true,
              loading: interestLoading,
              onPressed:
                  event.isPast || interestLoading ? null : onToggleInterest,
            ),
          ),
        ],
      ),
    );
  }
}
