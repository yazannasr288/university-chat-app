import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/gpa_course_entry.dart';
import '../../../data/models/gpa_models.dart';
import 'gpa_mini_result_pill.dart';

class GpaCourseCard extends StatelessWidget {
  final GpaCourseEntry course;
  final int index;
  final double? coursePoints;
  final List<GpaGradeOption> gradeOptions;
  final GpaGradeOption defaultGrade;
  final List<TextInputFormatter> numberInputFormatters;
  final String Function(double? value) formatNumber;
  final VoidCallback onRemove;
  final ValueChanged<GpaGradeOption> onGradeChanged;
  final ValueChanged<bool> onRepeatedFailedChanged;

  const GpaCourseCard({
    super.key,
    required this.course,
    required this.index,
    required this.coursePoints,
    required this.gradeOptions,
    required this.defaultGrade,
    required this.numberInputFormatters,
    required this.formatNumber,
    required this.onRemove,
    required this.onGradeChanged,
    required this.onRepeatedFailedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.soft(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: context.appSurfaceSoft,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: Column(
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icons.numbers_rounded,
                size: 38,
                color: context.appPrimary,
                backgroundColor: context.appPrimary.withValues(alpha: 0.12),
                child: Text(
                  '${index + 1}',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.appPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  course.nameController.text.trim().isEmpty
                      ? 'gpa.course_number'.tr(args: ['${index + 1}'])
                      : course.nameController.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GpaMiniResultPill(
                value: formatNumber(coursePoints),
                label: 'gpa.points_short'.tr(),
              ),
              IconButton(
                tooltip: 'gpa.remove_course'.tr(),
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final courseNameField = AppTextField(
                controller: course.nameController,
                label: 'gpa.course_name'.tr(),
                hint: 'gpa.course_name_hint'.tr(),
                icon: Icons.edit_note_rounded,
                textInputAction: TextInputAction.next,
              );
              final creditsField = AppTextField(
                controller: course.creditsController,
                label: 'gpa.credits'.tr(),
                hint: '3',
                icon: Icons.access_time_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numberInputFormatters,
                maxLength: 4,
                textInputAction: TextInputAction.next,
              );
              final gradeField = AppDropdownField<GpaGradeOption>(
                value: course.grade,
                fallbackValue: defaultGrade,
                label: 'gpa.grade'.tr(),
                icon: Icons.auto_graph_rounded,
                options: gradeOptions
                    .map(
                      (grade) => AppDropdownOption(
                        value: grade,
                        label: '${grade.label}  •  ${formatNumber(grade.points)}',
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  onGradeChanged(value);
                },
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: courseNameField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 3, child: creditsField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 4, child: gradeField),
                  ],
                );
              }

              return Column(
                children: [
                  courseNameField,
                  const SizedBox(height: AppSpacing.md),
                  creditsField,
                  const SizedBox(height: AppSpacing.md),
                  gradeField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            value: course.isRepeatedFailedCourse,
            onChanged: (value) => onRepeatedFailedChanged(value ?? false),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _repeatedFailedTitle(context),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              _repeatedFailedSubtitle(context),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _repeatedFailedTitle(BuildContext context) {
    return context.locale.languageCode == 'ar'
        ? 'مادة معادة / راسبة سابقًا'
        : 'Repeated previously failed course';
  }

  String _repeatedFailedSubtitle(BuildContext context) {
    return context.locale.languageCode == 'ar'
        ? 'فعّل هذا الخيار إذا كانت هذه المادة تعوض مادة راسبة سابقة'
        : 'Enable this if the course replaces a previously failed course';
  }
}
