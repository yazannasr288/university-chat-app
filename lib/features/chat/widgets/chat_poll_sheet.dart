import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';

class PollDraft {
  final String question;
  final List<String> options;
  final int expiresAt;

  const PollDraft({
    required this.question,
    required this.options,
    required this.expiresAt,
  });
}

class ChatPollSheet extends StatefulWidget {
  const ChatPollSheet({super.key});

  @override
  State<ChatPollSheet> createState() => _ChatPollSheetState();
}

class _ChatPollSheetState extends State<ChatPollSheet> {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  DateTime _expiresAt = DateTime.now().add(const Duration(hours: 24));

  @override
  void dispose() {
    questionController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiresAt.isBefore(now) ? now : _expiresAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _expiresAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addOption() {
    if (optionControllers.length >= 6) return;
    setState(() {
      optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (optionControllers.length <= 2) return;
    setState(() {
      optionControllers[index].dispose();
      optionControllers.removeAt(index);
    });
  }

  void _submit() {
    final question = questionController.text.trim();
    final options = optionControllers
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      _showError('chat.enter_poll_question'.tr());
      return;
    }

    if (question.length > 120) {
      _showError('chat.poll_question_must_not_exceed_120_characters'.tr());
      return;
    }

    if (options.length < 2) {
      _showError('chat.least_two_options_required'.tr());
      return;
    }

    if (options.length > 6) {
      _showError('chat.poll_options_must_between_2_6'.tr());
      return;
    }

    if (options.any((option) => option.length > 80)) {
      _showError('chat.poll_option_too_long'.tr());
      return;
    }

    if (_expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      _showError('chat.choose_valid_expiry_time'.tr());
      return;
    }

    Navigator.pop(
      context,
      PollDraft(
        question: question,
        options: options,
        expiresAt: _expiresAt.millisecondsSinceEpoch,
      ),
    );
  }

  void _showError(String text) {
    showAppSnackBar(context, text, type: SnackType.error);
  }

  String _expiryLabel() {
    final date = _expiresAt;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/${date.month}/${date.day} - $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final scheme = context.scheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.appCardColorStrong,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: context.appBorder),
            boxShadow: context.isDark ? const [] : AppShadows.floating,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorderStrong,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'chat.create_poll'.tr(),
                    style: context.textTheme.titleLarge?.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: questionController,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: 'chat.poll_question'.tr(),
                    hintText: 'chat.type_question_here'.tr(),
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < optionControllers.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: optionControllers[i],
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: tr('chat.option_value', args: ['${i + 1}']),
                            hintText: 'chat.enter_option_text'.tr(),
                          ),
                        ),
                      ),
                      if (optionControllers.length > 2) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeOption(i),
                          icon: Icon(
                            Icons.remove_circle_rounded,
                            color: scheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: optionControllers.length < 6 ? _addOption : null,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          optionControllers.length < 6
                              ? 'chat.add_option'.tr()
                              : 'chat.maximum_reached'.tr(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: _pickExpiry,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.accent.withValues(alpha: 0.10)
                          : AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: context.isDark ? 0.55 : 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: scheme.secondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('chat.ends_value', args: [_expiryLabel()]),
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_rounded,
                          color: context.appTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('common.cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: Text('chat.send_poll'.tr()),
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
