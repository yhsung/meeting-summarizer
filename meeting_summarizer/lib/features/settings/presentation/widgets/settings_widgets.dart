/// Settings widgets for different data types and UI components
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/database/app_settings.dart';

/// Base class for all settings widgets
abstract class BaseSettingWidget extends StatefulWidget {
  final AppSettings setting;
  final Function(String key, dynamic value)? onChanged;
  final bool enabled;

  const BaseSettingWidget({
    super.key,
    required this.setting,
    this.onChanged,
    this.enabled = true,
  });
}

/// Widget for boolean/switch settings
class BooleanSettingWidget extends BaseSettingWidget {
  const BooleanSettingWidget({
    super.key,
    required super.setting,
    super.onChanged,
    super.enabled,
  });

  @override
  State<BooleanSettingWidget> createState() => _BooleanSettingWidgetState();
}

class _BooleanSettingWidgetState extends State<BooleanSettingWidget> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.setting.getValue<bool>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        _getDisplayName(widget.setting.key),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: widget.setting.description != null
          ? Text(widget.setting.description!, style: theme.textTheme.bodySmall)
          : null,
      trailing: Switch(
        value: _value,
        onChanged: widget.enabled
            ? (value) {
                setState(() {
                  _value = value;
                });
                widget.onChanged?.call(widget.setting.key, value);
              }
            : null,
      ),
    );
  }
}

/// Widget for string dropdown/selection settings
class StringSelectionSettingWidget extends BaseSettingWidget {
  final List<String> options;
  final Map<String, String>? optionDisplayNames;

  const StringSelectionSettingWidget({
    super.key,
    required super.setting,
    required this.options,
    this.optionDisplayNames,
    super.onChanged,
    super.enabled,
  });

  @override
  State<StringSelectionSettingWidget> createState() =>
      _StringSelectionSettingWidgetState();
}

class _StringSelectionSettingWidgetState
    extends State<StringSelectionSettingWidget> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.setting.getValue<String>();
    // Ensure value is in options list
    if (!widget.options.contains(_value)) {
      _value = widget.options.isNotEmpty ? widget.options.first : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        _getDisplayName(widget.setting.key),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.setting.description != null)
            Text(widget.setting.description!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: widget.options.map((option) {
              final displayName = widget.optionDisplayNames?[option] ?? option;
              return DropdownMenuItem(value: option, child: Text(displayName));
            }).toList(),
            onChanged: widget.enabled
                ? (value) {
                    if (value != null) {
                      setState(() {
                        _value = value;
                      });
                      widget.onChanged?.call(widget.setting.key, value);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Widget for numeric (int/double) settings with slider or text input
class NumericSettingWidget extends BaseSettingWidget {
  final double min;
  final double max;
  final int? divisions;
  final String? unit;
  final bool useSlider;

  const NumericSettingWidget({
    super.key,
    required super.setting,
    required this.min,
    required this.max,
    this.divisions,
    this.unit,
    this.useSlider = false,
    super.onChanged,
    super.enabled,
  });

  @override
  State<NumericSettingWidget> createState() => _NumericSettingWidgetState();
}

class _NumericSettingWidgetState extends State<NumericSettingWidget> {
  late double _value;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.setting.type == SettingType.int) {
      _value = widget.setting.getValue<int>().toDouble();
    } else {
      _value = widget.setting.getValue<double>();
    }
    _controller = TextEditingController(text: _getDisplayValue());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getDisplayValue() {
    if (widget.setting.type == SettingType.int) {
      return _value.round().toString();
    } else {
      return _value.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        _getDisplayName(widget.setting.key),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.setting.description != null)
            Text(widget.setting.description!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (widget.useSlider) ...[
            Slider(
              value: _value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              label: '${_getDisplayValue()}${widget.unit ?? ''}',
              onChanged: widget.enabled
                  ? (value) {
                      setState(() {
                        _value = value;
                        _controller.text = _getDisplayValue();
                      });
                      final actualValue = widget.setting.type == SettingType.int
                          ? value.round()
                          : value;
                      widget.onChanged?.call(widget.setting.key, actualValue);
                    }
                  : null,
            ),
            Text(
              '${_getDisplayValue()}${widget.unit ?? ''}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            TextFormField(
              controller: _controller,
              keyboardType: widget.setting.type == SettingType.int
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                if (widget.setting.type == SettingType.int)
                  FilteringTextInputFormatter.digitsOnly
                else
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: widget.unit,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              enabled: widget.enabled,
              onChanged: (value) {
                try {
                  final numericValue = widget.setting.type == SettingType.int
                      ? int.parse(value)
                      : double.parse(value);

                  if (numericValue >= widget.min &&
                      numericValue <= widget.max) {
                    setState(() {
                      _value = numericValue.toDouble();
                    });
                    widget.onChanged?.call(widget.setting.key, numericValue);
                  }
                } catch (_) {
                  // Invalid input, ignore
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget for text/string input settings
class TextSettingWidget extends BaseSettingWidget {
  final bool obscureText;
  final int? maxLength;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const TextSettingWidget({
    super.key,
    required super.setting,
    this.obscureText = false,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    super.onChanged,
    super.enabled,
  });

  @override
  State<TextSettingWidget> createState() => _TextSettingWidgetState();
}

class _TextSettingWidgetState extends State<TextSettingWidget> {
  late TextEditingController _controller;
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.setting.getValue<String>(),
    );
    _isObscured = widget.obscureText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        _getDisplayName(widget.setting.key),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.setting.description != null)
            Text(widget.setting.description!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controller,
            obscureText: _isObscured,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _isObscured ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    )
                  : null,
            ),
            enabled: widget.enabled,
            onChanged: (value) {
              widget.onChanged?.call(widget.setting.key, value);
            },
          ),
        ],
      ),
    );
  }
}

/// Widget for category section headers
class SettingsCategoryHeader extends StatelessWidget {
  final SettingCategory category;
  final int settingsCount;

  const SettingsCategoryHeader({
    super.key,
    required this.category,
    required this.settingsCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(category),
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              settingsCount.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(SettingCategory category) {
    switch (category) {
      case SettingCategory.audio:
        return Icons.volume_up;
      case SettingCategory.transcription:
        return Icons.transcribe;
      case SettingCategory.summary:
        return Icons.summarize;
      case SettingCategory.ui:
        return Icons.palette;
      case SettingCategory.general:
        return Icons.settings;
      case SettingCategory.security:
        return Icons.security;
      case SettingCategory.storage:
        return Icons.storage;
    }
  }
}

/// Widget for search functionality
class SettingsSearchWidget extends StatefulWidget {
  final Function(String query) onSearchChanged;
  final String initialQuery;

  const SettingsSearchWidget({
    super.key,
    required this.onSearchChanged,
    this.initialQuery = '',
  });

  @override
  State<SettingsSearchWidget> createState() => _SettingsSearchWidgetState();
}

class _SettingsSearchWidgetState extends State<SettingsSearchWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search settings...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: widget.onSearchChanged,
      ),
    );
  }
}

/// Factory function to create appropriate widget for setting type
Widget createSettingWidget(
  AppSettings setting, {
  Function(String, dynamic)? onChanged,
}) {
  switch (setting.type) {
    case SettingType.bool:
      return BooleanSettingWidget(setting: setting, onChanged: onChanged);

    case SettingType.int:
      return NumericSettingWidget(
        setting: setting,
        min: _getMinValue(setting.key),
        max: _getMaxValue(setting.key),
        useSlider: _shouldUseSlider(setting.key),
        unit: _getUnit(setting.key),
        onChanged: onChanged,
      );

    case SettingType.double:
      return NumericSettingWidget(
        setting: setting,
        min: _getMinValue(setting.key),
        max: _getMaxValue(setting.key),
        useSlider: _shouldUseSlider(setting.key),
        unit: _getUnit(setting.key),
        onChanged: onChanged,
      );

    case SettingType.string:
      final options = _getStringOptions(setting.key);
      if (options != null) {
        return StringSelectionSettingWidget(
          setting: setting,
          options: options,
          optionDisplayNames: _getOptionDisplayNames(setting.key),
          onChanged: onChanged,
        );
      } else {
        return TextSettingWidget(
          setting: setting,
          obscureText: setting.isSensitive,
          onChanged: onChanged,
        );
      }

    case SettingType.json:
      return TextSettingWidget(
        setting: setting,
        keyboardType: TextInputType.multiline,
        onChanged: onChanged,
      );
  }
}

/// Helper function to get display name for setting key
String _getDisplayName(String key) {
  final displayNames = {
    SettingKeys.audioFormat: 'Audio Format',
    SettingKeys.audioQuality: 'Audio Quality',
    SettingKeys.recordingLimit: 'Recording Limit',
    SettingKeys.enableNoiseReduction: 'Noise Reduction',
    SettingKeys.enableAutoGainControl: 'Auto Gain Control',
    SettingKeys.transcriptionLanguage: 'Transcription Language',
    SettingKeys.transcriptionProvider: 'Transcription Provider',
    SettingKeys.autoTranscribe: 'Auto Transcribe',
    SettingKeys.summaryType: 'Summary Type',
    SettingKeys.autoSummarize: 'Auto Summarize',
    SettingKeys.themeMode: 'Theme Mode',
    SettingKeys.waveformEnabled: 'Show Waveform',
    SettingKeys.encryptRecordings: 'Encrypt Recordings',
    SettingKeys.autoLockTimeout: 'Auto Lock Timeout',
    SettingKeys.maxStorageSize: 'Max Storage Size',
    SettingKeys.autoCleanup: 'Auto Cleanup',
    SettingKeys.backupEnabled: 'Cloud Backup',
    'notification_enabled': 'Enable Notifications',
    'notification_sound': 'Notification Sound',
    'notification_vibration': 'Notification Vibration',
    'cloud_sync_enabled': 'Cloud Sync',
    'developer_mode': 'Developer Mode',
  };

  return displayNames[key] ?? _camelCaseToTitle(key);
}

/// Convert camelCase to Title Case
String _camelCaseToTitle(String camelCase) {
  return camelCase
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ')
      .trim();
}

/// Get minimum value for numeric settings
double _getMinValue(String key) {
  switch (key) {
    case SettingKeys.recordingLimit:
      return 60; // 1 minute minimum
    case SettingKeys.autoLockTimeout:
      return 30; // 30 seconds minimum
    case SettingKeys.maxStorageSize:
      return 100; // 100MB minimum
    default:
      return 0;
  }
}

/// Get maximum value for numeric settings
double _getMaxValue(String key) {
  switch (key) {
    case SettingKeys.recordingLimit:
      return 14400; // 4 hours maximum
    case SettingKeys.autoLockTimeout:
      return 3600; // 1 hour maximum
    case SettingKeys.maxStorageSize:
      return 10240; // 10GB maximum
    default:
      return 100;
  }
}

/// Check if setting should use slider instead of text input
bool _shouldUseSlider(String key) {
  switch (key) {
    case SettingKeys.autoLockTimeout:
    case SettingKeys.maxStorageSize:
      return true;
    default:
      return false;
  }
}

/// Get unit for numeric settings
String? _getUnit(String key) {
  switch (key) {
    case SettingKeys.recordingLimit:
    case SettingKeys.autoLockTimeout:
      return 's';
    case SettingKeys.maxStorageSize:
      return 'MB';
    default:
      return null;
  }
}

/// Get string options for dropdown settings
List<String>? _getStringOptions(String key) {
  switch (key) {
    case SettingKeys.audioFormat:
      return ['m4a', 'wav', 'mp3', 'aac'];
    case SettingKeys.audioQuality:
      return ['low', 'medium', 'high', 'highest'];
    case SettingKeys.themeMode:
      return ['light', 'dark', 'system'];
    case SettingKeys.summaryType:
      return ['brief', 'comprehensive', 'detailed', 'bullet_points'];
    case SettingKeys.transcriptionLanguage:
      return [
        'auto',
        'en',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'ru',
        'ja',
        'ko',
        'zh',
      ];
    default:
      return null;
  }
}

/// Get display names for options
Map<String, String>? _getOptionDisplayNames(String key) {
  switch (key) {
    case SettingKeys.audioFormat:
      return {
        'm4a': 'M4A (AAC)',
        'wav': 'WAV (Uncompressed)',
        'mp3': 'MP3 (Compressed)',
        'aac': 'AAC (Compressed)',
      };
    case SettingKeys.audioQuality:
      return {
        'low': 'Low (32kbps)',
        'medium': 'Medium (64kbps)',
        'high': 'High (128kbps)',
        'highest': 'Highest (256kbps)',
      };
    case SettingKeys.themeMode:
      return {
        'light': 'Light Theme',
        'dark': 'Dark Theme',
        'system': 'Follow System',
      };
    case SettingKeys.summaryType:
      return {
        'brief': 'Brief Summary',
        'comprehensive': 'Comprehensive',
        'detailed': 'Detailed Analysis',
        'bullet_points': 'Bullet Points',
      };
    case SettingKeys.transcriptionLanguage:
      return {
        'auto': 'Auto-detect',
        'en': 'English',
        'es': 'Spanish',
        'fr': 'French',
        'de': 'German',
        'it': 'Italian',
        'pt': 'Portuguese',
        'ru': 'Russian',
        'ja': 'Japanese',
        'ko': 'Korean',
        'zh': 'Chinese',
      };
    default:
      return null;
  }
}
