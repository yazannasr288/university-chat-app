import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SnackType { success, error, info }

void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackType type = SnackType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

  Color backgroundColor;
  IconData icon;

  switch (type) {
    case SnackType.success:
      backgroundColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      break;
    case SnackType.error:
      backgroundColor = AppColors.error;
      icon = Icons.error_rounded;
      break;
    case SnackType.info:
      backgroundColor = context.appPrimary;
      icon = Icons.info_rounded;
      break;
  }

  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        keyboardHeight > 0 ? keyboardHeight + 12 : 18,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
