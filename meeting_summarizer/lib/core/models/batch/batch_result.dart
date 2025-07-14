import '../../enums/batch_operation.dart';
import '../storage/file_metadata.dart';

/// Result of a batch processing operation
class BatchResult {
  final BatchOperation operation;
  final bool success;
  final int processedCount;
  final int totalCount;
  final int failedCount;
  final int skippedCount;
  final Duration processingTime;
  final List<FileOperationResult> results;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime endTime;

  const BatchResult({
    required this.operation,
    required this.success,
    required this.processedCount,
    required this.totalCount,
    required this.failedCount,
    required this.skippedCount,
    required this.processingTime,
    required this.results,
    this.errorMessage,
    required this.startTime,
    required this.endTime,
  });

  /// Create a successful batch result
  factory BatchResult.success({
    required BatchOperation operation,
    required int processedCount,
    required int totalCount,
    required Duration processingTime,
    required List<FileOperationResult> results,
    required DateTime startTime,
    required DateTime endTime,
    int skippedCount = 0,
  }) {
    return BatchResult(
      operation: operation,
      success: true,
      processedCount: processedCount,
      totalCount: totalCount,
      failedCount: results.where((r) => !r.success).length,
      skippedCount: skippedCount,
      processingTime: processingTime,
      results: results,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Create a failed batch result
  factory BatchResult.failure({
    required BatchOperation operation,
    required String errorMessage,
    required int totalCount,
    required Duration processingTime,
    required List<FileOperationResult> results,
    required DateTime startTime,
    required DateTime endTime,
    int processedCount = 0,
  }) {
    return BatchResult(
      operation: operation,
      success: false,
      processedCount: processedCount,
      totalCount: totalCount,
      failedCount: results.where((r) => !r.success).length,
      skippedCount:
          totalCount - processedCount - results.where((r) => !r.success).length,
      processingTime: processingTime,
      results: results,
      errorMessage: errorMessage,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Get success rate as percentage
  double get successRate {
    if (totalCount == 0) return 0.0;
    return (processedCount / totalCount) * 100;
  }

  /// Get failure rate as percentage
  double get failureRate {
    if (totalCount == 0) return 0.0;
    return (failedCount / totalCount) * 100;
  }

  /// Get successful results
  List<FileOperationResult> get successfulResults =>
      results.where((r) => r.success).toList();

  /// Get failed results
  List<FileOperationResult> get failedResults =>
      results.where((r) => !r.success).toList();

  /// Get average processing time per file
  Duration get averageTimePerFile {
    if (processedCount == 0) return Duration.zero;
    return Duration(
      microseconds: (processingTime.inMicroseconds / processedCount).round(),
    );
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

  /// Get summary message
  String get summary {
    if (success && failedCount == 0) {
      return 'Successfully processed $processedCount of $totalCount files';
    } else if (success && failedCount > 0) {
      return 'Processed $processedCount files with $failedCount failures';
    } else {
      return 'Operation failed: $errorMessage';
    }
  }

  /// Get detailed report
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('Batch ${operation.displayName} Report');
    buffer.writeln('=' * 40);
    buffer.writeln('Total Files: $totalCount');
    buffer.writeln('Processed: $processedCount');
    buffer.writeln('Failed: $failedCount');
    buffer.writeln('Skipped: $skippedCount');
    buffer.writeln('Success Rate: $formattedSuccessRate');
    buffer.writeln('Processing Time: $formattedProcessingTime');
    buffer.writeln(
      'Average Time per File: ${averageTimePerFile.inMilliseconds}ms',
    );

    if (failedResults.isNotEmpty) {
      buffer.writeln('\nFailures:');
      for (final failure in failedResults) {
        buffer.writeln('  - ${failure.file.fileName}: ${failure.errorMessage}');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'BatchResult(operation: ${operation.displayName}, '
        'success: $success, '
        'processed: $processedCount/$totalCount, '
        'failed: $failedCount, '
        'time: $formattedProcessingTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatchResult &&
        other.operation == operation &&
        other.success == success &&
        other.processedCount == processedCount &&
        other.totalCount == totalCount &&
        other.failedCount == failedCount &&
        other.skippedCount == skippedCount &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return operation.hashCode ^
        success.hashCode ^
        processedCount.hashCode ^
        totalCount.hashCode ^
        failedCount.hashCode ^
        skippedCount.hashCode ^
        startTime.hashCode ^
        endTime.hashCode;
  }
}

/// Result of a single file operation within a batch
class FileOperationResult {
  final FileMetadata file;
  final bool success;
  final String? errorMessage;
  final String? newFilePath;
  final FileMetadata? newMetadata;
  final Duration processingTime;
  final Map<String, dynamic> operationData;

  const FileOperationResult({
    required this.file,
    required this.success,
    this.errorMessage,
    this.newFilePath,
    this.newMetadata,
    required this.processingTime,
    this.operationData = const {},
  });

  /// Create a successful file operation result
  factory FileOperationResult.success({
    required FileMetadata file,
    required Duration processingTime,
    String? newFilePath,
    FileMetadata? newMetadata,
    Map<String, dynamic> operationData = const {},
  }) {
    return FileOperationResult(
      file: file,
      success: true,
      processingTime: processingTime,
      newFilePath: newFilePath,
      newMetadata: newMetadata,
      operationData: operationData,
    );
  }

  /// Create a failed file operation result
  factory FileOperationResult.failure({
    required FileMetadata file,
    required String errorMessage,
    required Duration processingTime,
    Map<String, dynamic> operationData = const {},
  }) {
    return FileOperationResult(
      file: file,
      success: false,
      errorMessage: errorMessage,
      processingTime: processingTime,
      operationData: operationData,
    );
  }

  /// Get operation data value with type safety
  T? getOperationData<T>(String key, [T? defaultValue]) {
    final value = operationData[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Get formatted processing time
  String get formattedProcessingTime {
    if (processingTime.inSeconds > 0) {
      return '${processingTime.inSeconds}s';
    }
    return '${processingTime.inMilliseconds}ms';
  }

  @override
  String toString() {
    return 'FileOperationResult(file: ${file.fileName}, '
        'success: $success, '
        'time: $formattedProcessingTime, '
        'error: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileOperationResult &&
        other.file == file &&
        other.success == success &&
        other.errorMessage == errorMessage &&
        other.newFilePath == newFilePath &&
        other.processingTime == processingTime;
  }

  @override
  int get hashCode {
    return file.hashCode ^
        success.hashCode ^
        errorMessage.hashCode ^
        newFilePath.hashCode ^
        processingTime.hashCode;
  }
}
