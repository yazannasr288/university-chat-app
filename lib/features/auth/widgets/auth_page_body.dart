import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold_background.dart';
import '../../../core/widgets/app_scrollable_body.dart';
import '../../../core/widgets/app_surface.dart';

class AuthPageBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AuthPageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffoldBackground(
      child: AppScrollableBody(
        padding: padding.add(
          const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xl,
          ),
        ),
        maxWidth: 560,
        child: TweenAnimationBuilder<double>(
          duration: AppMotion.emphasizedDuration,
          curve: AppMotion.emphasized,
          tween: Tween(begin: 0.985, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: value,
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 22),
                  child: child,
                ),
              ),
            );
          },
          child: AppSurface.card(
            padding: EdgeInsets.zero,
            color: context.appCardColorStrong,
            borderColor: context.appBorder,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: context.isDark ? const [] : AppShadows.card,
            child: Stack(
              children: [
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: Container(
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.brand,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 30,
                  child: Container(
                    width: 72,
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.gold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
