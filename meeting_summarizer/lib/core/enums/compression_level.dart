/// Compression level options for export operations
enum CompressionLevel {
  /// No compression - fastest but largest files
  none(0, 'None', 'No compression applied'),

  /// Fast compression - quick but moderate compression
  fast(3, 'Fast', 'Quick compression for speed'),

  /// Balanced compression - good balance of speed and size
  balanced(6, 'Balanced', 'Optimal balance of speed and compression'),

  /// Maximum compression - smallest files but slower
  maximum(9, 'Maximum', 'Best compression ratio');

  const CompressionLevel(this.level, this.displayName, this.description);

  /// Compression level value (0-9)
  final int level;

  /// User-friendly display name
  final String displayName;

  /// Description of the compression level
  final String description;

  /// Get compression level from integer value
  static CompressionLevel fromLevel(int level) {
    return CompressionLevel.values.firstWhere(
      (compression) => compression.level == level,
      orElse: () => CompressionLevel.balanced,
    );
  }

  /// Get estimated compression ratio (output/input size)
  double get estimatedRatio {
    switch (this) {
      case CompressionLevel.none:
        return 1.0;
      case CompressionLevel.fast:
        return 0.7;
      case CompressionLevel.balanced:
        return 0.5;
      case CompressionLevel.maximum:
        return 0.3;
    }
  }

  /// Get estimated processing time multiplier
  double get timeMultiplier {
    switch (this) {
      case CompressionLevel.none:
        return 1.0;
      case CompressionLevel.fast:
        return 1.5;
      case CompressionLevel.balanced:
        return 2.5;
      case CompressionLevel.maximum:
        return 4.0;
    }
  }
}
