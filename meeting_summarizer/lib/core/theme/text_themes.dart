/// Text theme definitions for the Meeting Summarizer application
library;

import 'package:flutter/material.dart';

/// Text themes for the application
class AppTextThemes {
  /// Private constructor to prevent instantiation
  AppTextThemes._();

  /// Base font family
  static const String primaryFontFamily = 'Roboto';
  static const String monospaceFontFamily = 'Roboto Mono';

  /// Light theme text theme
  static const TextTheme lightTextTheme = TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 57.0,
      fontWeight: FontWeight.w400,
      height: 1.12,
      letterSpacing: -0.25,
      color: Color(0xFF1C1B1F),
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 45.0,
      fontWeight: FontWeight.w400,
      height: 1.16,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 36.0,
      fontWeight: FontWeight.w400,
      height: 1.22,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 32.0,
      fontWeight: FontWeight.w400,
      height: 1.25,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 28.0,
      fontWeight: FontWeight.w400,
      height: 1.29,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      height: 1.33,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 22.0,
      fontWeight: FontWeight.w400,
      height: 1.27,
      letterSpacing: 0.0,
      color: Color(0xFF1C1B1F),
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFF1C1B1F),
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFF1C1B1F),
    ),

    // Label styles
    labelLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFF1C1B1F),
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      height: 1.33,
      letterSpacing: 0.5,
      color: Color(0xFF1C1B1F),
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      height: 1.45,
      letterSpacing: 0.5,
      color: Color(0xFF1C1B1F),
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w400,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFF1C1B1F),
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      height: 1.43,
      letterSpacing: 0.25,
      color: Color(0xFF1C1B1F),
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      height: 1.33,
      letterSpacing: 0.4,
      color: Color(0xFF1C1B1F),
    ),
  );

  /// Dark theme text theme
  static const TextTheme darkTextTheme = TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 57.0,
      fontWeight: FontWeight.w400,
      height: 1.12,
      letterSpacing: -0.25,
      color: Color(0xFFE6E1E5),
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 45.0,
      fontWeight: FontWeight.w400,
      height: 1.16,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 36.0,
      fontWeight: FontWeight.w400,
      height: 1.22,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 32.0,
      fontWeight: FontWeight.w400,
      height: 1.25,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 28.0,
      fontWeight: FontWeight.w400,
      height: 1.29,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      height: 1.33,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 22.0,
      fontWeight: FontWeight.w400,
      height: 1.27,
      letterSpacing: 0.0,
      color: Color(0xFFE6E1E5),
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFFE6E1E5),
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFFE6E1E5),
    ),

    // Label styles
    labelLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFFE6E1E5),
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      height: 1.33,
      letterSpacing: 0.5,
      color: Color(0xFFE6E1E5),
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      height: 1.45,
      letterSpacing: 0.5,
      color: Color(0xFFE6E1E5),
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w400,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFFE6E1E5),
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      height: 1.43,
      letterSpacing: 0.25,
      color: Color(0xFFE6E1E5),
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      height: 1.33,
      letterSpacing: 0.4,
      color: Color(0xFFE6E1E5),
    ),
  );

  /// High contrast light theme text theme
  static const TextTheme highContrastLightTextTheme = TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 57.0,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -0.25,
      color: Color(0xFF000000),
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 45.0,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 36.0,
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 32.0,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      height: 1.29,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 24.0,
      fontWeight: FontWeight.w700,
      height: 1.33,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 22.0,
      fontWeight: FontWeight.w700,
      height: 1.27,
      letterSpacing: 0.0,
      color: Color(0xFF000000),
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w700,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFF000000),
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w700,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFF000000),
    ),

    // Label styles
    labelLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w700,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFF000000),
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w700,
      height: 1.33,
      letterSpacing: 0.5,
      color: Color(0xFF000000),
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      height: 1.45,
      letterSpacing: 0.5,
      color: Color(0xFF000000),
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFF000000),
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.25,
      color: Color(0xFF000000),
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      height: 1.33,
      letterSpacing: 0.4,
      color: Color(0xFF000000),
    ),
  );

  /// High contrast dark theme text theme
  static const TextTheme highContrastDarkTextTheme = TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 57.0,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -0.25,
      color: Color(0xFFFFFFFF),
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 45.0,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 36.0,
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 32.0,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      height: 1.29,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 24.0,
      fontWeight: FontWeight.w700,
      height: 1.33,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),

    // Title styles
    titleLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 22.0,
      fontWeight: FontWeight.w700,
      height: 1.27,
      letterSpacing: 0.0,
      color: Color(0xFFFFFFFF),
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w700,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFFFFFFFF),
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w700,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFFFFFFFF),
    ),

    // Label styles
    labelLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w700,
      height: 1.43,
      letterSpacing: 0.1,
      color: Color(0xFFFFFFFF),
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w700,
      height: 1.33,
      letterSpacing: 0.5,
      color: Color(0xFFFFFFFF),
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      height: 1.45,
      letterSpacing: 0.5,
      color: Color(0xFFFFFFFF),
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      height: 1.50,
      letterSpacing: 0.15,
      color: Color(0xFFFFFFFF),
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0.25,
      color: Color(0xFFFFFFFF),
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      height: 1.33,
      letterSpacing: 0.4,
      color: Color(0xFFFFFFFF),
    ),
  );

  /// Monospace text style for code and technical content
  static const TextStyle monospaceTextStyle = TextStyle(
    fontFamily: monospaceFontFamily,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.0,
  );

  /// Get text style for waveform labels
  static TextStyle getWaveformLabelStyle(ThemeData theme) {
    return theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Get text style for recording duration
  static TextStyle getRecordingDurationStyle(ThemeData theme) {
    return theme.textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Get text style for transcription text
  static TextStyle getTranscriptionStyle(ThemeData theme) {
    return theme.textTheme.bodyMedium!.copyWith(
      height: 1.6,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Get text style for summary content
  static TextStyle getSummaryStyle(ThemeData theme) {
    return theme.textTheme.bodyLarge!.copyWith(
      height: 1.7,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Get text style for error messages
  static TextStyle getErrorStyle(ThemeData theme) {
    return theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w500,
    );
  }

  /// Get text style for success messages
  static TextStyle getSuccessStyle(ThemeData theme) {
    return theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );
  }

  /// Get text style for warning messages
  static TextStyle getWarningStyle(ThemeData theme) {
    return theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.tertiary,
      fontWeight: FontWeight.w500,
    );
  }
}
