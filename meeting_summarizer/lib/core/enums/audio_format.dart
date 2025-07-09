enum AudioFormat {
  wav('wav', 'audio/wav', true, false),
  mp3('mp3', 'audio/mpeg', false, true),
  m4a('m4a', 'audio/mp4', false, true),
  aac('aac', 'audio/aac', false, true);

  const AudioFormat(
    this.extension,
    this.mimeType,
    this.isLossless,
    this.isCompressed,
  );

  final String extension;
  final String mimeType;
  final bool isLossless;
  final bool isCompressed;

  static AudioFormat fromExtension(String extension) {
    return AudioFormat.values.firstWhere(
      (format) => format.extension == extension.toLowerCase(),
      orElse: () => AudioFormat.wav,
    );
  }

  bool get isSupported => true;

  double get compressionRatio {
    switch (this) {
      case AudioFormat.wav:
        return 1.0;
      case AudioFormat.mp3:
        return 0.1;
      case AudioFormat.m4a:
        return 0.12;
      case AudioFormat.aac:
        return 0.11;
    }
  }

  String get description {
    switch (this) {
      case AudioFormat.wav:
        return 'Uncompressed audio format with highest quality';
      case AudioFormat.mp3:
        return 'Popular compressed format with good quality/size balance';
      case AudioFormat.m4a:
        return 'Apple\'s compressed format with better quality than MP3';
      case AudioFormat.aac:
        return 'Advanced Audio Coding with excellent compression';
    }
  }

  String get displayName {
    switch (this) {
      case AudioFormat.wav:
        return 'WAV (Uncompressed)';
      case AudioFormat.mp3:
        return 'MP3 (Compressed)';
      case AudioFormat.m4a:
        return 'M4A (Apple)';
      case AudioFormat.aac:
        return 'AAC (Advanced)';
    }
  }

  String get detailedDescription {
    switch (this) {
      case AudioFormat.wav:
        return 'Highest quality, larger file size (~10MB/min)';
      case AudioFormat.mp3:
        return 'Good quality, smaller file size (~1MB/min)';
      case AudioFormat.m4a:
        return 'High quality, optimized for Apple devices (~1.2MB/min)';
      case AudioFormat.aac:
        return 'Excellent compression, modern standard (~1.1MB/min)';
    }
  }

  /// Check if format is supported on current platform
  bool get isSupportedOnCurrentPlatform {
    // For now, assume all formats are supported
    // TODO: Add platform-specific checks if needed
    return true;
  }
}
