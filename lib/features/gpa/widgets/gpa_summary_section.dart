import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/gpa_models.dart';
import 'gpa_summary_card.dart';

typedef GpaColorResolver = Color Function(BuildContext context, double? gpa);

class GpaSummarySection extends StatelessWidget {
  final GpaSummary summary;
  final String Function(double? value) formatNumber;
  final String Function(double? gpa) standingKey;
  final GpaColorResolver gpaColor;

  const GpaSummarySection({
    super.key,
    required this.summary,
    required this.formatNumber,
    required this.standingKey,
    required this.gpaColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = [
          GpaSummaryCard(
            icon: Icons.school_rounded,
            label: 'gpa.semester_gpa'.tr(),
            value: formatNumber(summary.semesterGpa),
            subtitle: 'gpa.valid_courses'.tr(
              args: [summary.validCourses.toString()],
            ),
            color: gpaColor(context, summary.semesterGpa),
          ),
          GpaSummaryCard(
            icon: Icons.workspace_premium_rounded,
            label: 'gpa.cumulative_gpa'.tr(),
            value: formatNumber(summary.cumulativeGpa),
            subtitle: standingKey(summary.cumulativeGpa).tr(),
            color: gpaColor(context, summary.cumulativeGpa),
          ),
          GpaSummaryCard(
            icon: Icons.timeline_rounded,
            label: 'gpa.total_credits'.tr(),
            value: formatNumber(summary.totalCredits),
            subtitle: 'gpa.current_credits'.tr(
              args: [formatNumber(summary.currentCredits)],
            ),
            color: context.appPrimary,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                cards[i],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}
