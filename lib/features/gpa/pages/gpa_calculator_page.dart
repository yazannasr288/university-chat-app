import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../controllers/gpa_calculator_controller.dart';
import '../widgets/gpa_badge.dart';
import '../widgets/gpa_courses_section.dart';
import '../widgets/gpa_previous_section.dart';
import '../widgets/gpa_summary_section.dart';

class GpaCalculatorPage extends StatefulWidget {
  const GpaCalculatorPage({super.key});

  @override
  State<GpaCalculatorPage> createState() => _GpaCalculatorPageState();
}

class _GpaCalculatorPageState extends State<GpaCalculatorPage> {
  final controller = GpaCalculatorController();

  @override
  void initState() {
    super.initState();
    controller.init(_refresh);
  }

  @override
  void dispose() {
    controller.dispose(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  Color _gpaColor(BuildContext context, double? gpa) {
    if (gpa == null) return context.appTextMuted;
    if (gpa >= 3.0) return AppColors.success;
    if (gpa >= 2.0) return AppColors.info;
    if (gpa >= 1.0) return AppColors.supportCoral;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;

    return AppPageShell(
      title: 'gpa.title'.tr(),
      actions: [
        IconButton(
          tooltip: 'gpa.reset'.tr(),
          onPressed: () => controller.reset(_refresh),
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
      safeArea: true,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppPageHeader(
                icon: Icons.calculate_rounded,
                title: 'gpa.header_title'.tr(),
                subtitle: 'gpa.header_subtitle'.tr(),
                trailing: GpaCircularBadge(
                  label: 'gpa.cumulative_short'.tr(),
                  value: controller.formatNumber(summary.cumulativeGpa),
                  color: _gpaColor(context, summary.cumulativeGpa),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GpaSummarySection(
                summary: summary,
                formatNumber: controller.formatNumber,
                standingKey: controller.standingKey,
                gpaColor: _gpaColor,
              ),
              const SizedBox(height: AppSpacing.lg),
              GpaPreviousSection(
                summary: summary,
                previousGpaController: controller.previousGpaController,
                previousCreditsController: controller.previousCreditsController,
                numberInputFormatters:
                    GpaCalculatorController.numberInputFormatters,
              ),
              const SizedBox(height: AppSpacing.lg),
              GpaCoursesSection(
                courses: controller.courses,
                gradeOptions: GpaCalculatorController.gradeOptions,
                defaultGrade: GpaCalculatorController.defaultGrade,
                numberInputFormatters:
                    GpaCalculatorController.numberInputFormatters,
                formatNumber: controller.formatNumber,
                coursePointsOf: controller.courseWeightedPoints,
                onAddCourse: () {
                  final added = controller.addCourse(_refresh);

                  if (!added) {
                    showAppSnackBar(
                      context,
                      'gpa.max_courses_reached'.tr(
                        namedArgs: {
                          'count': GpaCalculatorController.maxCourses.toString(),
                        },
                      ),
                      type: SnackType.error,
                    );
                  }
                },
                onRemoveCourse: (course) => controller.removeCourse(
                  course,
                  _refresh,
                ),
                onGradeChanged: (course, grade) => controller.updateCourseGrade(
                  course: course,
                  grade: grade,
                  listener: _refresh,
                ),
                onRepeatedFailedChanged: (course, value) =>
                    controller.updateCourseRepeatedFailedStatus(
                  course: course,
                  value: value,
                  listener: _refresh,
                ),
              ),
            ],
      ),
    );
  }
}
