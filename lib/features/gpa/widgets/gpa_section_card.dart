import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_card.dart';

class GpaSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const GpaSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      color: context.appCardColor,
      boxShadow: context.isDark ? const [] : AppShadows.card,
      child: child,
    );
  }
}
