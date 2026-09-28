import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Widget? child;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
    this.child,
  });

  const AppIconBadge.circle({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.boxShadow,
    this.child,
  }) : borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill));

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient;
    final effectiveBackgroundColor = effectiveGradient == null
        ? backgroundColor ?? context.appPrimary.withValues(alpha: 0.10)
        : null;
    final effectiveColor = color ?? context.appPrimary;

    return Container(
      width: size,
      alignment: Alignment.center,
      height: size,
      decoration: AppDecorations.surface(
        color: effectiveBackgroundColor ?? Colors.transparent,
        gradient: effectiveGradient,
        borderRadius: borderRadius ?? AppDecorations.radius(AppRadii.md),
        borderColor: borderColor,
        boxShadow: boxShadow,
      ),
      child: child ?? Icon(icon, size: iconSize, color: effectiveColor),
    );
  }
}
