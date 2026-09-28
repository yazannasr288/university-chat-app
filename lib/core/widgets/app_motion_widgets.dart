import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A lightweight, one-time entrance used by page bodies.
///
/// It keeps the page background static, avoids rebuilding [child] for every
/// animation tick, and follows the operating system's reduced-motion setting.
class AppPageEntrance extends StatelessWidget {
  final Widget child;
  final double offsetY;
  final Duration duration;
  final double scaleBegin;

  const AppPageEntrance({
    super.key,
    required this.child,
    this.offsetY = 12,
    this.duration = AppMotion.medium,
    this.scaleBegin = 0.992,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.animationsDisabled(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: AppMotion.entrance,
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: scaleBegin + ((1 - scaleBegin) * value),
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * offsetY),
              child: animatedChild,
            ),
          ),
        );
      },
    );
  }
}

/// A restrained, one-time reveal for list items and layered page sections.
///
/// [index] adds a capped delay so long lists never feel slow. The delay is
/// encoded in the animation curve, which avoids timers and keeps disposal safe.
class AppStaggeredEntrance extends StatelessWidget {
  final Widget child;
  final int index;
  final int maxDelaySteps;
  final Duration duration;
  final double offsetY;
  final double offsetX;
  final double scaleBegin;

  const AppStaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxDelaySteps = 7,
    this.duration = AppMotion.medium,
    this.offsetY = 10,
    this.offsetX = 0,
    this.scaleBegin = 0.994,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.animationsDisabled(context)) return child;

    final delay = AppMotion.stagger(index, maxSteps: maxDelaySteps);
    final totalDuration = duration + delay;
    final delayFraction = totalDuration.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / totalDuration.inMicroseconds;
    final curve = Interval(
      delayFraction.clamp(0.0, 0.82).toDouble(),
      1,
      curve: AppMotion.entrance,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: totalDuration,
      curve: curve,
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: scaleBegin + ((1 - scaleBegin) * value),
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(
                (1 - value) * offsetX,
                (1 - value) * offsetY,
              ),
              child: animatedChild,
            ),
          ),
        );
      },
    );
  }
}

/// Shared fade-through transition for state changes that occupy the same area.
class AppFadeThroughSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  const AppFadeThroughSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, duration),
      reverseDuration: AppMotion.resolve(context, AppMotion.fast),
      switchInCurve: AppMotion.entrance,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: alignment,
          children: [...previousChildren, if (currentChild != null) currentChild],
        );
      },
      transitionBuilder: (transitionChild, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.16, 1, curve: AppMotion.standard),
          reverseCurve: AppMotion.exit,
        );
        final scale = Tween<double>(begin: 0.97, end: 1).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: transitionChild),
        );
      },
      child: child,
    );
  }
}
