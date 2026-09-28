import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_card.dart';

class DashboardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      color: context.appCardColorStrong,
      headerSpacing: 14,
      child: child,
    );
  }
}
