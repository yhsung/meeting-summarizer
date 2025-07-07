import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'recording.g.dart';

@JsonSerializable()
class Recording {
  final String id;
  final String filename;
  final String filePath;
  final int duration; // Duration in milliseconds
  final int fileSize; // File size in bytes
  final String format; // Audio format (wav, mp3, m4a)
  final String quality; // Quality setting (high, medium, low)
  final int sampleRate; // Sample rate in Hz
  final int bitDepth; // Bit depth (8, 16, 24)
  final int channels; // Number of audio channels
  final String? title; // User-provided title
  final String? description; // User-provided description
  final List<String>? tags; // List of tags
  final String? location; // Recording location
  final List<double>? waveformData; // Waveform data points
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete flag
  final Map<String, dynamic>? metadata; // Additional metadata

  const Recording({
    required this.id,
    required this.filename,
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.format,
    required this.quality,
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
    this.title,
    this.description,
    this.tags,
    this.location,
    this.waveformData,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.metadata,
  });

  /// Create a Recording from JSON
  factory Recording.fromJson(Map<String, dynamic> json) =>
      _$RecordingFromJson(json);

  /// Convert Recording to JSON
  Map<String, dynamic> toJson() => _$RecordingToJson(this);

  /// Create a Recording from database row
  factory Recording.fromDatabase(Map<String, dynamic> row) {
    return Recording(
      id: row['id'] as String,
      filename: row['filename'] as String,
      filePath: row['file_path'] as String,
      duration: row['duration'] as int,
      fileSize: row['file_size'] as int,
      format: row['format'] as String,
      quality: row['quality'] as String,
      sampleRate: row['sample_rate'] as int,
      bitDepth: row['bit_depth'] as int,
      channels: row['channels'] as int,
      title: row['title'] as String?,
      description: row['description'] as String?,
      tags: row['tags'] != null
          ? List<String>.from(
              // Handle JSON string to List conversion
              row['tags'] is String
                  ? _parseJsonList(row['tags'] as String)
                  : row['tags'],
            )
          : null,
      location: row['location'] as String?,
      waveformData: row['waveform_data'] != null
          ? List<double>.from(
              // Handle JSON string to List conversion
              row['waveform_data'] is String
                  ? _parseJsonList(row['waveform_data'] as String)
                  : row['waveform_data'],
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      isDeleted: (row['is_deleted'] as int) == 1,
      metadata: row['metadata'] != null
          ? _parseJsonMap(row['metadata'] as String)
          : null,
    );
  }

  /// Convert Recording to database row
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'filename': filename,
      'file_path': filePath,
      'duration': duration,
      'file_size': fileSize,
      'format': format,
      'quality': quality,
      'sample_rate': sampleRate,
      'bit_depth': bitDepth,
      'channels': channels,
      'title': title,
      'description': description,
      'tags': tags != null ? _encodeJsonList(tags!) : null,
      'location': location,
      'waveform_data': waveformData != null
          ? _encodeJsonList(waveformData!)
          : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_deleted': isDeleted ? 1 : 0,
      'metadata': metadata != null ? _encodeJsonMap(metadata!) : null,
    };
  }

  /// Create a copy with updated fields
  Recording copyWith({
    String? id,
    String? filename,
    String? filePath,
    int? duration,
    int? fileSize,
    String? format,
    String? quality,
    int? sampleRate,
    int? bitDepth,
    int? channels,
    String? title,
    String? description,
    List<String>? tags,
    String? location,
    List<double>? waveformData,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return Recording(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      waveformData: waveformData ?? this.waveformData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    final seconds = (duration / 1000).round();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted file size string
  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Check if recording is recent (within last 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inHours < 24;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recording && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Recording(id: $id, filename: $filename, duration: $formattedDuration)';

  // Helper methods for JSON encoding/decoding
  static dynamic _parseJsonList(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return [];
    }
  }

  static Map<String, dynamic>? _parseJsonMap(String jsonString) {
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      return null;
    }
  }

  static String _encodeJsonList(List<dynamic> list) {
    try {
      return jsonEncode(list);
    } catch (e) {
      return '[]';
    }
  }

  static String _encodeJsonMap(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (e) {
      return '{}';
    }
  }
}
