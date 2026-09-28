import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ChatScrollDateBadge extends StatelessWidget {
  final String label;
  final bool visible;

  const ChatScrollDateBadge({
    super.key,
    required this.label,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = context.isDark
        ? LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF0A3F72).withValues(alpha: 0.97),
              const Color(0xFF096DAE).withValues(alpha: 0.96),
            ],
          )
        : LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withValues(alpha: 0.96),
              AppColors.primarySoft.withValues(alpha: 0.96),
            ],
          );

    final borderColor = context.isDark
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.primary.withValues(alpha: 0.12);

    final textColor = context.isDark ? Colors.white : AppColors.primaryDark;

    return IgnorePointer(
      child: AnimatedSlide(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.standard,
        offset: visible ? Offset.zero : const Offset(0, -0.28),
        child: AnimatedOpacity(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.standard,
          opacity: visible && label.trim().isNotEmpty ? 1 : 0,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: backgroundGradient,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(
                      alpha: context.isDark ? 0.18 : 0.08,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: textColor.withValues(alpha: 0.86),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      textDirection: Directionality.of(context),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
