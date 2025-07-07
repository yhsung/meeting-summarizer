import 'package:json_annotation/json_annotation.dart';

part 'app_settings.g.dart';

@JsonSerializable()
class AppSettings {
  final String key;
  final String value;
  final SettingType type;
  final SettingCategory category;
  final String? description;
  final bool isSensitive; // Whether to store in secure storage
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppSettings({
    required this.key,
    required this.value,
    required this.type,
    required this.category,
    this.description,
    required this.isSensitive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create an AppSettings from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  /// Convert AppSettings to JSON
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  /// Create an AppSettings from database row
  factory AppSettings.fromDatabase(Map<String, dynamic> row) {
    return AppSettings(
      key: row['key'] as String,
      value: row['value'] as String,
      type: SettingType.fromString(row['type'] as String),
      category: SettingCategory.fromString(row['category'] as String),
      description: row['description'] as String?,
      isSensitive: (row['is_sensitive'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  /// Convert AppSettings to database row
  Map<String, dynamic> toDatabase() {
    return {
      'key': key,
      'value': value,
      'type': type.value,
      'category': category.value,
      'description': description,
      'is_sensitive': isSensitive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  AppSettings copyWith({
    String? key,
    String? value,
    SettingType? type,
    SettingCategory? category,
    String? description,
    bool? isSensitive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      key: key ?? this.key,
      value: value ?? this.value,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      isSensitive: isSensitive ?? this.isSensitive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get typed value based on setting type
  T getValue<T>() {
    switch (type) {
      case SettingType.string:
        return value as T;
      case SettingType.int:
        return int.parse(value) as T;
      case SettingType.double:
        return double.parse(value) as T;
      case SettingType.bool:
        return (value.toLowerCase() == 'true') as T;
      case SettingType.json:
        // In production, you'd parse JSON here
        return value as T;
    }
  }

  /// Create AppSettings with typed value
  static AppSettings withTypedValue<T>({
    required String key,
    required T value,
    required SettingCategory category,
    String? description,
    bool isSensitive = false,
  }) {
    SettingType type;
    String stringValue;

    if (value is String) {
      type = SettingType.string;
      stringValue = value;
    } else if (value is int) {
      type = SettingType.int;
      stringValue = value.toString();
    } else if (value is double) {
      type = SettingType.double;
      stringValue = value.toString();
    } else if (value is bool) {
      type = SettingType.bool;
      stringValue = value.toString();
    } else {
      type = SettingType.json;
      stringValue = value.toString(); // In production, you'd use JSON encoding
    }

    final now = DateTime.now();
    return AppSettings(
      key: key,
      value: stringValue,
      type: type,
      category: category,
      description: description,
      isSensitive: isSensitive,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() =>
      'AppSettings(key: $key, value: $value, category: ${category.value})';
}

enum SettingType {
  string('string'),
  int('int'),
  double('double'),
  bool('bool'),
  json('json');

  const SettingType(this.value);

  final String value;

  static SettingType fromString(String value) {
    return SettingType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SettingType.string,
    );
  }

  @override
  String toString() => value;
}

enum SettingCategory {
  audio('audio'),
  transcription('transcription'),
  summary('summary'),
  ui('ui'),
  general('general'),
  security('security'),
  storage('storage');

  const SettingCategory(this.value);

  final String value;

  static SettingCategory fromString(String value) {
    return SettingCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => SettingCategory.general,
    );
  }

  String get displayName {
    switch (this) {
      case SettingCategory.audio:
        return 'Audio Settings';
      case SettingCategory.transcription:
        return 'Transcription Settings';
      case SettingCategory.summary:
        return 'Summary Settings';
      case SettingCategory.ui:
        return 'UI Settings';
      case SettingCategory.general:
        return 'General Settings';
      case SettingCategory.security:
        return 'Security Settings';
      case SettingCategory.storage:
        return 'Storage Settings';
    }
  }

  @override
  String toString() => value;
}

/// Predefined setting keys for type safety
class SettingKeys {
  // Audio settings
  static const String audioFormat = 'audio_format';
  static const String audioQuality = 'audio_quality';
  static const String recordingLimit = 'recording_limit';
  static const String enableNoiseReduction = 'enable_noise_reduction';
  static const String enableAutoGainControl = 'enable_auto_gain_control';

  // Transcription settings
  static const String transcriptionLanguage = 'transcription_language';
  static const String transcriptionProvider = 'transcription_provider';
  static const String autoTranscribe = 'auto_transcribe';

  // Summary settings
  static const String summaryType = 'summary_type';
  static const String autoSummarize = 'auto_summarize';

  // UI settings
  static const String themeMode = 'theme_mode';
  static const String waveformEnabled = 'waveform_enabled';

  // General settings
  static const String appVersion = 'app_version';
  static const String firstLaunch = 'first_launch';

  // Security settings
  static const String encryptRecordings = 'encrypt_recordings';
  static const String autoLockTimeout = 'auto_lock_timeout';

  // Storage settings
  static const String maxStorageSize = 'max_storage_size';
  static const String autoCleanup = 'auto_cleanup';
  static const String backupEnabled = 'backup_enabled';
}
