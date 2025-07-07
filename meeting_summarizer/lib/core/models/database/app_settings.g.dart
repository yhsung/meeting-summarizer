// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  key: json['key'] as String,
  value: json['value'] as String,
  type: $enumDecode(_$SettingTypeEnumMap, json['type']),
  category: $enumDecode(_$SettingCategoryEnumMap, json['category']),
  description: json['description'] as String?,
  isSensitive: json['isSensitive'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'type': _$SettingTypeEnumMap[instance.type]!,
      'category': _$SettingCategoryEnumMap[instance.category]!,
      'description': instance.description,
      'isSensitive': instance.isSensitive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$SettingTypeEnumMap = {
  SettingType.string: 'string',
  SettingType.int: 'int',
  SettingType.double: 'double',
  SettingType.bool: 'bool',
  SettingType.json: 'json',
};

const _$SettingCategoryEnumMap = {
  SettingCategory.audio: 'audio',
  SettingCategory.transcription: 'transcription',
  SettingCategory.summary: 'summary',
  SettingCategory.ui: 'ui',
  SettingCategory.general: 'general',
  SettingCategory.security: 'security',
  SettingCategory.storage: 'storage',
};
