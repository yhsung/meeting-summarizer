/// File category enumeration for organizing files by type and purpose
enum FileCategory {
  /// Original audio recordings
  recordings('recordings', 'Audio Recordings', 'Original recorded audio files'),

  /// Enhanced/processed audio files
  enhancedAudio(
    'enhanced',
    'Enhanced Audio',
    'Processed and enhanced audio files',
  ),

  /// Transcription files and related data
  transcriptions(
    'transcriptions',
    'Transcriptions',
    'Text transcriptions of audio content',
  ),

  /// Summary files and reports
  summaries('summaries', 'Summaries', 'AI-generated summaries and reports'),

  /// Exported files for sharing
  exports('exports', 'Exports', 'Files prepared for export and sharing'),

  /// Temporary files and cache
  cache('cache', 'Cache', 'Temporary files and cached data'),

  /// User-imported files
  imports('imports', 'Imports', 'Files imported from external sources'),

  /// Archive/backup files
  archive('archive', 'Archive', 'Archived and backup files');

  const FileCategory(this.directoryName, this.displayName, this.description);

  /// Directory name for file organization
  final String directoryName;

  /// Human-readable display name
  final String displayName;

  /// Description of file category purpose
  final String description;

  /// Get all categories that store user content (exclude cache)
  static List<FileCategory> get userContentCategories => [
    recordings,
    enhancedAudio,
    transcriptions,
    summaries,
    exports,
    imports,
    archive,
  ];

  /// Get categories that can be safely cleaned up
  static List<FileCategory> get cleanupableCategories => [
    cache,
    exports, // Old exports can be regenerated
  ];

  /// Create FileCategory from directory name string
  static FileCategory fromString(String directoryName) {
    return FileCategory.values.firstWhere(
      (category) => category.directoryName == directoryName,
      orElse: () =>
          throw ArgumentError('Unknown file category: $directoryName'),
    );
  }
}
