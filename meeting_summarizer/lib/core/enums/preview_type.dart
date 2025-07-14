/// Preview type definitions for different file types
enum PreviewType {
  /// Image files (PNG, JPG, GIF, etc.)
  image('image', 'Image', 'Direct image display with zoom capabilities'),

  /// Video files (MP4, MOV, AVI, etc.)
  video('video', 'Video', 'Video preview with thumbnail and playback controls'),

  /// Audio files (MP3, WAV, AAC, etc.)
  audio('audio', 'Audio', 'Audio waveform and playback controls'),

  /// PDF documents
  pdf('pdf', 'PDF Document', 'PDF viewer with page navigation'),

  /// Text files (TXT, JSON, MD, etc.)
  text('text', 'Text File', 'Syntax-highlighted text content display'),

  /// Archive files (ZIP, TAR, etc.)
  archive(
    'archive',
    'Archive',
    'Archive contents listing with nested previews',
  ),

  /// Unsupported or unknown file types
  unsupported(
    'unsupported',
    'Unsupported',
    'File type not supported for preview',
  );

  const PreviewType(this.value, this.displayName, this.description);

  /// Internal type identifier
  final String value;

  /// User-friendly display name
  final String displayName;

  /// Description of the preview type
  final String description;

  /// Get preview type from file extension
  static PreviewType fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');

    switch (ext) {
      // Image formats
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return PreviewType.image;

      // Video formats
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
      case 'flv':
      case 'm4v':
        return PreviewType.video;

      // Audio formats
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
      case 'ogg':
      case 'm4a':
      case 'wma':
        return PreviewType.audio;

      // PDF documents
      case 'pdf':
        return PreviewType.pdf;

      // Text formats
      case 'txt':
      case 'md':
      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
      case 'dart':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
        return PreviewType.text;

      // Archive formats
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
      case 'bz2':
        return PreviewType.archive;

      default:
        return PreviewType.unsupported;
    }
  }

  /// Check if this preview type supports thumbnail generation
  bool get supportsThumbnails {
    switch (this) {
      case PreviewType.image:
      case PreviewType.video:
      case PreviewType.pdf:
        return true;
      case PreviewType.audio:
      case PreviewType.text:
      case PreviewType.archive:
      case PreviewType.unsupported:
        return false;
    }
  }

  /// Check if this preview type supports zoom functionality
  bool get supportsZoom {
    switch (this) {
      case PreviewType.image:
      case PreviewType.pdf:
        return true;
      case PreviewType.video:
      case PreviewType.audio:
      case PreviewType.text:
      case PreviewType.archive:
      case PreviewType.unsupported:
        return false;
    }
  }

  /// Check if this preview type supports fullscreen mode
  bool get supportsFullscreen {
    switch (this) {
      case PreviewType.image:
      case PreviewType.video:
      case PreviewType.pdf:
        return true;
      case PreviewType.audio:
      case PreviewType.text:
      case PreviewType.archive:
      case PreviewType.unsupported:
        return false;
    }
  }
}
