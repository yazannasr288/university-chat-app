import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelText,
  required String confirmText,
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: TextStyle(color: confirmColor ?? AppColors.error),
          ),
        ),
      ],
    ),
  );

  return result == true;
}
