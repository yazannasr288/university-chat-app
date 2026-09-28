import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';

class SearchInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SearchInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: AppSurface.card(
        padding: EdgeInsets.zero,
        color: context.appCardColorStrong,
        borderColor: context.appBorder,
        borderRadius: AppDecorations.radius(AppRadii.xl),
        boxShadow: context.isDark ? const [] : AppShadows.subtle,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.appTextPrimary,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'search.search_groups_hint'.tr(),
            hintStyle: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextMuted,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.isDark ? AppColors.accent : AppColors.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
