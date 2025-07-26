// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transcription _$TranscriptionFromJson(Map<String, dynamic> json) =>
    Transcription(
      id: json['id'] as String,
      recordingId: json['recordingId'] as String,
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      language: json['language'] as String,
      provider: json['provider'] as String,
      segments: (json['segments'] as List<dynamic>?)
          ?.map((e) => TranscriptionSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: $enumDecode(_$TranscriptionStatusEnumMap, json['status']),
      errorMessage: json['errorMessage'] as String?,
      processingTime: (json['processingTime'] as num?)?.toInt(),
      wordCount: (json['wordCount'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TranscriptionToJson(Transcription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recordingId': instance.recordingId,
      'text': instance.text,
      'confidence': instance.confidence,
      'language': instance.language,
      'provider': instance.provider,
      'segments': instance.segments,
      'status': _$TranscriptionStatusEnumMap[instance.status]!,
      'errorMessage': instance.errorMessage,
      'processingTime': instance.processingTime,
      'wordCount': instance.wordCount,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$TranscriptionStatusEnumMap = {
  TranscriptionStatus.pending: 'pending',
  TranscriptionStatus.processing: 'processing',
  TranscriptionStatus.completed: 'completed',
  TranscriptionStatus.failed: 'failed',
};

TranscriptionSegment _$TranscriptionSegmentFromJson(
        Map<String, dynamic> json) =>
    TranscriptionSegment(
      startTime: (json['startTime'] as num).toInt(),
      endTime: (json['endTime'] as num).toInt(),
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      words:
          (json['words'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$TranscriptionSegmentToJson(
        TranscriptionSegment instance) =>
    <String, dynamic>{
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'text': instance.text,
      'confidence': instance.confidence,
      'words': instance.words,
    };
