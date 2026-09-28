import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';

class AccountTypeOptionTile extends StatelessWidget {
  final String title;
  final String value;
  final bool selected;

  const AccountTypeOptionTile({
    super.key,
    required this.title,
    required this.value,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.medium),
      curve: AppMotion.standard,
      child: AppSurface.soft(
        padding: EdgeInsets.zero,
        color: selected ? context.appPrimaryGlow : context.appCardColor,
        borderColor: selected ? context.appPrimary : context.appBorder,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: RadioListTile<String>(
          value: value,
          selected: selected,
          activeColor: context.appPrimary,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}
