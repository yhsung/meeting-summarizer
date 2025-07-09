/// Color scheme definitions for the Meeting Summarizer application
library;

import 'package:flutter/material.dart';

/// Color schemes for the application
class AppColorSchemes {
  /// Private constructor to prevent instantiation
  AppColorSchemes._();

  /// Primary seed color for the application
  static const Color primarySeedColor = Color(0xFF2196F3); // Blue

  /// Secondary seed color for accent elements
  static const Color secondarySeedColor = Color(0xFF4CAF50); // Green

  /// Tertiary seed color for additional elements
  static const Color tertiarySeedColor = Color(0xFFFF9800); // Orange

  /// Light color scheme
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1976D2),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBBDEFB),
    onPrimaryContainer: Color(0xFF0D47A1),
    secondary: Color(0xFF388E3C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFC8E6C9),
    onSecondaryContainer: Color(0xFF1B5E20),
    tertiary: Color(0xFFEF6C00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFCC80),
    onTertiaryContainer: Color(0xFFE65100),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFCDD2),
    onErrorContainer: Color(0xFFB71C1C),
    surface: Color(0xFFFFFBFE),
    onSurface: Color(0xFF1C1B1F),
    surfaceContainerHighest: Color(0xFFE6E1E5),
    onSurfaceVariant: Color(0xFF49454F),
    outline: Color(0xFF79747E),
    outlineVariant: Color(0xFFCAC4D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF313033),
    onInverseSurface: Color(0xFFF4EFF4),
    inversePrimary: Color(0xFF90CAF9),
    surfaceTint: Color(0xFF1976D2),
  );

  /// Dark color scheme
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1565C0),
    onPrimaryContainer: Color(0xFFBBDEFB),
    secondary: Color(0xFF81C784),
    onSecondary: Color(0xFF1B5E20),
    secondaryContainer: Color(0xFF2E7D32),
    onSecondaryContainer: Color(0xFFC8E6C9),
    tertiary: Color(0xFFFFB74D),
    onTertiary: Color(0xFFE65100),
    tertiaryContainer: Color(0xFFF57C00),
    onTertiaryContainer: Color(0xFFFFCC80),
    error: Color(0xFFEF5350),
    onError: Color(0xFFB71C1C),
    errorContainer: Color(0xFFC62828),
    onErrorContainer: Color(0xFFFFCDD2),
    surface: Color(0xFF1C1B1F),
    onSurface: Color(0xFFE6E1E5),
    surfaceContainerHighest: Color(0xFF49454F),
    onSurfaceVariant: Color(0xFFCAC4D0),
    outline: Color(0xFF938F99),
    outlineVariant: Color(0xFF49454F),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6E1E5),
    onInverseSurface: Color(0xFF313033),
    inversePrimary: Color(0xFF1976D2),
    surfaceTint: Color(0xFF90CAF9),
  );

  /// High contrast light color scheme for accessibility
  static const ColorScheme highContrastLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF000000),
    onPrimaryContainer: Color(0xFFFFFFFF),
    secondary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF000000),
    onSecondaryContainer: Color(0xFFFFFFFF),
    tertiary: Color(0xFF000000),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF000000),
    onTertiaryContainer: Color(0xFFFFFFFF),
    error: Color(0xFF9B0000),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF9B0000),
    onErrorContainer: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFFE0E0E0),
    onSurfaceVariant: Color(0xFF000000),
    outline: Color(0xFF000000),
    outlineVariant: Color(0xFF000000),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFF000000),
  );

  /// High contrast dark color scheme for accessibility
  static const ColorScheme highContrastDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFFFFFFFF),
    onPrimaryContainer: Color(0xFF000000),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFFFFFFFF),
    onSecondaryContainer: Color(0xFF000000),
    tertiary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFF000000),
    tertiaryContainer: Color(0xFFFFFFFF),
    onTertiaryContainer: Color(0xFF000000),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFFFF6B6B),
    onErrorContainer: Color(0xFF000000),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFF2A2A2A),
    onSurfaceVariant: Color(0xFFFFFFFF),
    outline: Color(0xFFFFFFFF),
    outlineVariant: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF000000),
    surfaceTint: Color(0xFFFFFFFF),
  );

  /// Audio waveform color palette
  static const List<Color> waveformColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFFEB3B), // Yellow
  ];

  /// Recording state colors
  static const Color recordingActiveColor = Color(0xFFF44336); // Red
  static const Color recordingPausedColor = Color(0xFFFF9800); // Orange
  static const Color recordingStoppedColor = Color(0xFF757575); // Grey

  /// Audio level colors
  static const Color audioLevelLowColor = Color(0xFF4CAF50); // Green
  static const Color audioLevelMediumColor = Color(0xFFFF9800); // Orange
  static const Color audioLevelHighColor = Color(0xFFF44336); // Red

  /// Transcription state colors
  static const Color transcriptionProcessingColor = Color(0xFF2196F3); // Blue
  static const Color transcriptionCompletedColor = Color(0xFF4CAF50); // Green
  static const Color transcriptionErrorColor = Color(0xFFF44336); // Red

  /// Summary quality colors
  static const Color summaryExcellentColor = Color(0xFF4CAF50); // Green
  static const Color summaryGoodColor = Color(0xFF8BC34A); // Light Green
  static const Color summaryFairColor = Color(0xFFFF9800); // Orange
  static const Color summaryPoorColor = Color(0xFFF44336); // Red

  /// Accessibility colors
  static const Color accessibilityFocusColor = Color(0xFF0000FF); // Blue
  static const Color accessibilityErrorColor = Color(0xFFFF0000); // Red
  static const Color accessibilitySuccessColor = Color(0xFF00FF00); // Green
  static const Color accessibilityWarningColor = Color(0xFFFFFF00); // Yellow

  /// Get waveform color by index
  static Color getWaveformColor(int index) {
    return waveformColors[index % waveformColors.length];
  }

  /// Get audio level color based on amplitude
  static Color getAudioLevelColor(double amplitude) {
    if (amplitude < 0.3) return audioLevelLowColor;
    if (amplitude < 0.7) return audioLevelMediumColor;
    return audioLevelHighColor;
  }

  /// Get transcription state color
  static Color getTranscriptionStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'processing':
        return transcriptionProcessingColor;
      case 'completed':
        return transcriptionCompletedColor;
      case 'error':
      case 'failed':
        return transcriptionErrorColor;
      default:
        return transcriptionProcessingColor;
    }
  }

  /// Get summary quality color
  static Color getSummaryQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return summaryExcellentColor;
      case 'good':
        return summaryGoodColor;
      case 'fair':
        return summaryFairColor;
      case 'poor':
        return summaryPoorColor;
      default:
        return summaryGoodColor;
    }
  }
}
