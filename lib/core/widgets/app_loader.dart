import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface.dart';

class AppLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final bool boxed;
  final Color? color;

  const AppLoader({
    super.key,
    this.size = 34,
    this.strokeWidth = 3,
    this.boxed = true,
    this.color,
  });

  const AppLoader.inline({
    super.key,
    this.size = 20,
    this.strokeWidth = 2.2,
    this.color,
  }) : boxed = false;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? context.appPrimary,
      ),
    );

    if (!boxed) return indicator;

    return Center(
      child: AppSurface.card(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: context.appCardColorStrong,
        borderColor: context.appBorder,
        borderRadius: AppDecorations.radius(AppRadii.lg),
        boxShadow: context.isDark ? const [] : AppShadows.card,
        child: indicator,
      ),
    );
  }
}
