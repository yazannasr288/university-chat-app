import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_loader.dart';

class AppCompactButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final bool outlined;

  const AppCompactButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final effectiveIcon = AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.fast),
      child:
          loading
              ? AppLoader.inline(
                key: const ValueKey<String>('loading'),
                size: 18,
                strokeWidth: 2,
                color: outlined ? null : Colors.white,
              )
              : Icon(icon, key: const ValueKey<String>('icon')),
    );
    final effectiveLabel = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: effectiveOnPressed,
        icon: effectiveIcon,
        label: effectiveLabel,
      );
    }

    return ElevatedButton.icon(
      style:
          backgroundColor == null
              ? null
              : ElevatedButton.styleFrom(backgroundColor: backgroundColor),
      onPressed: effectiveOnPressed,
      icon: effectiveIcon,
      label: effectiveLabel,
    );
  }
}
