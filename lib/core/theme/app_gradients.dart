import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
      AppColors.primaryBright,
    ],
    stops: [0.0, 0.56, 1.0],
  );

  static const LinearGradient primaryVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.primaryBright,
      AppColors.primary,
      AppColors.primaryDark,
    ],
    stops: [0.0, 0.48, 1.0],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFFFDC68),
      AppColors.accent,
      AppColors.accentDeep,
    ],
    stops: [0.0, 0.56, 1.0],
  );

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
      AppColors.secondary,
      AppColors.primaryBright,
    ],
    stops: [0.0, 0.42, 0.76, 1.0],
  );

  static const LinearGradient appBar = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
      AppColors.primaryBright,
    ],
    stops: [0.0, 0.58, 1.0],
  );

  static const LinearGradient softBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFEFEFF),
      AppColors.background,
      AppColors.backgroundAlt,
    ],
    stops: [0.0, 0.42, 1.0],
  );

  static const LinearGradient drawer = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
    ],
  );

  static const LinearGradient messageMine = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      AppColors.primaryDark,
      AppColors.primary,
      Color(0xFF1479C6),
    ],
    stops: [0.0, 0.58, 1.0],
  );

  static const LinearGradient accentGlow = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      AppColors.accent,
      AppColors.accentDeep,
    ],
  );

  static const LinearGradient video = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.supportNavy,
      AppColors.primaryDark,
    ],
  );
}
