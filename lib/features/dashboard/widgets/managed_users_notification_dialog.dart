import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class ManagedUsersNotificationDialog extends StatefulWidget {
  final int selectedCount;
  final Future<String?> Function(String title, String body) onSend;

  const ManagedUsersNotificationDialog({
    super.key,
    required this.selectedCount,
    required this.onSend,
  });

  @override
  State<ManagedUsersNotificationDialog> createState() =>
      _ManagedUsersNotificationDialogState();
}

class _ManagedUsersNotificationDialogState
    extends State<ManagedUsersNotificationDialog> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      showAppSnackBar(
        context,
        tr('dashboard.notification_required_fields'),
        type: SnackType.error,
      );
      return;
    }

    setState(() => isLoading = true);

    final error = await widget.onSend(title, body);

    if (!mounted) return;

    setState(() => isLoading = false);

    Navigator.pop(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardColorStrong,
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('dashboard.send_notification'),
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr(
                    'dashboard.notification_selected_count',
                    args: ['${widget.selectedCount}'],
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: titleController,
                  label: tr('dashboard.notification_title'),
                  hint: tr('dashboard.notification_title_hint'),
                  icon: Icons.notifications_active_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: bodyController,
                  minLines: 5,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: tr('dashboard.notification_body'),
                    hintText: tr('dashboard.notification_body_hint'),
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: tr('common.cancel'),
                        icon: Icons.close_rounded,
                        backgroundColor: AppColors.supportNavy,
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        text: tr('dashboard.send_notification'),
                        icon: Icons.send_rounded,
                        loading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
