import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get scheme => appTheme.colorScheme;
  TextTheme get textTheme => appTheme.textTheme;
  bool get isDark => appTheme.brightness == Brightness.dark;

  Color get appPrimary => isDark ? AppColors.accent : AppColors.primary;

  Color get appTextPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  Color get appTextSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  Color get appTextMuted =>
      isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  Color get appBorder => isDark ? AppColors.darkBorder : AppColors.border;

  Color get appBorderStrong =>
      isDark ? AppColors.darkBorderStrong : AppColors.borderStrong;

  Color get appCardColor => isDark
      ? AppColors.darkCard.withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.95);

  Color get appCardColorStrong => isDark
      ? AppColors.darkCardStrong.withValues(alpha: 0.98)
      : Colors.white.withValues(alpha: 0.98);

  Color get appGlassSurface => isDark
      ? AppColors.darkSurfaceSoft.withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.88);

  Color get appGlassBorder => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.72);

  Color get appSurfaceSoft =>
      isDark ? AppColors.darkSurfaceSoft : AppColors.surfaceSoft;

  Color get appSurfaceAlt =>
      isDark ? AppColors.darkSurfaceAlt : AppColors.backgroundAlt;

  Color get appBubbleOther =>
      isDark ? AppColors.darkBubbleOther : AppColors.bubbleOther;

  Color get appBubbleOtherBorder =>
      isDark ? AppColors.darkBubbleOtherBorder : AppColors.bubbleOtherBorder;

  Color get appChatInputFill =>
      isDark ? AppColors.darkChatInputFill : AppColors.chatInputFill;

  Color get appDrawerItemBackground =>
      isDark ? AppColors.darkDrawerItemBackground : AppColors.surfaceSoft;

  Color get appMessageMineAlpha =>
      Colors.white.withValues(alpha: isDark ? 0.12 : 0.15);

  Color get appMessageMineBorder =>
      isDark ? Colors.white24 : Colors.white30;

  Color get appMessageMineText => Colors.white;

  Color get appMessageMineMeta => Colors.white.withValues(alpha: 0.76);

  Color get appMessageOtherText => appTextPrimary;

  Color get appMessageOtherMeta => appTextSecondary.withValues(alpha: 0.85);

  Color get appMessageBubbleRadius => const Color(0xFF121212); // Reference only

  LinearGradient get appMessageMineGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1B6DAF),
            Color(0xFF0E4F8C),
            Color(0xFF0A3D70),
          ],
          stops: [0.0, 0.56, 1.0],
        )
      : AppGradients.messageMine;

  LinearGradient get appScaffoldGradient {
    if (!isDark) {
      return AppGradients.softBackground;
    }

    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF07111D),
        Color(0xFF0A1725),
        Color(0xFF0D1D2E),
      ],
      stops: [0.0, 0.44, 1.0],
    );
  }

  Color get appPrimaryGlow => isDark
      ? AppColors.primary.withValues(alpha: 0.22)
      : AppColors.primary.withValues(alpha: 0.14);

  Color get appAccentGlow => isDark
      ? AppColors.accent.withValues(alpha: 0.17)
      : AppColors.accent.withValues(alpha: 0.22);

  Color get appSecondaryGlow => isDark
      ? AppColors.secondary.withValues(alpha: 0.15)
      : AppColors.secondary.withValues(alpha: 0.12);

  Color get appInteractiveOverlay => appPrimary.withValues(
        alpha: isDark ? 0.10 : 0.065,
      );

  LinearGradient get appPrimaryGradient => isDark
      ? LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.30),
            AppColors.primaryBright.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.13),
          ],
          stops: const [0.0, 0.62, 1.0],
        )
      : LinearGradient(
          colors: [
            AppColors.primarySoft.withValues(alpha: 0.96),
            const Color(0xFFF7FBFF),
            AppColors.accentSoft.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.62, 1.0],
        );

  LinearGradient get appAccentGradient => isDark
      ? LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.accent.withValues(alpha: 0.06),
          ],
        )
      : LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.09),
            AppColors.accent.withValues(alpha: 0.05),
          ],
        );
}
