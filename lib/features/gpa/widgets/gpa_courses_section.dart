import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/gpa_course_entry.dart';
import '../../../data/models/gpa_models.dart';
import 'gpa_course_card.dart';
import 'gpa_section_card.dart';

class GpaCoursesSection extends StatelessWidget {
  final List<GpaCourseEntry> courses;
  final List<GpaGradeOption> gradeOptions;
  final GpaGradeOption defaultGrade;
  final List<TextInputFormatter> numberInputFormatters;
  final String Function(double? value) formatNumber;
  final double? Function(GpaCourseEntry course) coursePointsOf;
  final VoidCallback onAddCourse;
  final void Function(GpaCourseEntry course) onRemoveCourse;
  final void Function(GpaCourseEntry course, GpaGradeOption grade) onGradeChanged;
  final void Function(GpaCourseEntry course, bool value)
      onRepeatedFailedChanged;

  const GpaCoursesSection({
    super.key,
    required this.courses,
    required this.gradeOptions,
    required this.defaultGrade,
    required this.numberInputFormatters,
    required this.formatNumber,
    required this.coursePointsOf,
    required this.onAddCourse,
    required this.onRemoveCourse,
    required this.onGradeChanged,
    required this.onRepeatedFailedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GpaSectionCard(
      title: 'gpa.courses_section_title'.tr(),
      subtitle: 'gpa.courses_section_subtitle'.tr(),
      icon: Icons.menu_book_rounded,
      trailing: FilledButton.icon(
        onPressed: onAddCourse,
        icon: const Icon(Icons.add_rounded),
        label: Text('gpa.add_course'.tr()),
      ),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            GpaCourseCard(
              course: courses[i],
              index: i,
              coursePoints: coursePointsOf(courses[i]),
              gradeOptions: gradeOptions,
              defaultGrade: defaultGrade,
              numberInputFormatters: numberInputFormatters,
              formatNumber: formatNumber,
              onRemove: () => onRemoveCourse(courses[i]),
              onGradeChanged: (grade) => onGradeChanged(courses[i], grade),
              onRepeatedFailedChanged: (value) => onRepeatedFailedChanged(
                courses[i],
                value,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
