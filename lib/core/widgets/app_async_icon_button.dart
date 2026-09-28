import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_loader.dart';

class AppAsyncIconButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final double loaderSize;

  const AppAsyncIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.tooltip,
    this.loaderSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      icon: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.fast),
        child:
            loading
                ? AppLoader.inline(
                  key: const ValueKey<String>('loading'),
                  size: loaderSize,
                  strokeWidth: 2.2,
                )
                : Icon(icon, key: const ValueKey<String>('icon')),
      ),
    );
  }
}
