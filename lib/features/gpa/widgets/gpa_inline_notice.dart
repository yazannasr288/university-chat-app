import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notice.dart';

class GpaInlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const GpaInlineNotice({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      text: text,
      icon: icon,
      color: color,
      textColor: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }
}
