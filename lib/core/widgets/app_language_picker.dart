import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface.dart';

Future<void> showAppLanguagePicker(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return SafeArea(
        child: AppSurface.card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: context.appCardColorStrong,
          borderColor: context.appBorder,
          borderRadius: AppDecorations.radius(AppRadii.xl),
          boxShadow: context.isDark ? const [] : AppShadows.floating,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: AppDecorations.pill(
                  color: context.appBorderStrong,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'common.language.choose_language'.tr(),
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _LangTile(
                title: 'common.language.arabic'.tr(),
                selected: context.locale.languageCode == 'ar',
                onTap: () async {
                  await context.setLocale(const Locale('ar'));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _LangTile(
                title: 'common.language.english'.tr(),
                selected: context.locale.languageCode == 'en',
                onTap: () async {
                  await context.setLocale(const Locale('en'));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LangTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.soft(
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.zero,
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : context.appSurfaceSoft,
      borderColor: selected ? AppColors.primary : context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      onTap: onTap,
      child: ListTile(
        leading: Icon(
          selected ? Icons.check_circle_rounded : Icons.language_rounded,
          color: selected
              ? AppColors.primary
              : context.appPrimary,
        ),
        title: Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
