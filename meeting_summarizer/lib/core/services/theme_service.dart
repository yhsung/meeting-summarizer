/// Theme service for managing application theme state and persistence
library;

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Service for managing application theme
class ThemeService extends ChangeNotifier {
  /// Private constructor
  ThemeService._() {
    _initialize();
  }

  /// Singleton instance
  static final ThemeService _instance = ThemeService._();

  /// Get the singleton instance
  static ThemeService get instance => _instance;

  /// Current theme mode
  ThemeMode _themeMode = ThemeMode.system;

  /// Whether high contrast mode is enabled
  bool _isHighContrastMode = false;

  /// Whether the theme service has been initialized
  bool _isInitialized = false;

  /// Current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Whether high contrast mode is enabled
  bool get isHighContrastMode => _isHighContrastMode;

  /// Whether the theme service has been initialized
  bool get isInitialized => _isInitialized;

  /// Get light theme
  ThemeData get lightTheme => _isHighContrastMode
      ? AppTheme.highContrastLightTheme
      : AppTheme.lightTheme;

  /// Get dark theme
  ThemeData get darkTheme =>
      _isHighContrastMode ? AppTheme.highContrastDarkTheme : AppTheme.darkTheme;

  /// Get current theme based on brightness
  ThemeData getCurrentTheme(Brightness brightness) {
    return AppTheme.getTheme(
      brightness: brightness,
      highContrast: _isHighContrastMode,
    );
  }

  /// Initialize the theme service
  Future<void> _initialize() async {
    try {
      await _loadThemeSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (error) {
      log('Failed to initialize theme service: $error');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Load theme settings from storage
  Future<void> _loadThemeSettings() async {
    try {
      // For now, use system defaults
      // In a full implementation, this would load from database
      _themeMode = ThemeMode.system;
      _isHighContrastMode = false;
    } catch (error) {
      log('Failed to load theme settings: $error');
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    // Update system UI overlay style
    _updateSystemUiOverlayStyle();
  }

  /// Toggle high contrast mode
  Future<void> toggleHighContrastMode() async {
    _isHighContrastMode = !_isHighContrastMode;
    notifyListeners();

    // Update system UI overlay style
    _updateSystemUiOverlayStyle();
  }

  /// Set high contrast mode
  Future<void> setHighContrastMode(bool enabled) async {
    if (_isHighContrastMode == enabled) return;

    _isHighContrastMode = enabled;
    notifyListeners();

    // Update system UI overlay style
    _updateSystemUiOverlayStyle();
  }

  /// Update system UI overlay style based on current theme
  void _updateSystemUiOverlayStyle() {
    final brightness = _getBrightness();
    final currentTheme = getCurrentTheme(brightness);
    final overlayStyle = AppTheme.getSystemUiOverlayStyle(currentTheme);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  /// Get current brightness based on theme mode
  Brightness _getBrightness() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  /// Get theme mode display name
  String getThemeModeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get available theme modes
  List<ThemeMode> get availableThemeModes => [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  /// Reset to default theme settings
  Future<void> resetToDefaults() async {
    await setThemeMode(ThemeMode.system);
    await setHighContrastMode(false);
  }

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}
