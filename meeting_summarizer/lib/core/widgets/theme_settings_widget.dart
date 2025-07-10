/// Theme settings widget for user theme customization
library;

import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'accessibility_wrapper.dart';

/// Widget for theme settings and customization
class ThemeSettingsWidget extends StatefulWidget {
  /// Whether to show advanced settings
  final bool showAdvancedSettings;

  /// Callback when theme changes
  final VoidCallback? onThemeChanged;

  const ThemeSettingsWidget({
    super.key,
    this.showAdvancedSettings = false,
    this.onThemeChanged,
  });

  @override
  State<ThemeSettingsWidget> createState() => _ThemeSettingsWidgetState();
}

class _ThemeSettingsWidgetState extends State<ThemeSettingsWidget> {
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
    widget.onThemeChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.palette, color: theme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Theme Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Theme mode selection
            _buildThemeModeSelector(context),

            const SizedBox(height: 20),

            // High contrast toggle
            _buildHighContrastToggle(context),

            if (widget.showAdvancedSettings) ...[
              const SizedBox(height: 20),
              _buildAdvancedSettings(context),
            ],

            const SizedBox(height: 20),

            // Reset button
            _buildResetButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme Mode',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: _themeService.availableThemeModes.map((mode) {
            return ButtonSegment<ThemeMode>(
              value: mode,
              label: Text(_themeService.getThemeModeDisplayName(mode)),
              icon: Icon(_getThemeModeIcon(mode)),
            );
          }).toList(),
          selected: {_themeService.themeMode},
          onSelectionChanged: (Set<ThemeMode> selection) {
            final selectedMode = selection.first;
            _themeService.setThemeMode(selectedMode);
            AccessibilityAnnouncement.announce(
              context,
              'Theme changed to ${_themeService.getThemeModeDisplayName(selectedMode)}',
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getThemeModeDescription(_themeService.themeMode),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildHighContrastToggle(BuildContext context) {
    final theme = Theme.of(context);

    return AccessibilityWrapper(
      semanticLabel: 'High contrast mode toggle',
      semanticHint: _themeService.isHighContrastMode
          ? 'Currently enabled. Tap to disable high contrast mode'
          : 'Currently disabled. Tap to enable high contrast mode',
      child: SwitchListTile(
        title: Text(
          'High Contrast Mode',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _themeService.isHighContrastMode
              ? 'Enhanced contrast for better visibility'
              : 'Tap to enable enhanced contrast for better visibility',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        value: _themeService.isHighContrastMode,
        onChanged: (value) {
          _themeService.setHighContrastMode(value);
          AccessibilityAnnouncement.announce(
            context,
            value
                ? 'High contrast mode enabled'
                : 'High contrast mode disabled',
          );
        },
        secondary: Icon(
          _themeService.isHighContrastMode
              ? Icons.contrast
              : Icons.contrast_outlined,
          color: _themeService.isHighContrastMode
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAdvancedSettings(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'System accessibility settings',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'The app respects your system-wide accessibility settings including reduced motion, large text, and high contrast preferences.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: AccessibilityWrapper(
        semanticLabel: 'Reset theme settings',
        semanticHint: 'Reset all theme settings to default values',
        child: OutlinedButton.icon(
          onPressed: () async {
            await _themeService.resetToDefaults();
            if (context.mounted) {
              AccessibilityAnnouncement.announce(
                context,
                'Theme settings reset to defaults',
              );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Theme settings reset to defaults'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: theme.colorScheme.inverseSurface,
                ),
              );
            }
          },
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Reset to Defaults'),
        ),
      ),
    );
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }

  String _getThemeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Always use light theme';
      case ThemeMode.dark:
        return 'Always use dark theme';
      case ThemeMode.system:
        return 'Follow system theme setting';
    }
  }
}

/// Quick theme toggle button
class QuickThemeToggle extends StatelessWidget {
  /// Icon size
  final double iconSize;

  /// Whether to show tooltip
  final bool showTooltip;

  const QuickThemeToggle({
    super.key,
    this.iconSize = 24,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) {
        final currentMode = themeService.themeMode;
        final nextMode = _getNextThemeMode(currentMode);
        final icon = _getThemeModeIcon(currentMode);
        final tooltip = showTooltip
            ? 'Current: ${themeService.getThemeModeDisplayName(currentMode)}. Tap to switch to ${themeService.getThemeModeDisplayName(nextMode)}'
            : null;

        return AccessibilityWrapper(
          semanticLabel: 'Theme toggle button',
          semanticHint: tooltip,
          tooltip: tooltip,
          isButton: true,
          child: IconButton(
            icon: Icon(icon, size: iconSize),
            onPressed: () {
              themeService.setThemeMode(nextMode);
              AccessibilityAnnouncement.announce(
                context,
                'Theme changed to ${themeService.getThemeModeDisplayName(nextMode)}',
              );
            },
            color: theme.colorScheme.onSurface,
          ),
        );
      },
    );
  }

  ThemeMode _getNextThemeMode(ThemeMode currentMode) {
    switch (currentMode) {
      case ThemeMode.light:
        return ThemeMode.dark;
      case ThemeMode.dark:
        return ThemeMode.system;
      case ThemeMode.system:
        return ThemeMode.light;
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }
}
