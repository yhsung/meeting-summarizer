import 'cloud_provider.dart';

/// Represents a synchronization conflict between local and remote files
class SyncConflict {
  final String id;
  final String filePath;
  final CloudProvider provider;
  final ConflictType type;
  final FileVersion localVersion;
  final FileVersion remoteVersion;
  final DateTime detectedAt;
  final ConflictSeverity severity;
  final String? description;
  final bool isResolved;
  final ConflictResolution? resolution;
  final DateTime? resolvedAt;
  final Map<String, dynamic> metadata;

  const SyncConflict({
    required this.id,
    required this.filePath,
    required this.provider,
    required this.type,
    required this.localVersion,
    required this.remoteVersion,
    required this.detectedAt,
    required this.severity,
    this.description,
    this.isResolved = false,
    this.resolution,
    this.resolvedAt,
    this.metadata = const {},
  });

  /// Get human-readable conflict description
  String get humanReadableDescription {
    if (description != null) return description!;

    switch (type) {
      case ConflictType.modifiedBoth:
        return 'Both local and remote versions have been modified';
      case ConflictType.deletedLocal:
        return 'File was deleted locally but modified remotely';
      case ConflictType.deletedRemote:
        return 'File was deleted remotely but modified locally';
      case ConflictType.typeChanged:
        return 'File type changed between local and remote versions';
      case ConflictType.permissionDenied:
        return 'Permission denied accessing remote file';
      case ConflictType.sizeMismatch:
        return 'File sizes differ significantly between versions';
      case ConflictType.checksumMismatch:
        return 'File checksums do not match';
      case ConflictType.encodingConflict:
        return 'File encoding differs between versions';
    }
  }

  /// Get suggested automatic resolution
  ConflictResolution get suggestedResolution {
    switch (type) {
      case ConflictType.modifiedBoth:
        // Prefer newer version
        if (localVersion.modifiedAt.isAfter(remoteVersion.modifiedAt)) {
          return ConflictResolution.keepLocal;
        } else {
          return ConflictResolution.keepRemote;
        }
      case ConflictType.deletedLocal:
        return ConflictResolution.keepRemote;
      case ConflictType.deletedRemote:
        return ConflictResolution.keepLocal;
      case ConflictType.sizeMismatch:
      case ConflictType.checksumMismatch:
        // Prefer larger or more recently modified file
        if (localVersion.size > remoteVersion.size ||
            localVersion.modifiedAt.isAfter(remoteVersion.modifiedAt)) {
          return ConflictResolution.keepLocal;
        } else {
          return ConflictResolution.keepRemote;
        }
      case ConflictType.typeChanged:
      case ConflictType.permissionDenied:
      case ConflictType.encodingConflict:
        return ConflictResolution.manual;
    }
  }

  /// Check if conflict can be automatically resolved
  bool get canAutoResolve {
    return suggestedResolution != ConflictResolution.manual &&
        severity != ConflictSeverity.critical;
  }

  /// Get time since conflict was detected
  Duration get timeSinceDetected => DateTime.now().difference(detectedAt);

  /// Create a copy with updated values
  SyncConflict copyWith({
    String? id,
    String? filePath,
    CloudProvider? provider,
    ConflictType? type,
    FileVersion? localVersion,
    FileVersion? remoteVersion,
    DateTime? detectedAt,
    ConflictSeverity? severity,
    String? description,
    bool? isResolved,
    ConflictResolution? resolution,
    DateTime? resolvedAt,
    Map<String, dynamic>? metadata,
  }) {
    return SyncConflict(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      provider: provider ?? this.provider,
      type: type ?? this.type,
      localVersion: localVersion ?? this.localVersion,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      detectedAt: detectedAt ?? this.detectedAt,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      isResolved: isResolved ?? this.isResolved,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'provider': provider.id,
      'type': type.name,
      'localVersion': localVersion.toJson(),
      'remoteVersion': remoteVersion.toJson(),
      'detectedAt': detectedAt.toIso8601String(),
      'severity': severity.name,
      'description': description,
      'isResolved': isResolved,
      'resolution': resolution?.name,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      provider: CloudProvider.fromId(json['provider'] as String)!,
      type: ConflictType.values.firstWhere((type) => type.name == json['type']),
      localVersion: FileVersion.fromJson(
        json['localVersion'] as Map<String, dynamic>,
      ),
      remoteVersion: FileVersion.fromJson(
        json['remoteVersion'] as Map<String, dynamic>,
      ),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      severity: ConflictSeverity.values.firstWhere(
        (severity) => severity.name == json['severity'],
      ),
      description: json['description'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
      resolution: json['resolution'] != null
          ? ConflictResolution.values.firstWhere(
              (res) => res.name == json['resolution'],
            )
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Types of synchronization conflicts
enum ConflictType {
  /// Both local and remote files have been modified
  modifiedBoth,

  /// File was deleted locally but exists remotely
  deletedLocal,

  /// File was deleted remotely but exists locally
  deletedRemote,

  /// File type changed between versions
  typeChanged,

  /// Permission denied accessing file
  permissionDenied,

  /// File sizes differ significantly
  sizeMismatch,

  /// File checksums don't match
  checksumMismatch,

  /// File encoding differs
  encodingConflict,
}

/// Severity levels for conflicts
enum ConflictSeverity {
  /// Low severity - can be auto-resolved
  low,

  /// Medium severity - user input recommended
  medium,

  /// High severity - user attention required
  high,

  /// Critical severity - manual resolution required
  critical,
}

/// Strategies for resolving conflicts
enum ConflictResolution {
  /// Keep local version, discard remote
  keepLocal,

  /// Keep remote version, discard local
  keepRemote,

  /// Keep both versions with suffixes
  keepBoth,

  /// Attempt to merge if possible
  merge,

  /// Manual resolution required
  manual,
}

/// Represents a version of a file at a specific point in time
class FileVersion {
  final String path;
  final int size;
  final DateTime modifiedAt;
  final String? checksum;
  final String? mimeType;
  final bool exists;
  final Map<String, dynamic> metadata;

  const FileVersion({
    required this.path,
    required this.size,
    required this.modifiedAt,
    this.checksum,
    this.mimeType,
    this.exists = true,
    this.metadata = const {},
  });

  /// Get formatted file size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file extension
  String get extension {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  /// Get file name without extension
  String get nameWithoutExtension {
    final lastSlash = path.lastIndexOf('/');
    final fileName = lastSlash == -1 ? path : path.substring(lastSlash + 1);
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'size': size,
      'modifiedAt': modifiedAt.toIso8601String(),
      'checksum': checksum,
      'mimeType': mimeType,
      'exists': exists,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory FileVersion.fromJson(Map<String, dynamic> json) {
    return FileVersion(
      path: json['path'] as String,
      size: json['size'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      checksum: json['checksum'] as String?,
      mimeType: json['mimeType'] as String?,
      exists: json['exists'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}
