import 'package:flutter/material.dart';

abstract final class AppColors {
  // Core brand colors: institutional blue with a restrained warm-gold accent.
  static const Color primary = Color(0xFF075FAF);
  static const Color primaryDark = Color(0xFF063E75);
  static const Color primaryBright = Color(0xFF1688D1);
  static const Color primarySoft = Color(0xFFDDEDFC);
  static const Color secondary = Color(0xFF247BC1);
  static const Color accent = Color(0xFFF2C94C);
  static const Color accentDeep = Color(0xFFD7A91F);
  static const Color accentSoft = Color(0xFFFFF5CE);

  // Premium neutral palette.
  static const Color background = Color(0xFFF5F8FC);
  static const Color backgroundAlt = Color(0xFFEBF2F9);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF7FAFD);
  static const Color border = Color(0xFFDCE7F1);
  static const Color borderStrong = Color(0xFFC4D5E5);

  // Dark theme palette.
  static const Color darkBackground = Color(0xFF07111D);
  static const Color darkSurface = Color(0xFF0C1826);
  static const Color darkSurfaceSoft = Color(0xFF122337);
  static const Color darkSurfaceAlt = Color(0xFF0E1D2E);
  static const Color darkCard = Color(0xFF0F1D2D);
  static const Color darkCardStrong = Color(0xFF0C1724);
  static const Color darkBorder = Color(0xFF243A52);
  static const Color darkBorderStrong = Color(0xFF365878);
  static const Color darkTextPrimary = Color(0xFFEAF4FF);
  static const Color darkTextSecondary = Color(0xFFB2C6DA);
  static const Color darkTextMuted = Color(0xFF8198B2);
  static const Color darkBubbleOther = Color(0xFF122437);
  static const Color darkBubbleOtherBorder = Color(0xFF2A4561);
  static const Color darkChatInputFill = Color(0xFF152638);
  static const Color darkDrawerItemBackground = Color(0xFF102031);

  // Text.
  static const Color textPrimary = Color(0xFF102E49);
  static const Color textSecondary = Color(0xFF5B7185);
  static const Color textMuted = Color(0xFF8697A8);

  // Status.
  static const Color success = Color(0xFF16866E);
  static const Color successSoft = Color(0xFFDDF4EE);
  static const Color error = Color(0xFFD95C5C);
  static const Color errorSoft = Color(0xFFFFE6E6);
  static const Color warning = Color(0xFFB27A00);
  static const Color warningSoft = Color(0xFFFFF4D4);
  static const Color info = Color(0xFF2D5B86);
  static const Color infoSoft = Color(0xFFE4EEF7);

  // Supporting colors for specific surfaces.
  static const Color supportPurple = Color(0xFF7A5CC8);
  static const Color supportEmerald = Color(0xFF1E9B72);
  static const Color supportCoral = Color(0xFFD66A5F);
  static const Color supportNavy = Color(0xFF22364F);

  // Chat surfaces.
  static const Color bubbleOther = Colors.white;
  static const Color bubbleOtherBorder = Color(0xFFD6E3EF);
  static const Color chatInputFill = Color(0xFFF1F6FA);

  static const Color white = Colors.white;
  static const Color black = Color(0xFF0F1B27);
}
