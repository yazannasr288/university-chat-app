import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_audit_filters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';

class DashboardAuditFilterBar extends StatelessWidget {
  final String selectedCategory;
  final String selectedLevel;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final Future<void> Function() onApply;
  final bool loading;

  const DashboardAuditFilterBar({
    super.key,
    required this.selectedCategory,
    required this.selectedLevel,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.onCategoryChanged,
    required this.onLevelChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onApply,
    this.loading = false,
  });

  static const List<String> categoryValues = AppAuditCategories.filterValues;

  static const List<String> levelValues = AppAuditLevels.filterValues;

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? initialDate,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) onChanged(picked);
  }

  String _dateLabel(DateTime? value, String fallback) {
    if (value == null) return fallback;
    return DateFormat('yyyy/MM/dd').format(value);
  }

  String _categoryLabel(String value) => AppAuditCategories.labelKey(value).tr();

  String _levelKey(String value) => AppAuditLevels.labelKey(value);

  @override
  Widget build(BuildContext context) {
    final categoryOptions = categoryValues
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: _categoryLabel(value),
          ),
        )
        .toList();

    final levelOptions = levelValues
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: tr(_levelKey(value)),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: AppDropdownField<String>(
                value: selectedCategory.isEmpty ? null : selectedCategory,
                label: 'dashboard.log_type'.tr(),
                options: categoryOptions,
                onChanged: (v) => onCategoryChanged(v ?? ''),
              ),
            ),
            SizedBox(
              width: 180,
              child: AppDropdownField<String>(
                value: selectedLevel,
                fallbackValue: AppAuditLevels.all,
                label: tr('dashboard.audit_level'),
                options: levelOptions,
                onChanged: (v) => onLevelChanged(v ?? AppAuditLevels.all),
              ),
            ),
            SizedBox(
              width: 170,
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(
                  context: context,
                  initialDate: selectedStartDate,
                  onChanged: onStartDateChanged,
                ),
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  _dateLabel(selectedStartDate, 'dashboard.date_2'.tr()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(
                  context: context,
                  initialDate: selectedEndDate,
                  onChanged: onEndDateChanged,
                ),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(
                  _dateLabel(selectedEndDate, 'dashboard.date'.tr()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppButton(
          text: tr('dashboard.apply_filters'),
          icon: Icons.filter_alt_rounded,
          backgroundColor: context.isDark ? AppColors.accent : AppColors.primary,
          loading: loading,
          onPressed: loading ? null : onApply,
        ),
      ],
    );
  }
}
