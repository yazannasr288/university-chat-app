import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/gpa_models.dart';
import 'gpa_inline_notice.dart';
import 'gpa_section_card.dart';

class GpaPreviousSection extends StatelessWidget {
  final GpaSummary summary;
  final TextEditingController previousGpaController;
  final TextEditingController previousCreditsController;
  final List<TextInputFormatter> numberInputFormatters;

  const GpaPreviousSection({
    super.key,
    required this.summary,
    required this.previousGpaController,
    required this.previousCreditsController,
    required this.numberInputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return GpaSectionCard(
      title: 'gpa.previous_section_title'.tr(),
      subtitle: 'gpa.previous_section_subtitle'.tr(),
      icon: Icons.history_edu_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;
              final previousGpaField = AppTextField(
                controller: previousGpaController,
                label: 'gpa.previous_gpa'.tr(),
                hint: '3.25',
                icon: Icons.grade_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numberInputFormatters,
                maxLength: 4,
                textInputAction: TextInputAction.next,
              );
              final previousCreditsField = AppTextField(
                controller: previousCreditsController,
                label: 'gpa.previous_credits'.tr(),
                hint: '60',
                icon: Icons.hourglass_bottom_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numberInputFormatters,
                maxLength: 6,
                textInputAction: TextInputAction.done,
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: previousGpaField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: previousCreditsField),
                  ],
                );
              }

              return Column(
                children: [
                  previousGpaField,
                  const SizedBox(height: AppSpacing.md),
                  previousCreditsField,
                ],
              );
            },
          ),
          if (summary.hasInvalidPreviousGpa) ...[
            const SizedBox(height: AppSpacing.sm),
            GpaInlineNotice(
              icon: Icons.error_outline_rounded,
              text: 'gpa.invalid_previous_gpa'.tr(),
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }
}
