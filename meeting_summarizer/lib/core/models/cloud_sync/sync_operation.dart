import 'cloud_provider.dart';

/// Represents a single synchronization operation
class SyncOperation {
  final String id;
  final SyncOperationType type;
  final String localFilePath;
  final String remoteFilePath;
  final CloudProvider provider;
  final SyncOperationStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double progressPercentage;
  final int bytesTransferred;
  final int totalBytes;
  final String? error;
  final int retryCount;
  final int maxRetries;
  final Duration? estimatedTimeRemaining;
  final Map<String, dynamic> metadata;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.localFilePath,
    required this.remoteFilePath,
    required this.provider,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.progressPercentage = 0.0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.error,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.estimatedTimeRemaining,
    this.metadata = const {},
  });

  /// Check if operation is currently running
  bool get isActive => status == SyncOperationStatus.running;

  /// Check if operation completed successfully
  bool get isCompleted => status == SyncOperationStatus.completed;

  /// Check if operation failed
  bool get isFailed => status == SyncOperationStatus.failed;

  /// Check if operation can be retried
  bool get canRetry => isFailed && retryCount < maxRetries;

  /// Get operation duration
  Duration? get duration {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Get transfer speed in bytes per second
  double? get transferSpeed {
    final operationDuration = duration;
    if (operationDuration == null || operationDuration.inMilliseconds == 0) {
      return null;
    }
    return bytesTransferred / (operationDuration.inMilliseconds / 1000);
  }

  /// Get formatted transfer speed
  String? get formattedTransferSpeed {
    final speed = transferSpeed;
    if (speed == null) return null;

    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Get formatted bytes transferred
  String get formattedBytesTransferred => _formatBytes(bytesTransferred);

  /// Get formatted total bytes
  String get formattedTotalBytes => _formatBytes(totalBytes);

  /// Get operation summary
  String get summary {
    final fileName = localFilePath.split('/').last;
    switch (type) {
      case SyncOperationType.upload:
        return 'Uploading $fileName to ${provider.displayName}';
      case SyncOperationType.download:
        return 'Downloading $fileName from ${provider.displayName}';
      case SyncOperationType.delete:
        return 'Deleting $fileName from ${provider.displayName}';
      case SyncOperationType.metadata:
        return 'Updating metadata for $fileName';
    }
  }

  /// Create a copy with updated values
  SyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    String? localFilePath,
    String? remoteFilePath,
    CloudProvider? provider,
    SyncOperationStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? progressPercentage,
    int? bytesTransferred,
    int? totalBytes,
    String? error,
    int? retryCount,
    int? maxRetries,
    Duration? estimatedTimeRemaining,
    Map<String, dynamic>? metadata,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteFilePath: remoteFilePath ?? this.remoteFilePath,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'localFilePath': localFilePath,
      'remoteFilePath': remoteFilePath,
      'provider': provider.id,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'progressPercentage': progressPercentage,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'error': error,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'estimatedTimeRemaining': estimatedTimeRemaining?.inMilliseconds,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values.firstWhere(
        (type) => type.name == json['type'],
      ),
      localFilePath: json['localFilePath'] as String,
      remoteFilePath: json['remoteFilePath'] as String,
      provider: CloudProvider.fromId(json['provider'] as String)!,
      status: SyncOperationStatus.values.firstWhere(
        (status) => status.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      progressPercentage:
          (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      error: json['error'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
      estimatedTimeRemaining: json['estimatedTimeRemaining'] != null
          ? Duration(milliseconds: json['estimatedTimeRemaining'] as int)
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Types of synchronization operations
enum SyncOperationType {
  /// Upload file to cloud
  upload,

  /// Download file from cloud
  download,

  /// Delete file from cloud
  delete,

  /// Update file metadata only
  metadata,
}

/// Status of a synchronization operation
enum SyncOperationStatus {
  /// Operation is queued for execution
  queued,

  /// Operation is currently running
  running,

  /// Operation completed successfully
  completed,

  /// Operation failed
  failed,

  /// Operation was cancelled
  cancelled,

  /// Operation is paused
  paused,
}

/// Extension for SyncOperationType convenience methods
extension SyncOperationTypeExtension on SyncOperationType {
  /// Check if this operation involves data transfer
  bool get involvesTransfer =>
      this == SyncOperationType.upload || this == SyncOperationType.download;

  /// Get display text for the operation type
  String get displayText {
    switch (this) {
      case SyncOperationType.upload:
        return 'Upload';
      case SyncOperationType.download:
        return 'Download';
      case SyncOperationType.delete:
        return 'Delete';
      case SyncOperationType.metadata:
        return 'Update Metadata';
    }
  }
}

/// Extension for SyncOperationStatus convenience methods
extension SyncOperationStatusExtension on SyncOperationStatus {
  /// Check if this status represents an active operation
  bool get isActive => this == SyncOperationStatus.running;

  /// Check if this status represents a completed operation
  bool get isCompleted => this == SyncOperationStatus.completed;

  /// Check if this status represents a failed operation
  bool get isFailed => this == SyncOperationStatus.failed;

  /// Check if operation can be cancelled
  bool get canCancel =>
      this == SyncOperationStatus.queued || this == SyncOperationStatus.running;

  /// Check if operation can be retried
  bool get canRetry => this == SyncOperationStatus.failed;

  /// Get display text for the status
  String get displayText {
    switch (this) {
      case SyncOperationStatus.queued:
        return 'Queued';
      case SyncOperationStatus.running:
        return 'Running';
      case SyncOperationStatus.completed:
        return 'Completed';
      case SyncOperationStatus.failed:
        return 'Failed';
      case SyncOperationStatus.cancelled:
        return 'Cancelled';
      case SyncOperationStatus.paused:
        return 'Paused';
    }
  }
}
