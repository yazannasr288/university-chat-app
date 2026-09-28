import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScaffoldBackground extends StatelessWidget {
  final Widget child;
  final bool animate;

  const AppScaffoldBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: context.appScaffoldGradient),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AmbientPatternPainter(
                dotColor: context.appPrimary.withValues(
                  alpha: context.isDark ? 0.055 : 0.038,
                ),
                lineColor: AppColors.accent.withValues(
                  alpha: context.isDark ? 0.042 : 0.055,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -60,
          child: _GlowOrb(size: 240, color: context.appAccentGlow),
        ),
        Positioned(
          top: -90,
          left: -90,
          child: _GlowOrb(size: 280, color: context.appPrimaryGlow),
        ),
        Positioned(
          bottom: -110,
          left: -40,
          child: _GlowOrb(size: 220, color: context.appSecondaryGlow),
        ),
        Positioned(
          bottom: 34,
          right: -92,
          child: Transform.rotate(
            angle: -0.18,
            child: Container(
              width: 250,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(52),
                gradient: context.appAccentGradient,
                border: Border.all(
                  color: AppColors.accent.withValues(
                    alpha: context.isDark ? 0.045 : 0.075,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );

    if (!animate || AppMotion.animationsDisabled(context)) {
      return background;
    }

    return TweenAnimationBuilder<double>(
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      tween: Tween(begin: 0.985, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: background,
    );
  }
}

class _AmbientPatternPainter extends CustomPainter {
  final Color dotColor;
  final Color lineColor;

  const _AmbientPatternPainter({
    required this.dotColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = dotColor;
    const gap = 42.0;

    for (double y = 22; y < size.height; y += gap) {
      final row = (y / gap).round();
      final shift = row.isEven ? 0.0 : gap / 2;
      for (double x = 18 + shift; x < size.width; x += gap) {
        final radius = ((x + y) ~/ gap).isEven ? 1.15 : 0.75;
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final firstPath = Path()
      ..moveTo(size.width * 0.66, -18)
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.16,
        size.width + 24,
        size.height * 0.38,
      );
    final secondPath = Path()
      ..moveTo(-30, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.66,
        size.width * 0.42,
        size.height + 24,
      );
    canvas
      ..drawPath(firstPath, linePaint)
      ..drawPath(secondPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AmbientPatternPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor || oldDelegate.lineColor != lineColor;
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.18), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
