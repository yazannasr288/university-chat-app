import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_text_field.dart';

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final TextEditingController passwordController =
  TextEditingController();

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('dashboard.reset_password')),
      content: AppTextField(
        controller: passwordController,
        label: tr('dashboard.temp_password'),
        hint: tr('dashboard.temp_password_hint'),
        icon: Icons.lock_reset_rounded,
        obscureText: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('common.cancel')),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              passwordController.text.trim(),
            );
          },
          child: Text(tr('dashboard.confirm_reset')),
        ),
      ],
    );
  }
}
