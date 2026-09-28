import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/create_event_controller.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final controller = CreateEventController();
  String? initError;

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  Future<void> _handleInit() async {
    setState(() => initError = null);

    try {
      final initFuture = controller.init();
      setState(() {});
      await initFuture;
    } catch (_) {
      initError = 'events.create_init_failed';
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final current = controller.selectedDateTime;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      controller.selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    final submitFuture = controller.submit();
    setState(() {});
    final error = await submitFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      showAppSnackBar(context, error.tr(), type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      tr('events.create_success'),
      type: SnackType.success,
    );

    Navigator.pop(context, true);
  }

  String _dateLabel() {
    return DateFormat('yyyy/MM/dd - HH:mm').format(controller.selectedDateTime);
  }

  String _scopeLabel(EventScopeOption scope) {
    switch (scope) {
      case EventScopeOption.university:
        return tr('events.scope_university_2');
      case EventScopeOption.department:
        return tr('events.scope_department_2');
      case EventScopeOption.group:
        return tr('events.scope_group_2');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading || initError != null || controller.availableScopes.isEmpty) {
      return AppPageShell(
        title: tr('events.create_title'),
        body: AppStateView(
          loading: controller.isLoading,
          error: initError?.tr(),
          empty: !controller.isLoading &&
              initError == null &&
              controller.availableScopes.isEmpty,
          emptyIcon: Icons.lock_outline_rounded,
          emptyText: tr('events.create_permission_denied'),
          errorIcon: Icons.event_busy_rounded,
          onRetry: initError != null ? _handleInit : null,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return AppPageShell(
      title: tr('events.create_title'),
      body: AppScrollableBody.column(
        children: [
              AppPageHeader(
                title: tr('events.create_title'),
                subtitle: tr('events.create_subtitle'),
                icon: Icons.event_available_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('events.scope_label'),
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppFilterChips<EventScopeOption?>(
                values: controller.availableScopes.cast<EventScopeOption?>(),
                selected: controller.selectedScope,
                labelBuilder: (scope) => scope == null ? '' : _scopeLabel(scope),
                onChanged: (scope) {
                  if (scope == null) return;
                  setState(() => controller.setScope(scope));
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller.titleController,
                maxLength: CreateEventController.titleMaxLength,
                decoration: InputDecoration(
                  labelText: tr('events.title_label'),
                  hintText: tr('events.title_hint'),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller.detailsController,
                minLines: 3,
                maxLines: 5,
                maxLength: CreateEventController.detailsMaxLength,
                decoration: InputDecoration(
                  labelText: tr('events.details_label'),
                  hintText: tr('events.details_hint'),
                  prefixIcon: const Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller.locationController,
                maxLength: CreateEventController.locationMaxLength,
                decoration: InputDecoration(
                  labelText: tr('events.location_label'),
                  hintText: tr('events.location_hint'),
                  prefixIcon: const Icon(Icons.place_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller.notesController,
                minLines: 2,
                maxLines: 4,
                maxLength: CreateEventController.notesMaxLength,
                decoration: InputDecoration(
                  labelText: tr('events.notes_label'),
                  hintText: tr('events.notes_hint'),
                  prefixIcon: const Icon(Icons.sticky_note_2_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSurface.card(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: context.appCardColor,
                borderColor: context.appBorder,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: _pickDateTime,
                child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          tr('events.event_time', args: [_dateLabel()]),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded),
                    ],
                  ),
                ),
              if (controller.selectedScope == EventScopeOption.department &&
                  (controller.currentUser?.department ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppSurface.card(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: context.appCardColor,
                  borderColor: context.appBorder,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          tr(
                            'events.target_department',
                            args: [tr(AppDepartments.labelKey(controller.currentUser?.department ?? ''))],
                          ),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (controller.selectedScope == EventScopeOption.group) ...[
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<String>(
                  value: controller.selectedGroupId.isEmpty
                      ? null
                      : controller.selectedGroupId,
                  label: tr('events.target_group'),
                  icon: Icons.groups_rounded,
                  options: controller.manageableGroups
                      .map(
                        (group) => AppDropdownOption<String>(
                          value: group.groupId,
                          label: group.groupName,
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      controller.setSelectedGroup(value);
                    });
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: tr('events.create_action'),
                icon: Icons.event_available_rounded,
                loading: controller.isSubmitting,
                onPressed: controller.isSubmitting ? null : _submit,
              ),
        ],
      ),
    );
  }
}
