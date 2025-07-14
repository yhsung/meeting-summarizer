import 'dart:typed_data';
import 'dart:ui';
import '../../../core/enums/preview_type.dart';
import '../../../core/enums/thumbnail_size.dart';

/// Result of a file preview generation operation
class PreviewResult {
  final bool success;
  final PreviewType type;
  final String? thumbnailPath;
  final Uint8List? thumbnailData;
  final ThumbnailSize size;
  final String? errorMessage;
  final Duration processingTime;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const PreviewResult({
    required this.success,
    required this.type,
    this.thumbnailPath,
    this.thumbnailData,
    required this.size,
    this.errorMessage,
    required this.processingTime,
    this.metadata = const {},
    required this.createdAt,
  });

  /// Create a successful preview result
  factory PreviewResult.success({
    required PreviewType type,
    String? thumbnailPath,
    Uint8List? thumbnailData,
    required ThumbnailSize size,
    required Duration processingTime,
    Map<String, dynamic> metadata = const {},
  }) {
    return PreviewResult(
      success: true,
      type: type,
      thumbnailPath: thumbnailPath,
      thumbnailData: thumbnailData,
      size: size,
      processingTime: processingTime,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// Create a failed preview result
  factory PreviewResult.failure({
    required PreviewType type,
    required String errorMessage,
    required ThumbnailSize size,
    required Duration processingTime,
    Map<String, dynamic> metadata = const {},
  }) {
    return PreviewResult(
      success: false,
      type: type,
      errorMessage: errorMessage,
      size: size,
      processingTime: processingTime,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// Check if the preview has thumbnail data available
  bool get hasThumbnail => thumbnailPath != null || thumbnailData != null;

  /// Get the thumbnail data, either from memory or by reading from file
  Future<Uint8List?> getThumbnailData() async {
    if (thumbnailData != null) {
      return thumbnailData;
    }

    if (thumbnailPath != null) {
      try {
        final file = await _getFile(thumbnailPath!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        // File not accessible or doesn't exist
        return null;
      }
    }

    return null;
  }

  /// Get file size information if available
  int? get thumbnailSizeBytes {
    if (thumbnailData != null) {
      return thumbnailData!.length;
    }

    final sizeValue = metadata['fileSizeBytes'];
    return sizeValue is int ? sizeValue : null;
  }

  /// Get dimensions if available
  Size? get thumbnailDimensions {
    final width = metadata['width'];
    final height = metadata['height'];

    if (width is int && height is int) {
      return Size(width.toDouble(), height.toDouble());
    }

    return null;
  }

  /// Get format information
  String? get format => metadata['format'] as String?;

  /// Get compression ratio if available
  double? get compressionRatio {
    final ratio = metadata['compressionRatio'];
    return ratio is double ? ratio : (ratio is int ? ratio.toDouble() : null);
  }

  /// Check if the preview is cached
  bool get isCached => thumbnailPath != null;

  /// Check if the preview is in memory
  bool get isInMemory => thumbnailData != null;

  /// Get human-readable processing time
  String get formattedProcessingTime {
    if (processingTime.inSeconds > 0) {
      return '${processingTime.inSeconds}s';
    } else {
      return '${processingTime.inMilliseconds}ms';
    }
  }

  /// Get human-readable file size
  String get formattedSize {
    final sizeBytes = thumbnailSizeBytes;
    if (sizeBytes == null) return 'Unknown';

    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Create a copy with modified properties
  PreviewResult copyWith({
    bool? success,
    PreviewType? type,
    String? thumbnailPath,
    Uint8List? thumbnailData,
    ThumbnailSize? size,
    String? errorMessage,
    Duration? processingTime,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return PreviewResult(
      success: success ?? this.success,
      type: type ?? this.type,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      size: size ?? this.size,
      errorMessage: errorMessage ?? this.errorMessage,
      processingTime: processingTime ?? this.processingTime,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreviewResult &&
        other.success == success &&
        other.type == type &&
        other.thumbnailPath == thumbnailPath &&
        other.size == size &&
        other.errorMessage == errorMessage &&
        other.processingTime == processingTime &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return success.hashCode ^
        type.hashCode ^
        thumbnailPath.hashCode ^
        size.hashCode ^
        errorMessage.hashCode ^
        processingTime.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'PreviewResult(success: $success, type: $type, '
        'hasThumbnail: $hasThumbnail, size: $size, '
        'processingTime: $formattedProcessingTime, '
        'errorMessage: $errorMessage)';
  }

  /// Helper method to get file (would need to import dart:io in actual implementation)
  Future<dynamic> _getFile(String path) async {
    // This is a placeholder - in actual implementation, would import dart:io
    // and return File(path)
    throw UnimplementedError('File access not implemented in this context');
  }
}
