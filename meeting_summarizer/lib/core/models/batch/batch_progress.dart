import '../../enums/batch_operation.dart';
import '../storage/file_metadata.dart';

/// Progress tracking for batch operations
class BatchProgress {
  final String batchId;
  final BatchOperation operation;
  final int totalFiles;
  final int processedFiles;
  final int failedFiles;
  final int skippedFiles;
  final FileMetadata? currentFile;
  final String currentOperation;
  final double progressPercentage;
  final Duration elapsedTime;
  final Duration? estimatedTimeRemaining;
  final DateTime startTime;
  final bool isComplete;
  final bool isCancelled;

  const BatchProgress({
    required this.batchId,
    required this.operation,
    required this.totalFiles,
    required this.processedFiles,
    required this.failedFiles,
    required this.skippedFiles,
    this.currentFile,
    required this.currentOperation,
    required this.progressPercentage,
    required this.elapsedTime,
    this.estimatedTimeRemaining,
    required this.startTime,
    required this.isComplete,
    required this.isCancelled,
  });

  /// Create initial progress
  factory BatchProgress.initial({
    required String batchId,
    required BatchOperation operation,
    required int totalFiles,
    required DateTime startTime,
  }) {
    return BatchProgress(
      batchId: batchId,
      operation: operation,
      totalFiles: totalFiles,
      processedFiles: 0,
      failedFiles: 0,
      skippedFiles: 0,
      currentOperation: 'Starting ${operation.displayName}...',
      progressPercentage: 0.0,
      elapsedTime: Duration.zero,
      startTime: startTime,
      isComplete: false,
      isCancelled: false,
    );
  }

  /// Create progress update
  factory BatchProgress.update({
    required String batchId,
    required BatchOperation operation,
    required int totalFiles,
    required int processedFiles,
    required int failedFiles,
    required int skippedFiles,
    FileMetadata? currentFile,
    required String currentOperation,
    required DateTime startTime,
    required Duration elapsedTime,
    Duration? estimatedTimeRemaining,
  }) {
    final percentage =
        totalFiles > 0 ? (processedFiles / totalFiles) * 100 : 0.0;

    return BatchProgress(
      batchId: batchId,
      operation: operation,
      totalFiles: totalFiles,
      processedFiles: processedFiles,
      failedFiles: failedFiles,
      skippedFiles: skippedFiles,
      currentFile: currentFile,
      currentOperation: currentOperation,
      progressPercentage: percentage,
      elapsedTime: elapsedTime,
      estimatedTimeRemaining: estimatedTimeRemaining,
      startTime: startTime,
      isComplete: false,
      isCancelled: false,
    );
  }

  /// Create completed progress
  factory BatchProgress.completed({
    required String batchId,
    required BatchOperation operation,
    required int totalFiles,
    required int processedFiles,
    required int failedFiles,
    required int skippedFiles,
    required DateTime startTime,
    required Duration elapsedTime,
  }) {
    return BatchProgress(
      batchId: batchId,
      operation: operation,
      totalFiles: totalFiles,
      processedFiles: processedFiles,
      failedFiles: failedFiles,
      skippedFiles: skippedFiles,
      currentOperation: 'Completed ${operation.displayName}',
      progressPercentage: 100.0,
      elapsedTime: elapsedTime,
      startTime: startTime,
      isComplete: true,
      isCancelled: false,
    );
  }

  /// Create cancelled progress
  factory BatchProgress.cancelled({
    required String batchId,
    required BatchOperation operation,
    required int totalFiles,
    required int processedFiles,
    required int failedFiles,
    required int skippedFiles,
    required DateTime startTime,
    required Duration elapsedTime,
  }) {
    final percentage =
        totalFiles > 0 ? (processedFiles / totalFiles) * 100 : 0.0;

    return BatchProgress(
      batchId: batchId,
      operation: operation,
      totalFiles: totalFiles,
      processedFiles: processedFiles,
      failedFiles: failedFiles,
      skippedFiles: skippedFiles,
      currentOperation: 'Cancelled ${operation.displayName}',
      progressPercentage: percentage,
      elapsedTime: elapsedTime,
      startTime: startTime,
      isComplete: false,
      isCancelled: true,
    );
  }

  /// Get remaining files to process
  int get remainingFiles =>
      totalFiles - processedFiles - failedFiles - skippedFiles;

  /// Get success rate percentage
  double get successRate {
    if (processedFiles == 0) return 0.0;
    return ((processedFiles - failedFiles) / processedFiles) * 100;
  }

  /// Get processing rate (files per second)
  double get processingRate {
    if (elapsedTime.inSeconds == 0) return 0.0;
    return processedFiles / elapsedTime.inSeconds;
  }

  /// Get formatted progress percentage
  String get formattedProgress => '${progressPercentage.toStringAsFixed(1)}%';

  /// Get formatted elapsed time
  String get formattedElapsedTime {
    if (elapsedTime.inHours > 0) {
      return '${elapsedTime.inHours}h ${elapsedTime.inMinutes % 60}m ${elapsedTime.inSeconds % 60}s';
    } else if (elapsedTime.inMinutes > 0) {
      return '${elapsedTime.inMinutes}m ${elapsedTime.inSeconds % 60}s';
    } else {
      return '${elapsedTime.inSeconds}s';
    }
  }

  /// Get formatted estimated time remaining
  String get formattedEstimatedTimeRemaining {
    if (estimatedTimeRemaining == null) return 'Unknown';

    final remaining = estimatedTimeRemaining!;
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    } else {
      return '${remaining.inSeconds}s';
    }
  }

  /// Get formatted success rate
  String get formattedSuccessRate => '${successRate.toStringAsFixed(1)}%';

  /// Get formatted processing rate
  String get formattedProcessingRate =>
      '${processingRate.toStringAsFixed(1)} files/sec';

  /// Get status message
  String get statusMessage {
    if (isCancelled) {
      return 'Cancelled after processing $processedFiles of $totalFiles files';
    } else if (isComplete) {
      return 'Completed processing $processedFiles of $totalFiles files';
    } else {
      return 'Processing $processedFiles of $totalFiles files';
    }
  }

  /// Get detailed status with current file
  String get detailedStatus {
    final buffer = StringBuffer();
    buffer.write(statusMessage);

    if (currentFile != null && !isComplete && !isCancelled) {
      buffer.write(' (Current: ${currentFile!.fileName})');
    }

    if (failedFiles > 0) {
      buffer.write(' - $failedFiles failed');
    }

    if (skippedFiles > 0) {
      buffer.write(' - $skippedFiles skipped');
    }

    return buffer.toString();
  }

  /// Calculate estimated time remaining based on current progress
  Duration calculateEstimatedTimeRemaining() {
    if (processedFiles == 0 || remainingFiles == 0) {
      return Duration.zero;
    }

    final timePerFile = elapsedTime.inMicroseconds / processedFiles;
    final remainingMicroseconds = (remainingFiles * timePerFile).round();

    return Duration(microseconds: remainingMicroseconds);
  }

  /// Create a copy with updated progress
  BatchProgress copyWith({
    String? batchId,
    BatchOperation? operation,
    int? totalFiles,
    int? processedFiles,
    int? failedFiles,
    int? skippedFiles,
    FileMetadata? currentFile,
    String? currentOperation,
    double? progressPercentage,
    Duration? elapsedTime,
    Duration? estimatedTimeRemaining,
    DateTime? startTime,
    bool? isComplete,
    bool? isCancelled,
  }) {
    return BatchProgress(
      batchId: batchId ?? this.batchId,
      operation: operation ?? this.operation,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      skippedFiles: skippedFiles ?? this.skippedFiles,
      currentFile: currentFile ?? this.currentFile,
      currentOperation: currentOperation ?? this.currentOperation,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      startTime: startTime ?? this.startTime,
      isComplete: isComplete ?? this.isComplete,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  @override
  String toString() {
    return 'BatchProgress(id: $batchId, '
        'operation: ${operation.displayName}, '
        'progress: $formattedProgress, '
        'processed: $processedFiles/$totalFiles, '
        'failed: $failedFiles, '
        'time: $formattedElapsedTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatchProgress &&
        other.batchId == batchId &&
        other.operation == operation &&
        other.totalFiles == totalFiles &&
        other.processedFiles == processedFiles &&
        other.failedFiles == failedFiles &&
        other.skippedFiles == skippedFiles &&
        other.isComplete == isComplete &&
        other.isCancelled == isCancelled;
  }

  @override
  int get hashCode {
    return batchId.hashCode ^
        operation.hashCode ^
        totalFiles.hashCode ^
        processedFiles.hashCode ^
        failedFiles.hashCode ^
        skippedFiles.hashCode ^
        isComplete.hashCode ^
        isCancelled.hashCode;
  }
}
