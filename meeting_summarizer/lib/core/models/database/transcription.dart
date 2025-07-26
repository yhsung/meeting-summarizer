import 'package:json_annotation/json_annotation.dart';

part 'transcription.g.dart';

@JsonSerializable()
class Transcription {
  final String id;
  final String recordingId;
  final String text;
  final double confidence; // Confidence score 0.0-1.0
  final String language;
  final String provider; // Transcription service provider
  final List<TranscriptionSegment>?
      segments; // Time-segmented transcription data
  final TranscriptionStatus status;
  final String? errorMessage; // Error details if transcription failed
  final int? processingTime; // Processing time in milliseconds
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transcription({
    required this.id,
    required this.recordingId,
    required this.text,
    required this.confidence,
    required this.language,
    required this.provider,
    this.segments,
    required this.status,
    this.errorMessage,
    this.processingTime,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a Transcription from JSON
  factory Transcription.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionFromJson(json);

  /// Convert Transcription to JSON
  Map<String, dynamic> toJson() => _$TranscriptionToJson(this);

  /// Create a Transcription from database row
  factory Transcription.fromDatabase(Map<String, dynamic> row) {
    return Transcription(
      id: row['id'] as String,
      recordingId: row['recording_id'] as String,
      text: row['text'] as String,
      confidence: (row['confidence'] as num).toDouble(),
      language: row['language'] as String,
      provider: row['provider'] as String,
      segments: row['segments'] != null
          ? _parseSegments(row['segments'] as String)
          : null,
      status: TranscriptionStatus.fromString(row['status'] as String),
      errorMessage: row['error_message'] as String?,
      processingTime: row['processing_time'] as int?,
      wordCount: row['word_count'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  /// Convert Transcription to database row
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'recording_id': recordingId,
      'text': text,
      'confidence': confidence,
      'language': language,
      'provider': provider,
      'segments': segments != null ? _encodeSegments(segments!) : null,
      'status': status.value,
      'error_message': errorMessage,
      'processing_time': processingTime,
      'word_count': wordCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  Transcription copyWith({
    String? id,
    String? recordingId,
    String? text,
    double? confidence,
    String? language,
    String? provider,
    List<TranscriptionSegment>? segments,
    TranscriptionStatus? status,
    String? errorMessage,
    int? processingTime,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transcription(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      language: language ?? this.language,
      provider: provider ?? this.provider,
      segments: segments ?? this.segments,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      processingTime: processingTime ?? this.processingTime,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted confidence percentage
  String get formattedConfidence => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get formatted processing time
  String? get formattedProcessingTime {
    if (processingTime == null) return null;
    final seconds = processingTime! / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  /// Check if transcription is completed successfully
  bool get isCompleted => status == TranscriptionStatus.completed;

  /// Check if transcription failed
  bool get isFailed => status == TranscriptionStatus.failed;

  /// Check if transcription is in progress
  bool get isProcessing => status == TranscriptionStatus.processing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transcription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Transcription(id: $id, recordingId: $recordingId, status: ${status.value})';

  // Helper methods for segments encoding/decoding
  static List<TranscriptionSegment>? _parseSegments(String segmentsJson) {
    try {
      // Simplified parsing - in production you'd use dart:convert
      return [];
    } catch (e) {
      return null;
    }
  }

  static String _encodeSegments(List<TranscriptionSegment> segments) {
    // Simplified encoding - in production you'd use dart:convert
    return '[]';
  }
}

@JsonSerializable()
class TranscriptionSegment {
  final int startTime; // Start time in milliseconds
  final int endTime; // End time in milliseconds
  final String text;
  final double confidence;
  final List<String>? words;

  const TranscriptionSegment({
    required this.startTime,
    required this.endTime,
    required this.text,
    required this.confidence,
    this.words,
  });

  /// Create a TranscriptionSegment from JSON
  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionSegmentFromJson(json);

  /// Convert TranscriptionSegment to JSON
  Map<String, dynamic> toJson() => _$TranscriptionSegmentToJson(this);

  /// Get formatted time range
  String get formattedTimeRange {
    final start = Duration(milliseconds: startTime);
    final end = Duration(milliseconds: endTime);
    return '${_formatDuration(start)} - ${_formatDuration(end)}';
  }

  /// Get segment duration
  Duration get duration => Duration(milliseconds: endTime - startTime);

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptionSegment &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          text == other.text;

  @override
  int get hashCode => Object.hash(startTime, endTime, text);

  @override
  String toString() => 'TranscriptionSegment($formattedTimeRange: $text)';
}

enum TranscriptionStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed');

  const TranscriptionStatus(this.value);

  final String value;

  static TranscriptionStatus fromString(String value) {
    return TranscriptionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TranscriptionStatus.pending,
    );
  }

  @override
  String toString() => value;
}
