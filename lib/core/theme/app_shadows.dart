import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  static final List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.075),
      blurRadius: 30,
      offset: const Offset(0, 14),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.035),
      blurRadius: 8,
      offset: const Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static final List<BoxShadow> subtle = [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.055),
      blurRadius: 18,
      offset: const Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  static final List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.14),
      blurRadius: 34,
      offset: const Offset(0, 17),
      spreadRadius: -10,
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static final List<BoxShadow> brandGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.24),
      blurRadius: 30,
      offset: const Offset(0, 14),
      spreadRadius: -7,
    ),
  ];

  static final List<BoxShadow> goldGlow = [
    BoxShadow(
      color: AppColors.accent.withValues(alpha: 0.28),
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: -7,
    ),
  ];
}
