import '../../enums/batch_operation.dart';
import '../storage/file_metadata.dart';

/// Configuration for batch processing operations
class BatchConfig {
  final BatchOperation operation;
  final List<FileMetadata> files;
  final Map<String, dynamic> options;
  final bool requireConfirmation;
  final bool createBackup;
  final String? targetDirectory;
  final bool continueOnError;
  final int maxConcurrency;

  const BatchConfig({
    required this.operation,
    required this.files,
    this.options = const {},
    this.requireConfirmation = true,
    this.createBackup = false,
    this.targetDirectory,
    this.continueOnError = false,
    this.maxConcurrency = 3,
  });

  /// Create config for rename operations
  factory BatchConfig.rename({
    required List<FileMetadata> files,
    required String pattern,
    String? replacement,
    bool addIndex = false,
    bool preserveExtension = true,
    bool requireConfirmation = true,
    bool createBackup = false,
  }) {
    return BatchConfig(
      operation: BatchOperation.rename,
      files: files,
      requireConfirmation: requireConfirmation,
      createBackup: createBackup,
      options: {
        'pattern': pattern,
        'replacement': replacement,
        'addIndex': addIndex,
        'preserveExtension': preserveExtension,
      },
    );
  }

  /// Create config for move operations
  factory BatchConfig.move({
    required List<FileMetadata> files,
    required String targetDirectory,
    bool requireConfirmation = true,
    bool createBackup = false,
    bool continueOnError = false,
  }) {
    return BatchConfig(
      operation: BatchOperation.move,
      files: files,
      targetDirectory: targetDirectory,
      requireConfirmation: requireConfirmation,
      createBackup: createBackup,
      continueOnError: continueOnError,
    );
  }

  /// Create config for delete operations
  factory BatchConfig.delete({
    required List<FileMetadata> files,
    bool requireConfirmation = true,
    bool createBackup = true,
    bool continueOnError = false,
  }) {
    return BatchConfig(
      operation: BatchOperation.delete,
      files: files,
      requireConfirmation: requireConfirmation,
      createBackup: createBackup,
      continueOnError: continueOnError,
    );
  }

  /// Create config for copy operations
  factory BatchConfig.copy({
    required List<FileMetadata> files,
    required String targetDirectory,
    bool requireConfirmation = false,
    bool continueOnError = false,
    int maxConcurrency = 3,
  }) {
    return BatchConfig(
      operation: BatchOperation.copy,
      files: files,
      targetDirectory: targetDirectory,
      requireConfirmation: requireConfirmation,
      continueOnError: continueOnError,
      maxConcurrency: maxConcurrency,
    );
  }

  /// Create config for format conversion
  factory BatchConfig.convert({
    required List<FileMetadata> files,
    required String targetFormat,
    Map<String, dynamic> conversionOptions = const {},
    String? targetDirectory,
    bool requireConfirmation = false,
    bool continueOnError = false,
    int maxConcurrency = 2,
  }) {
    return BatchConfig(
      operation: BatchOperation.convert,
      files: files,
      targetDirectory: targetDirectory,
      requireConfirmation: requireConfirmation,
      continueOnError: continueOnError,
      maxConcurrency: maxConcurrency,
      options: {
        'targetFormat': targetFormat,
        'conversionOptions': conversionOptions,
      },
    );
  }

  /// Create config for tagging operations
  factory BatchConfig.tag({
    required List<FileMetadata> files,
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    bool requireConfirmation = false,
  }) {
    return BatchConfig(
      operation: BatchOperation.tag,
      files: files,
      requireConfirmation: requireConfirmation,
      options: {'tagsToAdd': tagsToAdd, 'tagsToRemove': tagsToRemove},
    );
  }

  /// Create config for categorization
  factory BatchConfig.categorize({
    required List<FileMetadata> files,
    required String targetCategory,
    bool requireConfirmation = false,
    bool createBackup = false,
  }) {
    return BatchConfig(
      operation: BatchOperation.categorize,
      files: files,
      requireConfirmation: requireConfirmation,
      createBackup: createBackup,
      options: {'targetCategory': targetCategory},
    );
  }

  /// Get the number of files to process
  int get fileCount => files.length;

  /// Get total estimated size of all files
  int get totalSize => files.fold(0, (sum, file) => sum + file.fileSize);

  /// Get human-readable total size
  String get formattedTotalSize {
    final bytes = totalSize;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Check if the operation requires user confirmation
  bool get needsConfirmation => requireConfirmation || operation.isDestructive;

  /// Check if the operation should create backups
  bool get shouldCreateBackup => createBackup || operation.isDestructive;

  /// Get option value with type safety
  T? getOption<T>(String key, [T? defaultValue]) {
    final value = options[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Create a copy with modified properties
  BatchConfig copyWith({
    BatchOperation? operation,
    List<FileMetadata>? files,
    Map<String, dynamic>? options,
    bool? requireConfirmation,
    bool? createBackup,
    String? targetDirectory,
    bool? continueOnError,
    int? maxConcurrency,
  }) {
    return BatchConfig(
      operation: operation ?? this.operation,
      files: files ?? this.files,
      options: options ?? this.options,
      requireConfirmation: requireConfirmation ?? this.requireConfirmation,
      createBackup: createBackup ?? this.createBackup,
      targetDirectory: targetDirectory ?? this.targetDirectory,
      continueOnError: continueOnError ?? this.continueOnError,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
    );
  }

  /// Validate configuration
  List<String> validate() {
    final errors = <String>[];

    if (files.isEmpty) {
      errors.add('No files specified for batch operation');
    }

    if (maxConcurrency < 1) {
      errors.add('Max concurrency must be at least 1');
    }

    // Operation-specific validations
    switch (operation) {
      case BatchOperation.move:
      case BatchOperation.copy:
        if (targetDirectory == null || targetDirectory!.isEmpty) {
          errors.add(
            'Target directory is required for ${operation.displayName}',
          );
        }
        break;
      case BatchOperation.rename:
        final pattern = getOption<String>('pattern');
        if (pattern == null || pattern.isEmpty) {
          errors.add('Pattern is required for rename operation');
        }
        break;
      case BatchOperation.convert:
        final targetFormat = getOption<String>('targetFormat');
        if (targetFormat == null || targetFormat.isEmpty) {
          errors.add('Target format is required for conversion operation');
        }
        break;
      case BatchOperation.categorize:
        final targetCategory = getOption<String>('targetCategory');
        if (targetCategory == null || targetCategory.isEmpty) {
          errors.add(
            'Target category is required for categorization operation',
          );
        }
        break;
      default:
        break;
    }

    return errors;
  }

  @override
  String toString() {
    return 'BatchConfig(operation: ${operation.displayName}, '
        'files: ${files.length}, '
        'options: $options)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatchConfig &&
        other.operation == operation &&
        other.files.length == files.length &&
        other.requireConfirmation == requireConfirmation &&
        other.createBackup == createBackup &&
        other.targetDirectory == targetDirectory &&
        other.continueOnError == continueOnError &&
        other.maxConcurrency == maxConcurrency;
  }

  @override
  int get hashCode {
    return operation.hashCode ^
        files.length.hashCode ^
        requireConfirmation.hashCode ^
        createBackup.hashCode ^
        targetDirectory.hashCode ^
        continueOnError.hashCode ^
        maxConcurrency.hashCode;
  }
}
