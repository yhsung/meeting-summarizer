/// Application theme configuration and management
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'color_schemes.dart';
import 'text_themes.dart';
import 'component_themes.dart';

/// Theme configuration for the Meeting Summarizer application
class AppTheme {
  /// Private constructor to prevent instantiation
  AppTheme._();

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.lightColorScheme,
      textTheme: AppTextThemes.lightTextTheme,
      appBarTheme: AppComponentThemes.lightAppBarTheme,
      cardTheme: AppComponentThemes.lightCardTheme,
      elevatedButtonTheme: AppComponentThemes.lightElevatedButtonTheme,
      outlinedButtonTheme: AppComponentThemes.lightOutlinedButtonTheme,
      textButtonTheme: AppComponentThemes.lightTextButtonTheme,
      floatingActionButtonTheme:
          AppComponentThemes.lightFloatingActionButtonTheme,
      bottomNavigationBarTheme:
          AppComponentThemes.lightBottomNavigationBarTheme,
      switchTheme: AppComponentThemes.lightSwitchTheme,
      segmentedButtonTheme: AppComponentThemes.lightSegmentedButtonTheme,
      sliderTheme: AppComponentThemes.lightSliderTheme,
      progressIndicatorTheme: AppComponentThemes.lightProgressIndicatorTheme,
      dividerTheme: AppComponentThemes.lightDividerTheme,
      dialogTheme: AppComponentThemes.lightDialogTheme,
      snackBarTheme: AppComponentThemes.lightSnackBarTheme,
      tooltipTheme: AppComponentThemes.lightTooltipTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.darkColorScheme,
      textTheme: AppTextThemes.darkTextTheme,
      appBarTheme: AppComponentThemes.darkAppBarTheme,
      cardTheme: AppComponentThemes.darkCardTheme,
      elevatedButtonTheme: AppComponentThemes.darkElevatedButtonTheme,
      outlinedButtonTheme: AppComponentThemes.darkOutlinedButtonTheme,
      textButtonTheme: AppComponentThemes.darkTextButtonTheme,
      floatingActionButtonTheme:
          AppComponentThemes.darkFloatingActionButtonTheme,
      bottomNavigationBarTheme: AppComponentThemes.darkBottomNavigationBarTheme,
      switchTheme: AppComponentThemes.darkSwitchTheme,
      segmentedButtonTheme: AppComponentThemes.darkSegmentedButtonTheme,
      sliderTheme: AppComponentThemes.darkSliderTheme,
      progressIndicatorTheme: AppComponentThemes.darkProgressIndicatorTheme,
      dividerTheme: AppComponentThemes.darkDividerTheme,
      dialogTheme: AppComponentThemes.darkDialogTheme,
      snackBarTheme: AppComponentThemes.darkSnackBarTheme,
      tooltipTheme: AppComponentThemes.darkTooltipTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitionsTheme,
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// High contrast light theme for accessibility
  static ThemeData get highContrastLightTheme {
    final baseTheme = lightTheme;
    return baseTheme.copyWith(
      colorScheme: AppColorSchemes.highContrastLightColorScheme,
      textTheme: AppTextThemes.highContrastLightTextTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: AppColorSchemes.highContrastLightColorScheme.surface,
        foregroundColor: AppColorSchemes.highContrastLightColorScheme.onSurface,
      ),
      cardTheme: baseTheme.cardTheme.copyWith(
        color: AppColorSchemes.highContrastLightColorScheme.surface,
      ),
      dividerTheme: baseTheme.dividerTheme.copyWith(
        color: AppColorSchemes.highContrastLightColorScheme.outline,
        thickness: 2.0,
      ),
    );
  }

  /// High contrast dark theme for accessibility
  static ThemeData get highContrastDarkTheme {
    final baseTheme = darkTheme;
    return baseTheme.copyWith(
      colorScheme: AppColorSchemes.highContrastDarkColorScheme,
      textTheme: AppTextThemes.highContrastDarkTextTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: AppColorSchemes.highContrastDarkColorScheme.surface,
        foregroundColor: AppColorSchemes.highContrastDarkColorScheme.onSurface,
      ),
      cardTheme: baseTheme.cardTheme.copyWith(
        color: AppColorSchemes.highContrastDarkColorScheme.surface,
      ),
      dividerTheme: baseTheme.dividerTheme.copyWith(
        color: AppColorSchemes.highContrastDarkColorScheme.outline,
        thickness: 2.0,
      ),
    );
  }

  /// Page transition theme for consistent animations
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      );

  /// Configure system UI overlay style for status bar
  static SystemUiOverlayStyle getSystemUiOverlayStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.colorScheme.surface,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: theme.colorScheme.outline,
    );
  }

  /// Get theme mode from string value
  static ThemeMode themeModeFromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Convert theme mode to string
  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Get theme based on brightness and high contrast settings
  static ThemeData getTheme({
    required Brightness brightness,
    bool highContrast = false,
  }) {
    if (highContrast) {
      return brightness == Brightness.light
          ? highContrastLightTheme
          : highContrastDarkTheme;
    }
    return brightness == Brightness.light ? lightTheme : darkTheme;
  }

  /// Common animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  /// Common animation curves
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;

  /// Common border radius values
  static const double smallBorderRadius = 4.0;
  static const double mediumBorderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double xlargeBorderRadius = 16.0;

  /// Common spacing values
  static const double xxsmallSpacing = 2.0;
  static const double xsmallSpacing = 4.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double xlargeSpacing = 32.0;
  static const double xxlargeSpacing = 48.0;

  /// Common elevation values
  static const double lowElevation = 1.0;
  static const double mediumElevation = 4.0;
  static const double highElevation = 8.0;
  static const double veryHighElevation = 16.0;
}
