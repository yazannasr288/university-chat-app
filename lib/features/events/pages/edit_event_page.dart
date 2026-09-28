import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/app_event.dart';
import '../controllers/edit_event_controller.dart';

class EditEventPage extends StatefulWidget {
  final AppEvent event;

  const EditEventPage({
    super.key,
    required this.event,
  });

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final controller = EditEventController();

  @override
  void initState() {
    super.initState();
    controller.fillFromEvent(widget.event);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final current = controller.selectedDateTime;
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate = current.isBefore(firstDate) ? firstDate : current;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
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
    final submitFuture = controller.submit(widget.event.id);
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
      tr('events.edit_success'),
      type: SnackType.success,
    );

    Navigator.pop(context, true);
  }

  String _dateLabel() {
    return DateFormat('yyyy/MM/dd - HH:mm').format(controller.selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: tr('events.edit_title'),
      body: AppScrollableBody.column(
        children: [
              TextField(
                controller: controller.titleController,
                maxLength: EditEventController.titleMaxLength,
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
                maxLength: EditEventController.detailsMaxLength,
                decoration: InputDecoration(
                  labelText: tr('events.details_label'),
                  hintText: tr('events.details_hint'),
                  prefixIcon: const Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller.locationController,
                maxLength: EditEventController.locationMaxLength,
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
                maxLength: EditEventController.notesMaxLength,
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
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: controller.isSubmitting
                    ? tr('events.saving')
                    : tr('events.save_changes'),
                icon: Icons.save_rounded,
                loading: controller.isSubmitting,
                onPressed: controller.isSubmitting ? null : _submit,
              ),
        ],
      ),
    );
  }
}
