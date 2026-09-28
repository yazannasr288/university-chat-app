import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  /// Motion tokens are intentionally short. The UI should feel responsive,
  /// while still giving spatial changes enough time to be understood.
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 440);
  static const Duration emphasizedDuration = Duration(milliseconds: 560);

  static const Curve standard = Cubic(0.20, 0.00, 0.00, 1.00);
  static const Curve decelerate = Cubic(0.00, 0.00, 0.00, 1.00);
  static const Curve emphasized = Cubic(0.16, 1.00, 0.30, 1.00);
  static const Curve entrance = Cubic(0.12, 0.82, 0.18, 1.00);
  static const Curve exit = Cubic(0.40, 0.00, 1.00, 1.00);
  static const Curve spring = Curves.easeOutBack;

  static Duration stagger(int index, {int maxSteps = 7}) {
    final safeIndex = index.clamp(0, maxSteps).toInt();
    return Duration(milliseconds: safeIndex * 34);
  }

  static bool animationsDisabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration resolve(BuildContext context, Duration duration) {
    return animationsDisabled(context) ? Duration.zero : duration;
  }
}
