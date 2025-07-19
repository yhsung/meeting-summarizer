import 'cloud_provider.dart';

/// Status of a synchronization operation
class SyncStatus {
  final String id;
  final SyncState state;
  final CloudProvider? provider;
  final DateTime lastSync;
  final DateTime? nextSync;
  final int filesUploaded;
  final int filesDownloaded;
  final int filesSkipped;
  final int filesErrored;
  final List<String> errors;
  final double progressPercentage;
  final int totalFiles;
  final int processedFiles;
  final String? currentOperation;

  const SyncStatus({
    required this.id,
    required this.state,
    this.provider,
    required this.lastSync,
    this.nextSync,
    this.filesUploaded = 0,
    this.filesDownloaded = 0,
    this.filesSkipped = 0,
    this.filesErrored = 0,
    this.errors = const [],
    this.progressPercentage = 0.0,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.currentOperation,
  });

  /// Check if sync is currently running
  bool get isActive =>
      state == SyncState.syncing || state == SyncState.preparing;

  /// Check if sync completed successfully
  bool get isSuccess => state == SyncState.completed && filesErrored == 0;

  /// Check if sync has errors
  bool get hasErrors => filesErrored > 0 || errors.isNotEmpty;

  /// Get summary of sync results
  String get resultSummary {
    if (state == SyncState.idle) return 'Ready to sync';
    if (state == SyncState.preparing) return 'Preparing sync...';
    if (state == SyncState.syncing) return 'Syncing files...';
    if (state == SyncState.paused) return 'Sync paused';
    if (state == SyncState.cancelled) return 'Sync cancelled';
    if (state == SyncState.error) return 'Sync failed';

    // Completed state
    final uploaded = filesUploaded > 0 ? '$filesUploaded uploaded' : '';
    final downloaded = filesDownloaded > 0 ? '$filesDownloaded downloaded' : '';
    final skipped = filesSkipped > 0 ? '$filesSkipped skipped' : '';
    final errored = filesErrored > 0 ? '$filesErrored errors' : '';

    final parts = [
      uploaded,
      downloaded,
      skipped,
      errored,
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return 'No changes';
    return parts.join(', ');
  }

  /// Create a copy with updated values
  SyncStatus copyWith({
    String? id,
    SyncState? state,
    CloudProvider? provider,
    DateTime? lastSync,
    DateTime? nextSync,
    int? filesUploaded,
    int? filesDownloaded,
    int? filesSkipped,
    int? filesErrored,
    List<String>? errors,
    double? progressPercentage,
    int? totalFiles,
    int? processedFiles,
    String? currentOperation,
  }) {
    return SyncStatus(
      id: id ?? this.id,
      state: state ?? this.state,
      provider: provider ?? this.provider,
      lastSync: lastSync ?? this.lastSync,
      nextSync: nextSync ?? this.nextSync,
      filesUploaded: filesUploaded ?? this.filesUploaded,
      filesDownloaded: filesDownloaded ?? this.filesDownloaded,
      filesSkipped: filesSkipped ?? this.filesSkipped,
      filesErrored: filesErrored ?? this.filesErrored,
      errors: errors ?? this.errors,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state': state.name,
      'provider': provider?.id,
      'lastSync': lastSync.toIso8601String(),
      'nextSync': nextSync?.toIso8601String(),
      'filesUploaded': filesUploaded,
      'filesDownloaded': filesDownloaded,
      'filesSkipped': filesSkipped,
      'filesErrored': filesErrored,
      'errors': errors,
      'progressPercentage': progressPercentage,
      'totalFiles': totalFiles,
      'processedFiles': processedFiles,
      'currentOperation': currentOperation,
    };
  }

  /// Create from JSON
  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      id: json['id'] as String,
      state: SyncState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => SyncState.idle,
      ),
      provider: json['provider'] != null
          ? CloudProvider.fromId(json['provider'] as String)
          : null,
      lastSync: DateTime.parse(json['lastSync'] as String),
      nextSync: json['nextSync'] != null
          ? DateTime.parse(json['nextSync'] as String)
          : null,
      filesUploaded: json['filesUploaded'] as int? ?? 0,
      filesDownloaded: json['filesDownloaded'] as int? ?? 0,
      filesSkipped: json['filesSkipped'] as int? ?? 0,
      filesErrored: json['filesErrored'] as int? ?? 0,
      errors: List<String>.from(json['errors'] as List? ?? []),
      progressPercentage:
          (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      totalFiles: json['totalFiles'] as int? ?? 0,
      processedFiles: json['processedFiles'] as int? ?? 0,
      currentOperation: json['currentOperation'] as String?,
    );
  }
}

/// States of synchronization
enum SyncState {
  /// No sync operation running
  idle,

  /// Preparing for sync (checking files, conflicts, etc.)
  preparing,

  /// Actively syncing files
  syncing,

  /// Sync completed successfully
  completed,

  /// Sync paused by user
  paused,

  /// Sync cancelled by user
  cancelled,

  /// Sync failed due to error
  error,
}

/// Extension for SyncState convenience methods
extension SyncStateExtension on SyncState {
  /// Check if this state represents an active operation
  bool get isActive => this == SyncState.syncing || this == SyncState.preparing;

  /// Check if this state represents a completed operation
  bool get isCompleted => this == SyncState.completed;

  /// Check if this state represents an error condition
  bool get isError => this == SyncState.error;

  /// Check if sync can be resumed from this state
  bool get canResume => this == SyncState.paused || this == SyncState.idle;

  /// Check if sync can be paused from this state
  bool get canPause => this == SyncState.syncing || this == SyncState.preparing;

  /// Get display text for the state
  String get displayText {
    switch (this) {
      case SyncState.idle:
        return 'Ready';
      case SyncState.preparing:
        return 'Preparing';
      case SyncState.syncing:
        return 'Syncing';
      case SyncState.completed:
        return 'Completed';
      case SyncState.paused:
        return 'Paused';
      case SyncState.cancelled:
        return 'Cancelled';
      case SyncState.error:
        return 'Error';
    }
  }
}
