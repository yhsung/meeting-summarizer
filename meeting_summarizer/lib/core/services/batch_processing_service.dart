import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../interfaces/batch_processing_interface.dart';
import '../models/batch/batch_config.dart';
import '../models/batch/batch_result.dart';
import '../models/batch/batch_progress.dart';
import '../models/storage/file_metadata.dart';
import '../models/storage/file_category.dart';
import '../enums/batch_operation.dart';

/// Implementation of batch file processing service
class BatchProcessingService implements BatchProcessingInterface {
  final Map<String, StreamController<BatchProgress>> _progressControllers = {};
  final Map<String, Completer<void>> _cancellationTokens = {};
  final List<BatchHistoryEntry> _history = [];
  final _uuid = const Uuid();

  /// Statistics tracking
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;
  int _totalFilesProcessed = 0;
  Duration _totalProcessingTime = Duration.zero;
  DateTime? _lastOperationTime;
  final Map<BatchOperation, int> _operationCounts = {};
  final Map<BatchOperation, Duration> _averageProcessingTimes = {};

  @override
  Future<BatchResult> executeBatch(BatchConfig config) async {
    // Validate configuration
    final validationErrors = await validateBatchConfig(config);
    if (validationErrors.isNotEmpty) {
      throw ArgumentError(
        'Invalid batch configuration: ${validationErrors.join(', ')}',
      );
    }

    final batchId = _uuid.v4();
    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();

    // Create progress controller
    final progressController = StreamController<BatchProgress>.broadcast();
    _progressControllers[batchId] = progressController;

    // Create cancellation token
    final cancellationToken = Completer<void>();
    _cancellationTokens[batchId] = cancellationToken;

    // Initialize progress
    var progress = BatchProgress.initial(
      batchId: batchId,
      operation: config.operation,
      totalFiles: config.fileCount,
      startTime: startTime,
    );
    progressController.add(progress);

    final results = <FileOperationResult>[];
    int processedCount = 0;
    int failedCount = 0;
    int skippedCount = 0;

    try {
      // Process files with concurrency control
      final semaphore = Semaphore(config.maxConcurrency);
      final futures = <Future<void>>[];

      for (int i = 0; i < config.files.length; i++) {
        final file = config.files[i];

        futures.add(
          semaphore.acquire().then((_) async {
            try {
              // Check for cancellation
              if (cancellationToken.isCompleted) {
                skippedCount++;
                return;
              }

              // Update progress
              final currentProgress = BatchProgress.update(
                batchId: batchId,
                operation: config.operation,
                totalFiles: config.fileCount,
                processedFiles: processedCount,
                failedFiles: failedCount,
                skippedFiles: skippedCount,
                currentFile: file,
                currentOperation: 'Processing ${file.fileName}',
                startTime: startTime,
                elapsedTime: stopwatch.elapsed,
                estimatedTimeRemaining: _calculateEstimatedTime(
                  processedCount,
                  config.fileCount,
                  stopwatch.elapsed,
                ),
              );
              progressController.add(currentProgress);

              // Process individual file
              final result = await _processFile(file, config);
              results.add(result);

              if (result.success) {
                processedCount++;
              } else {
                failedCount++;
                if (!config.continueOnError) {
                  cancellationToken.complete();
                }
              }
            } catch (e) {
              failedCount++;
              results.add(
                FileOperationResult.failure(
                  file: file,
                  errorMessage: e.toString(),
                  processingTime: Duration.zero,
                ),
              );

              if (!config.continueOnError) {
                cancellationToken.complete();
              }
            } finally {
              semaphore.release();
            }
          }),
        );
      }

      // Wait for all operations to complete
      await Future.wait(futures);

      stopwatch.stop();
      final endTime = DateTime.now();

      // Create final progress
      final finalProgress = BatchProgress.completed(
        batchId: batchId,
        operation: config.operation,
        totalFiles: config.fileCount,
        processedFiles: processedCount,
        failedFiles: failedCount,
        skippedFiles: skippedCount,
        startTime: startTime,
        elapsedTime: stopwatch.elapsed,
      );
      progressController.add(finalProgress);

      // Create result
      final result = failedCount == 0
          ? BatchResult.success(
              operation: config.operation,
              processedCount: processedCount,
              totalCount: config.fileCount,
              processingTime: stopwatch.elapsed,
              results: results,
              startTime: startTime,
              endTime: endTime,
              skippedCount: skippedCount,
            )
          : BatchResult.failure(
              operation: config.operation,
              errorMessage: 'Some files failed to process',
              totalCount: config.fileCount,
              processingTime: stopwatch.elapsed,
              results: results,
              startTime: startTime,
              endTime: endTime,
              processedCount: processedCount,
            );

      // Update statistics
      _updateStatistics(config.operation, result);

      // Add to history
      _addToHistory(batchId, config.operation, result);

      return result;
    } catch (e) {
      stopwatch.stop();
      final endTime = DateTime.now();

      // Create failure result
      final result = BatchResult.failure(
        operation: config.operation,
        errorMessage: e.toString(),
        totalCount: config.fileCount,
        processingTime: stopwatch.elapsed,
        results: results,
        startTime: startTime,
        endTime: endTime,
        processedCount: processedCount,
      );

      // Update statistics
      _updateStatistics(config.operation, result);

      // Add to history
      _addToHistory(batchId, config.operation, result);

      return result;
    } finally {
      // Clean up
      progressController.close();
      _progressControllers.remove(batchId);
      _cancellationTokens.remove(batchId);
    }
  }

  @override
  Stream<BatchProgress> getBatchProgress(String batchId) {
    final controller = _progressControllers[batchId];
    if (controller == null) {
      throw ArgumentError('Batch with ID $batchId not found');
    }
    return controller.stream;
  }

  @override
  Future<bool> cancelBatch(String batchId) async {
    final cancellationToken = _cancellationTokens[batchId];
    if (cancellationToken == null) {
      return false;
    }

    cancellationToken.complete();
    return true;
  }

  @override
  bool isBatchRunning(String batchId) {
    return _progressControllers.containsKey(batchId);
  }

  @override
  List<String> getRunningBatches() {
    return _progressControllers.keys.toList();
  }

  @override
  List<BatchOperation> getSupportedOperations() {
    return BatchOperation.values;
  }

  @override
  Future<List<String>> validateBatchConfig(BatchConfig config) async {
    final errors = <String>[];

    // Use the config's built-in validation
    errors.addAll(config.validate());

    // Additional runtime validations
    for (final file in config.files) {
      if (!await File(file.filePath).exists()) {
        errors.add('File not found: ${file.fileName}');
      }
    }

    // Operation-specific validations
    switch (config.operation) {
      case BatchOperation.move:
      case BatchOperation.copy:
        final targetDir = config.targetDirectory;
        if (targetDir != null && !await Directory(targetDir).exists()) {
          errors.add('Target directory does not exist: $targetDir');
        }
        break;
      case BatchOperation.convert:
        final targetFormat = config.getOption<String>('targetFormat');
        if (targetFormat != null && !_isSupportedFormat(targetFormat)) {
          errors.add('Unsupported target format: $targetFormat');
        }
        break;
      default:
        break;
    }

    return errors;
  }

  @override
  Future<List<FileOperationPreview>> previewBatch(BatchConfig config) async {
    final previews = <FileOperationPreview>[];

    for (final file in config.files) {
      final preview = await _previewFileOperation(file, config);
      previews.add(preview);
    }

    return previews;
  }

  @override
  Future<List<BatchHistoryEntry>> getBatchHistory({
    int? limit,
    BatchOperation? operation,
    DateTime? since,
  }) async {
    var filtered = _history.where((entry) {
      if (operation != null && entry.operation != operation) return false;
      if (since != null && entry.startTime.isBefore(since)) return false;
      return true;
    }).toList();

    // Sort by start time descending
    filtered.sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit != null && limit > 0) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  @override
  Future<void> clearBatchHistory() async {
    _history.clear();
  }

  @override
  Future<Duration> estimateBatchDuration(BatchConfig config) async {
    final operation = config.operation;
    final averageTime = _averageProcessingTimes[operation];

    if (averageTime == null) {
      // Default estimates based on operation type
      final baseTimePerFile = _getBaseTimeEstimate(operation);
      return Duration(
        microseconds: (baseTimePerFile.inMicroseconds * config.fileCount)
            .round(),
      );
    }

    return Duration(
      microseconds: (averageTime.inMicroseconds * config.fileCount).round(),
    );
  }

  @override
  Future<BatchStatistics> getBatchStatistics() async {
    return BatchStatistics(
      totalOperations: _totalOperations,
      successfulOperations: _successfulOperations,
      failedOperations: _failedOperations,
      totalFilesProcessed: _totalFilesProcessed,
      totalProcessingTime: _totalProcessingTime,
      lastOperationTime: _lastOperationTime,
      operationCounts: Map.from(_operationCounts),
      averageProcessingTimes: Map.from(_averageProcessingTimes),
    );
  }

  // Private helper methods

  Future<FileOperationResult> _processFile(
    FileMetadata file,
    BatchConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      switch (config.operation) {
        case BatchOperation.rename:
          return await _processRename(file, config, stopwatch);
        case BatchOperation.move:
          return await _processMove(file, config, stopwatch);
        case BatchOperation.delete:
          return await _processDelete(file, config, stopwatch);
        case BatchOperation.copy:
          return await _processCopy(file, config, stopwatch);
        case BatchOperation.convert:
          return await _processConvert(file, config, stopwatch);
        case BatchOperation.tag:
          return await _processTag(file, config, stopwatch);
        case BatchOperation.categorize:
          return await _processCategorize(file, config, stopwatch);
        default:
          throw UnimplementedError(
            'Operation ${config.operation} not implemented',
          );
      }
    } catch (e) {
      stopwatch.stop();
      return FileOperationResult.failure(
        file: file,
        errorMessage: e.toString(),
        processingTime: stopwatch.elapsed,
      );
    }
  }

  Future<FileOperationResult> _processRename(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final pattern = config.getOption<String>('pattern')!;
    final replacement = config.getOption<String>('replacement') ?? '';
    final addIndex = config.getOption<bool>('addIndex') ?? false;
    final preserveExtension =
        config.getOption<bool>('preserveExtension') ?? true;

    // Generate new filename
    String newName = file.baseName;

    // Apply pattern replacement
    if (pattern.isNotEmpty) {
      newName = newName.replaceAll(RegExp(pattern), replacement);
    }

    // Add index if requested
    if (addIndex) {
      final index = config.files.indexOf(file) + 1;
      newName = '${newName}_$index';
    }

    // Preserve extension if requested
    if (preserveExtension) {
      newName = '$newName${file.extension}';
    }

    final newPath = path.join(file.directory, newName);
    final originalFile = File(file.filePath);
    final newFile = File(newPath);

    // Check if target already exists
    if (await newFile.exists()) {
      throw Exception('Target file already exists: $newName');
    }

    // Perform rename
    await originalFile.rename(newPath);

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      newFilePath: newPath,
      newMetadata: file.copyWith(fileName: newName, filePath: newPath),
    );
  }

  Future<FileOperationResult> _processMove(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final targetDir = config.targetDirectory!;
    final newPath = path.join(targetDir, file.fileName);

    final originalFile = File(file.filePath);
    final newFile = File(newPath);

    // Ensure target directory exists
    await Directory(targetDir).create(recursive: true);

    // Check if target already exists
    if (await newFile.exists()) {
      throw Exception('Target file already exists: $newPath');
    }

    // Perform move
    await originalFile.rename(newPath);

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      newFilePath: newPath,
      newMetadata: file.copyWith(
        filePath: newPath,
        relativePath: path.relative(newPath, from: targetDir),
      ),
    );
  }

  Future<FileOperationResult> _processDelete(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final fileToDelete = File(file.filePath);

    // Create backup if requested
    if (config.shouldCreateBackup) {
      final backupPath = '${file.filePath}.backup';
      await fileToDelete.copy(backupPath);
    }

    // Perform delete
    await fileToDelete.delete();

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      operationData: {
        'deleted': true,
        'backupCreated': config.shouldCreateBackup,
      },
    );
  }

  Future<FileOperationResult> _processCopy(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final targetDir = config.targetDirectory!;
    final newPath = path.join(targetDir, file.fileName);

    final originalFile = File(file.filePath);
    final newFile = File(newPath);

    // Ensure target directory exists
    await Directory(targetDir).create(recursive: true);

    // Check if target already exists
    if (await newFile.exists()) {
      throw Exception('Target file already exists: $newPath');
    }

    // Perform copy
    await originalFile.copy(newPath);

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      newFilePath: newPath,
      newMetadata: file.copyWith(
        id: _uuid.v4(), // New ID for the copy
        filePath: newPath,
        relativePath: path.relative(newPath, from: targetDir),
      ),
    );
  }

  Future<FileOperationResult> _processConvert(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    // This is a placeholder implementation
    // In a real implementation, you would integrate with format conversion libraries
    throw UnimplementedError('Format conversion not yet implemented');
  }

  Future<FileOperationResult> _processTag(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final tagsToAdd = config.getOption<List<String>>('tagsToAdd') ?? <String>[];
    final tagsToRemove =
        config.getOption<List<String>>('tagsToRemove') ?? <String>[];

    final currentTags = file.tags.toSet();
    currentTags.addAll(tagsToAdd);
    currentTags.removeAll(tagsToRemove);

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      newMetadata: file.copyWith(tags: currentTags.toList()),
      operationData: {'tagsAdded': tagsToAdd, 'tagsRemoved': tagsToRemove},
    );
  }

  Future<FileOperationResult> _processCategorize(
    FileMetadata file,
    BatchConfig config,
    Stopwatch stopwatch,
  ) async {
    final targetCategory = config.getOption<String>('targetCategory')!;
    final newCategory = FileCategory.fromString(targetCategory);

    stopwatch.stop();
    return FileOperationResult.success(
      file: file,
      processingTime: stopwatch.elapsed,
      newMetadata: file.copyWith(category: newCategory),
      operationData: {
        'oldCategory': file.category.name,
        'newCategory': newCategory.name,
      },
    );
  }

  Future<FileOperationPreview> _previewFileOperation(
    FileMetadata file,
    BatchConfig config,
  ) async {
    switch (config.operation) {
      case BatchOperation.rename:
        return _previewRename(file, config);
      case BatchOperation.move:
        return _previewMove(file, config);
      case BatchOperation.copy:
        return _previewCopy(file, config);
      case BatchOperation.delete:
        return _previewDelete(file, config);
      case BatchOperation.tag:
        return _previewTag(file, config);
      case BatchOperation.categorize:
        return _previewCategorize(file, config);
      default:
        return FileOperationPreview(
          file: file,
          operation: config.operation.displayName,
          requiresConfirmation: config.needsConfirmation,
        );
    }
  }

  FileOperationPreview _previewRename(FileMetadata file, BatchConfig config) {
    final pattern = config.getOption<String>('pattern')!;
    final replacement = config.getOption<String>('replacement') ?? '';
    final addIndex = config.getOption<bool>('addIndex') ?? false;
    final preserveExtension =
        config.getOption<bool>('preserveExtension') ?? true;

    String newName = file.baseName;

    if (pattern.isNotEmpty) {
      newName = newName.replaceAll(RegExp(pattern), replacement);
    }

    if (addIndex) {
      final index = config.files.indexOf(file) + 1;
      newName = '${newName}_$index';
    }

    if (preserveExtension) {
      newName = '$newName${file.extension}';
    }

    return FileOperationPreview(
      file: file,
      operation: 'Rename',
      newFileName: newName,
      requiresConfirmation: config.needsConfirmation,
    );
  }

  FileOperationPreview _previewMove(FileMetadata file, BatchConfig config) {
    final targetDir = config.targetDirectory!;
    final newPath = path.join(targetDir, file.fileName);

    return FileOperationPreview(
      file: file,
      operation: 'Move',
      newPath: newPath,
      requiresConfirmation: config.needsConfirmation,
    );
  }

  FileOperationPreview _previewCopy(FileMetadata file, BatchConfig config) {
    final targetDir = config.targetDirectory!;
    final newPath = path.join(targetDir, file.fileName);

    return FileOperationPreview(
      file: file,
      operation: 'Copy',
      newPath: newPath,
      requiresConfirmation: config.needsConfirmation,
    );
  }

  FileOperationPreview _previewDelete(FileMetadata file, BatchConfig config) {
    final warnings = <String>[];
    if (config.shouldCreateBackup) {
      warnings.add('Backup will be created before deletion');
    } else {
      warnings.add('File will be permanently deleted');
    }

    return FileOperationPreview(
      file: file,
      operation: 'Delete',
      requiresConfirmation: true,
      warnings: warnings,
    );
  }

  FileOperationPreview _previewTag(FileMetadata file, BatchConfig config) {
    final tagsToAdd = config.getOption<List<String>>('tagsToAdd') ?? <String>[];
    final tagsToRemove =
        config.getOption<List<String>>('tagsToRemove') ?? <String>[];

    final currentTags = file.tags.toSet();
    currentTags.addAll(tagsToAdd);
    currentTags.removeAll(tagsToRemove);

    return FileOperationPreview(
      file: file,
      operation: 'Tag',
      newTags: currentTags.toList(),
      requiresConfirmation: config.needsConfirmation,
    );
  }

  FileOperationPreview _previewCategorize(
    FileMetadata file,
    BatchConfig config,
  ) {
    final targetCategory = config.getOption<String>('targetCategory')!;

    return FileOperationPreview(
      file: file,
      operation: 'Categorize',
      newCategory: targetCategory,
      requiresConfirmation: config.needsConfirmation,
    );
  }

  void _updateStatistics(BatchOperation operation, BatchResult result) {
    _totalOperations++;
    _totalFilesProcessed += result.processedCount;
    _totalProcessingTime += result.processingTime;
    _lastOperationTime = result.endTime;

    if (result.success) {
      _successfulOperations++;
    } else {
      _failedOperations++;
    }

    // Update operation counts
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    // Update average processing times
    final currentAverage = _averageProcessingTimes[operation] ?? Duration.zero;
    final currentCount = _operationCounts[operation]!;

    final newAverage = Duration(
      microseconds:
          ((currentAverage.inMicroseconds * (currentCount - 1)) +
              result.processingTime.inMicroseconds) ~/
          currentCount,
    );

    _averageProcessingTimes[operation] = newAverage;
  }

  void _addToHistory(
    String batchId,
    BatchOperation operation,
    BatchResult result,
  ) {
    final entry = BatchHistoryEntry(
      batchId: batchId,
      operation: operation,
      startTime: result.startTime,
      endTime: result.endTime,
      totalFiles: result.totalCount,
      processedFiles: result.processedCount,
      failedFiles: result.failedCount,
      success: result.success,
      processingTime: result.processingTime,
      errorMessage: result.errorMessage,
    );

    _history.add(entry);

    // Keep only last 100 entries
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  Duration? _calculateEstimatedTime(
    int processed,
    int total,
    Duration elapsed,
  ) {
    if (processed == 0) return null;

    final timePerFile = elapsed.inMicroseconds / processed;
    final remaining = total - processed;

    return Duration(microseconds: (timePerFile * remaining).round());
  }

  Duration _getBaseTimeEstimate(BatchOperation operation) {
    switch (operation) {
      case BatchOperation.rename:
        return const Duration(milliseconds: 100);
      case BatchOperation.move:
      case BatchOperation.copy:
        return const Duration(milliseconds: 500);
      case BatchOperation.delete:
        return const Duration(milliseconds: 50);
      case BatchOperation.convert:
        return const Duration(seconds: 5);
      case BatchOperation.tag:
      case BatchOperation.categorize:
        return const Duration(milliseconds: 10);
      default:
        return const Duration(milliseconds: 200);
    }
  }

  bool _isSupportedFormat(String format) {
    // This would be expanded based on supported conversion formats
    const supportedFormats = ['wav', 'mp3', 'aac', 'flac', 'ogg'];
    return supportedFormats.contains(format.toLowerCase());
  }
}

/// Semaphore implementation for controlling concurrency
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
