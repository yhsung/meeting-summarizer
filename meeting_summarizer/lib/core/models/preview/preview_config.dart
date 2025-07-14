import '../../../core/enums/preview_type.dart';
import '../../../core/enums/thumbnail_size.dart';

/// Configuration options for file preview generation
class PreviewConfig {
  final PreviewType type;
  final ThumbnailSize thumbnailSize;
  final int? quality;
  final bool enableCache;
  final Duration? cacheExpiry;
  final Map<String, dynamic> typeSpecificOptions;

  const PreviewConfig({
    required this.type,
    this.thumbnailSize = ThumbnailSize.medium,
    this.quality,
    this.enableCache = true,
    this.cacheExpiry,
    this.typeSpecificOptions = const {},
  });

  /// Create config for image preview
  factory PreviewConfig.image({
    ThumbnailSize thumbnailSize = ThumbnailSize.medium,
    int quality = 85,
    bool enableCache = true,
    Duration? cacheExpiry,
  }) {
    return PreviewConfig(
      type: PreviewType.image,
      thumbnailSize: thumbnailSize,
      quality: quality,
      enableCache: enableCache,
      cacheExpiry: cacheExpiry,
    );
  }

  /// Create config for video preview
  factory PreviewConfig.video({
    ThumbnailSize thumbnailSize = ThumbnailSize.medium,
    int quality = 70,
    bool enableCache = true,
    Duration? cacheExpiry,
    int timeMs = 1000, // Time position for thumbnail extraction
  }) {
    return PreviewConfig(
      type: PreviewType.video,
      thumbnailSize: thumbnailSize,
      quality: quality,
      enableCache: enableCache,
      cacheExpiry: cacheExpiry,
      typeSpecificOptions: {'timeMs': timeMs},
    );
  }

  /// Create config for PDF preview
  factory PreviewConfig.pdf({
    ThumbnailSize thumbnailSize = ThumbnailSize.medium,
    int quality = 80,
    bool enableCache = true,
    Duration? cacheExpiry,
    int page = 1, // Page number for thumbnail
  }) {
    return PreviewConfig(
      type: PreviewType.pdf,
      thumbnailSize: thumbnailSize,
      quality: quality,
      enableCache: enableCache,
      cacheExpiry: cacheExpiry,
      typeSpecificOptions: {'page': page},
    );
  }

  /// Create config for audio preview (waveform)
  factory PreviewConfig.audio({
    ThumbnailSize thumbnailSize = ThumbnailSize.medium,
    bool enableCache = true,
    Duration? cacheExpiry,
    int waveformSamples = 128,
  }) {
    return PreviewConfig(
      type: PreviewType.audio,
      thumbnailSize: thumbnailSize,
      enableCache: enableCache,
      cacheExpiry: cacheExpiry,
      typeSpecificOptions: {'waveformSamples': waveformSamples},
    );
  }

  /// Create config for text preview
  factory PreviewConfig.text({
    ThumbnailSize thumbnailSize = ThumbnailSize.medium,
    bool enableCache = true,
    Duration? cacheExpiry,
    int maxLines = 20,
    String? syntaxHighlighting,
  }) {
    return PreviewConfig(
      type: PreviewType.text,
      thumbnailSize: thumbnailSize,
      enableCache: enableCache,
      cacheExpiry: cacheExpiry,
      typeSpecificOptions: {
        'maxLines': maxLines,
        if (syntaxHighlighting != null)
          'syntaxHighlighting': syntaxHighlighting,
      },
    );
  }

  /// Get the default cache duration for this preview type
  Duration get defaultCacheExpiry {
    if (cacheExpiry != null) return cacheExpiry!;

    switch (type) {
      case PreviewType.image:
      case PreviewType.pdf:
        return const Duration(days: 7); // Images and PDFs rarely change
      case PreviewType.video:
        return const Duration(days: 3); // Videos are large, moderate caching
      case PreviewType.audio:
        return const Duration(days: 5); // Audio waveforms are stable
      case PreviewType.text:
        return const Duration(hours: 12); // Text files may change more often
      case PreviewType.archive:
        return const Duration(days: 1); // Archive contents might change
      case PreviewType.unsupported:
        return const Duration(hours: 1); // Minimal caching for unsupported
    }
  }

  /// Get the default quality for this preview type if not specified
  int get defaultQuality {
    if (quality != null) return quality!;

    switch (type) {
      case PreviewType.image:
        return 85; // High quality for images
      case PreviewType.video:
        return 70; // Lower quality for video thumbnails
      case PreviewType.pdf:
        return 80; // Good quality for document readability
      case PreviewType.audio:
      case PreviewType.text:
      case PreviewType.archive:
      case PreviewType.unsupported:
        return 75; // Balanced quality for other types
    }
  }

  /// Create a copy with modified properties
  PreviewConfig copyWith({
    PreviewType? type,
    ThumbnailSize? thumbnailSize,
    int? quality,
    bool? enableCache,
    Duration? cacheExpiry,
    Map<String, dynamic>? typeSpecificOptions,
  }) {
    return PreviewConfig(
      type: type ?? this.type,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      quality: quality ?? this.quality,
      enableCache: enableCache ?? this.enableCache,
      cacheExpiry: cacheExpiry ?? this.cacheExpiry,
      typeSpecificOptions: typeSpecificOptions ?? this.typeSpecificOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreviewConfig &&
        other.type == type &&
        other.thumbnailSize == thumbnailSize &&
        other.quality == quality &&
        other.enableCache == enableCache &&
        other.cacheExpiry == cacheExpiry &&
        _mapsEqual(other.typeSpecificOptions, typeSpecificOptions);
  }

  @override
  int get hashCode {
    return type.hashCode ^
        thumbnailSize.hashCode ^
        quality.hashCode ^
        enableCache.hashCode ^
        cacheExpiry.hashCode ^
        typeSpecificOptions.hashCode;
  }

  /// Helper method to compare maps for equality
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'PreviewConfig(type: $type, thumbnailSize: $thumbnailSize, '
        'quality: $quality, enableCache: $enableCache, '
        'cacheExpiry: $cacheExpiry, typeSpecificOptions: $typeSpecificOptions)';
  }
}
