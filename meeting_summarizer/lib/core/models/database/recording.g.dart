// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recording _$RecordingFromJson(Map<String, dynamic> json) => Recording(
      id: json['id'] as String,
      filename: json['filename'] as String,
      filePath: json['filePath'] as String,
      duration: (json['duration'] as num).toInt(),
      fileSize: (json['fileSize'] as num).toInt(),
      format: json['format'] as String,
      quality: json['quality'] as String,
      sampleRate: (json['sampleRate'] as num).toInt(),
      bitDepth: (json['bitDepth'] as num).toInt(),
      channels: (json['channels'] as num).toInt(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      location: json['location'] as String?,
      waveformData: (json['waveformData'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RecordingToJson(Recording instance) => <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'filePath': instance.filePath,
      'duration': instance.duration,
      'fileSize': instance.fileSize,
      'format': instance.format,
      'quality': instance.quality,
      'sampleRate': instance.sampleRate,
      'bitDepth': instance.bitDepth,
      'channels': instance.channels,
      'title': instance.title,
      'description': instance.description,
      'tags': instance.tags,
      'location': instance.location,
      'waveformData': instance.waveformData,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isDeleted': instance.isDeleted,
      'metadata': instance.metadata,
    };
