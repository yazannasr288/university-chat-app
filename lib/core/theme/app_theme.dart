import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

export 'app_branding.dart';
export 'app_colors.dart';
export 'app_decorations.dart';
export 'app_gradients.dart';
export 'app_motion.dart';
export 'app_radii.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_theme_extensions.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarySoft,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accent,
        onSecondary: AppColors.textPrimary,
        secondaryContainer: AppColors.accentSoft,
        onSecondaryContainer: AppColors.textPrimary,
        tertiary: AppColors.secondary,
        onTertiary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.borderStrong,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
      focusColor: AppColors.primary.withValues(alpha: 0.10),
      hoverColor: AppColors.primary.withValues(alpha: 0.055),
      highlightColor: AppColors.primary.withValues(alpha: 0.075),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppFadePageTransitionsBuilder(),
          TargetPlatform.iOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.linux: AppFadePageTransitionsBuilder(),
          TargetPlatform.macOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.windows: AppFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppFadePageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        height: 1.55,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        toolbarHeight: 62,
        backgroundColor: Colors.white.withValues(alpha: 0.97),
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actionsIconTheme: const IconThemeData(color: AppColors.primary),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.info,
        elevation: 0,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.96),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 15),
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 1,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.fast,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primary.withValues(alpha: 0.07);
            }
            return null;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: const BorderSide(color: AppColors.borderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.white;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.primarySoft,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.primarySoft,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        labelStyle: textTheme.labelMedium,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.primaryDark.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  static ThemeData get dark {
    const darkBackground = AppColors.darkBackground;
    const darkSurface = AppColors.darkSurface;
    const darkSurfaceSoft = AppColors.darkSurfaceSoft;
    const darkBorder = AppColors.darkBorder;
    const darkBorderStrong = AppColors.darkBorderStrong;
    const darkTextPrimary = AppColors.darkTextPrimary;
    const darkTextSecondary = AppColors.darkTextSecondary;
    const darkTextMuted = AppColors.darkTextMuted;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF12385C),
        onPrimaryContainer: AppColors.darkTextPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.black,
        secondaryContainer: const Color(0xFF493B12),
        onSecondaryContainer: AppColors.accentSoft,
        tertiary: AppColors.primaryBright,
        onTertiary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: AppColors.error,
        onError: Colors.white,
        outline: darkBorderStrong,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: darkBackground,
      dividerColor: darkBorder,
      splashFactory: InkRipple.splashFactory,
      focusColor: AppColors.accent.withValues(alpha: 0.11),
      hoverColor: AppColors.accent.withValues(alpha: 0.055),
      highlightColor: AppColors.accent.withValues(alpha: 0.075),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppFadePageTransitionsBuilder(),
          TargetPlatform.iOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.linux: AppFadePageTransitionsBuilder(),
          TargetPlatform.macOS: AppFadePageTransitionsBuilder(),
          TargetPlatform.windows: AppFadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppFadePageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: darkTextPrimary,
        height: 1.6,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: darkTextSecondary,
        height: 1.55,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: darkTextMuted),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        toolbarHeight: 62,
        backgroundColor: darkBackground.withValues(alpha: 0.97),
        foregroundColor: darkTextPrimary,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.accent),
        actionsIconTheme: const IconThemeData(color: AppColors.accent),
        shape: const Border(
          bottom: BorderSide(color: darkBorder, width: 0.8),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF18324F),
        elevation: 0,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceSoft,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        prefixIconColor: AppColors.accent,
        suffixIconColor: darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: darkBorderStrong,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: darkBorderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 15),
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 1,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.fast,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accent.withValues(alpha: 0.13);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.accent.withValues(alpha: 0.07);
            }
            return null;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: const BorderSide(color: darkBorderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return darkSurfaceSoft;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.accent,
        textColor: darkTextPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        circularTrackColor: Color(0xFF1B2C40),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF162637),
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        labelStyle: textTheme.labelMedium,
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurfaceSoft.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: darkSurface.withValues(alpha: 0.97),
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : darkTextMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : darkTextMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF17334D).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: darkBorder),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.primary.withValues(alpha: 0.36),
        selectionHandleColor: AppColors.accent,
      ),
    );
  }
}

class AppFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.animationsDisabled(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.entrance,
      reverseCurve: AppMotion.exit,
    );

    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isRtl ? -0.035 : 0.035, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
