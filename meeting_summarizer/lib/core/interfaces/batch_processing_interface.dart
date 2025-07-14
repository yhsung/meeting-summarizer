import 'dart:async';
import '../models/batch/batch_config.dart';
import '../models/batch/batch_result.dart';
import '../models/batch/batch_progress.dart';
import '../models/storage/file_metadata.dart';
import '../enums/batch_operation.dart';

/// Abstract interface for batch file processing operations
abstract class BatchProcessingInterface {
  /// Execute a batch operation with the given configuration
  Future<BatchResult> executeBatch(BatchConfig config);

  /// Get progress stream for a batch operation
  Stream<BatchProgress> getBatchProgress(String batchId);

  /// Cancel a running batch operation
  Future<bool> cancelBatch(String batchId);

  /// Check if a batch operation is currently running
  bool isBatchRunning(String batchId);

  /// Get list of currently running batch operations
  List<String> getRunningBatches();

  /// Get supported batch operations
  List<BatchOperation> getSupportedOperations();

  /// Validate batch configuration before execution
  Future<List<String>> validateBatchConfig(BatchConfig config);

  /// Preview batch operation results without executing
  Future<List<FileOperationPreview>> previewBatch(BatchConfig config);

  /// Get batch operation history
  Future<List<BatchHistoryEntry>> getBatchHistory({
    int? limit,
    BatchOperation? operation,
    DateTime? since,
  });

  /// Clear batch operation history
  Future<void> clearBatchHistory();

  /// Estimate batch operation duration
  Future<Duration> estimateBatchDuration(BatchConfig config);

  /// Get batch operation statistics
  Future<BatchStatistics> getBatchStatistics();
}

/// Preview of what will happen to a file during batch operation
class FileOperationPreview {
  final FileMetadata file;
  final String operation;
  final String? newFileName;
  final String? newPath;
  final String? newCategory;
  final List<String>? newTags;
  final bool requiresConfirmation;
  final List<String> warnings;

  const FileOperationPreview({
    required this.file,
    required this.operation,
    this.newFileName,
    this.newPath,
    this.newCategory,
    this.newTags,
    required this.requiresConfirmation,
    this.warnings = const [],
  });

  /// Check if the operation will change the file
  bool get willChangeFile =>
      newFileName != null ||
      newPath != null ||
      newCategory != null ||
      newTags != null;

  /// Get summary of changes
  String get changeSummary {
    final changes = <String>[];

    if (newFileName != null && newFileName != file.fileName) {
      changes.add('Name: ${file.fileName} → $newFileName');
    }

    if (newPath != null && newPath != file.filePath) {
      changes.add('Path: ${file.filePath} → $newPath');
    }

    if (newCategory != null && newCategory != file.category.name) {
      changes.add('Category: ${file.category.displayName} → $newCategory');
    }

    if (newTags != null) {
      final currentTags = file.tags.toSet();
      final newTagsSet = newTags!.toSet();

      final added = newTagsSet.difference(currentTags);
      final removed = currentTags.difference(newTagsSet);

      if (added.isNotEmpty) {
        changes.add('Tags added: ${added.join(', ')}');
      }

      if (removed.isNotEmpty) {
        changes.add('Tags removed: ${removed.join(', ')}');
      }
    }

    return changes.isEmpty ? 'No changes' : changes.join('; ');
  }

  @override
  String toString() {
    return 'FileOperationPreview(file: ${file.fileName}, '
        'operation: $operation, '
        'changes: $changeSummary)';
  }
}

/// Batch operation history entry
class BatchHistoryEntry {
  final String batchId;
  final BatchOperation operation;
  final DateTime startTime;
  final DateTime endTime;
  final int totalFiles;
  final int processedFiles;
  final int failedFiles;
  final bool success;
  final Duration processingTime;
  final String? errorMessage;

  const BatchHistoryEntry({
    required this.batchId,
    required this.operation,
    required this.startTime,
    required this.endTime,
    required this.totalFiles,
    required this.processedFiles,
    required this.failedFiles,
    required this.success,
    required this.processingTime,
    this.errorMessage,
  });

  /// Get success rate percentage
  double get successRate {
    if (processedFiles == 0) return 0.0;
    return ((processedFiles - failedFiles) / processedFiles) * 100;
  }

  /// Get formatted success rate
  String get formattedSuccessRate => '${successRate.toStringAsFixed(1)}%';

  /// Get formatted processing time
  String get formattedProcessingTime {
    if (processingTime.inMinutes > 0) {
      return '${processingTime.inMinutes}m ${processingTime.inSeconds % 60}s';
    }
    return '${processingTime.inSeconds}s';
  }

  @override
  String toString() {
    return 'BatchHistoryEntry(operation: ${operation.displayName}, '
        'files: $processedFiles/$totalFiles, '
        'success: $success, '
        'time: $formattedProcessingTime)';
  }
}

/// Batch operation statistics
class BatchStatistics {
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final int totalFilesProcessed;
  final Duration totalProcessingTime;
  final DateTime? lastOperationTime;
  final Map<BatchOperation, int> operationCounts;
  final Map<BatchOperation, Duration> averageProcessingTimes;

  const BatchStatistics({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.totalFilesProcessed,
    required this.totalProcessingTime,
    this.lastOperationTime,
    this.operationCounts = const {},
    this.averageProcessingTimes = const {},
  });

  /// Get success rate percentage
  double get successRate {
    if (totalOperations == 0) return 0.0;
    return (successfulOperations / totalOperations) * 100;
  }

  /// Get average files per operation
  double get averageFilesPerOperation {
    if (totalOperations == 0) return 0.0;
    return totalFilesProcessed / totalOperations;
  }

  /// Get most used operation
  BatchOperation? get mostUsedOperation {
    if (operationCounts.isEmpty) return null;

    return operationCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get fastest operation (by average time)
  BatchOperation? get fastestOperation {
    if (averageProcessingTimes.isEmpty) return null;

    return averageProcessingTimes.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  /// Get formatted success rate
  String get formattedSuccessRate => '${successRate.toStringAsFixed(1)}%';

  /// Get formatted total processing time
  String get formattedTotalProcessingTime {
    if (totalProcessingTime.inHours > 0) {
      return '${totalProcessingTime.inHours}h ${totalProcessingTime.inMinutes % 60}m';
    } else if (totalProcessingTime.inMinutes > 0) {
      return '${totalProcessingTime.inMinutes}m ${totalProcessingTime.inSeconds % 60}s';
    } else {
      return '${totalProcessingTime.inSeconds}s';
    }
  }

  @override
  String toString() {
    return 'BatchStatistics(operations: $totalOperations, '
        'success: $formattedSuccessRate, '
        'files: $totalFilesProcessed, '
        'time: $formattedTotalProcessingTime)';
  }
}
