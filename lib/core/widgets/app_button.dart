import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_loader.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;
  final LinearGradient? gradient;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
    this.gradient,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadii.pill);
    final buttonGradient =
        widget.backgroundColor == null
            ? (widget.gradient ?? AppGradients.primary)
            : null;
    final enabled = !widget.loading && widget.onPressed != null;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled && !_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel:
            enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed && !AppMotion.animationsDisabled(context)
              ? 0.982
              : _hovered && !AppMotion.animationsDisabled(context)
                  ? 1.006
                  : 1,
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.standard,
          child: AnimatedOpacity(
            opacity: enabled || widget.loading ? 1 : 0.58,
            duration: AppMotion.resolve(context, AppMotion.fast),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.fast),
                curve: AppMotion.standard,
                decoration: AppDecorations.surface(
                  color: widget.backgroundColor ?? Colors.transparent,
                  gradient: buttonGradient,
                  borderRadius: borderRadius,
                  boxShadow: enabled
                      ? (_hovered
                          ? AppShadows.brandGlow
                          : AppShadows.subtle)
                      : const [],
                ),
                child: ElevatedButton.icon(
                  onPressed: widget.loading ? null : widget.onPressed,
                  icon: AnimatedSwitcher(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    switchInCurve: AppMotion.entrance,
                    switchOutCurve: AppMotion.exit,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: widget.loading
                        ? const AppLoader.inline(
                            key: ValueKey<String>('loading'),
                            size: 18,
                            strokeWidth: 2.2,
                            color: Colors.white,
                          )
                        : Icon(
                            widget.icon ?? Icons.check_rounded,
                            key: const ValueKey<String>('icon'),
                            color: Colors.white,
                          ),
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: borderRadius),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
