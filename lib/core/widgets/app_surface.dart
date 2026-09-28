import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSurface extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
  });

  factory AppSurface.card({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    Color? color,
    Gradient? gradient,
    Color? borderColor,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    VoidCallback? onTap,
  }) {
    return AppSurface(
      key: key,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      onTap: onTap,
      child: child,
    );
  }

  factory AppSurface.soft({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md),
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    Color? color,
    Gradient? gradient,
    Color? borderColor,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    VoidCallback? onTap,
  }) {
    return AppSurface(
      key: key,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      onTap: onTap,
      child: child,
    );
  }

  @override
  State<AppSurface> createState() => _AppSurfaceState();
}

class _AppSurfaceState extends State<AppSurface> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        widget.borderRadius ?? AppDecorations.radius(AppRadii.xl);
    final effectiveColor = widget.color ?? context.appCardColor;
    final effectiveBorderColor = widget.borderColor ?? context.appBorder;
    final interactive = widget.onTap != null;
    final displayedBorderColor = interactive && _hovered
        ? Color.lerp(effectiveBorderColor, context.appPrimary, 0.24)!
        : effectiveBorderColor;
    final displayedShadow = widget.boxShadow ??
        (interactive && _hovered && !context.isDark
            ? AppShadows.card
            : null);

    Widget content = widget.child;
    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              effectiveBorderRadius is BorderRadius
                  ? effectiveBorderRadius
                  : AppDecorations.radius(AppRadii.xl),
          onTap: widget.onTap,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return context.appPrimary.withValues(alpha: 0.075);
            }
            if (states.contains(WidgetState.hovered)) {
              return context.appPrimary.withValues(alpha: 0.035);
            }
            return null;
          }),
          onHighlightChanged: (highlighted) {
            if (_pressed == highlighted || !mounted) return;
            setState(() => _pressed = highlighted);
          },
          child: content,
        ),
      );
    } else {
      content = Material(color: Colors.transparent, child: content);
    }

    content = AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.standard,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      clipBehavior: widget.clipBehavior,
      decoration: AppDecorations.surface(
        color: effectiveColor,
        gradient: widget.gradient,
        borderRadius: effectiveBorderRadius,
        borderColor: displayedBorderColor,
        borderWidth: widget.borderWidth,
        boxShadow: displayedShadow,
      ),
      child: content,
    );

    if (interactive) {
      content = AnimatedScale(
        scale: _pressed && !AppMotion.animationsDisabled(context)
            ? 0.978
            : _hovered && !AppMotion.animationsDisabled(context)
                ? 1.004
                : 1,
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.standard,
        child: content,
      );

      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!_hovered && mounted) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered && mounted) setState(() => _hovered = false);
        },
        child: content,
      );
    }

    return content;
  }
}
