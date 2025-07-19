import '../../../core/models/cloud_sync/cloud_provider.dart';

/// Represents a change to a file that needs to be synchronized
class FileChange {
  final String filePath;
  final String fileId;
  final CloudProvider provider;
  final FileChangeType changeType;
  final DateTime detectedAt;
  final DateTime lastModified;
  final int fileSize;
  final String? checksum;
  final String? previousChecksum;
  final List<FileChunk>? changedChunks;
  final Map<String, dynamic> metadata;

  const FileChange({
    required this.filePath,
    required this.fileId,
    required this.provider,
    required this.changeType,
    required this.detectedAt,
    required this.lastModified,
    required this.fileSize,
    this.checksum,
    this.previousChecksum,
    this.changedChunks,
    this.metadata = const {},
  });

  FileChange copyWith({
    String? filePath,
    String? fileId,
    CloudProvider? provider,
    FileChangeType? changeType,
    DateTime? detectedAt,
    DateTime? lastModified,
    int? fileSize,
    String? checksum,
    String? previousChecksum,
    List<FileChunk>? changedChunks,
    Map<String, dynamic>? metadata,
  }) {
    return FileChange(
      filePath: filePath ?? this.filePath,
      fileId: fileId ?? this.fileId,
      provider: provider ?? this.provider,
      changeType: changeType ?? this.changeType,
      detectedAt: detectedAt ?? this.detectedAt,
      lastModified: lastModified ?? this.lastModified,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      previousChecksum: previousChecksum ?? this.previousChecksum,
      changedChunks: changedChunks ?? this.changedChunks,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Calculate the size of changes (total size of changed chunks)
  int get changeSize {
    if (changedChunks == null || changedChunks!.isEmpty) {
      return fileSize; // Full file change
    }
    return changedChunks!.fold(0, (sum, chunk) => sum + chunk.size);
  }

  /// Get the percentage of the file that has changed
  double get changePercentage {
    if (fileSize == 0) return 0.0;
    return (changeSize / fileSize) * 100;
  }

  /// Check if this is a significant change (more than 1% of file)
  bool get isSignificantChange {
    return changePercentage > 1.0 || changeSize > 1024; // 1% or 1KB minimum
  }

  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'file_id': fileId,
      'provider_id': provider.id,
      'change_type': changeType.name,
      'detected_at': detectedAt.toIso8601String(),
      'last_modified': lastModified.toIso8601String(),
      'file_size': fileSize,
      'checksum': checksum,
      'previous_checksum': previousChecksum,
      'changed_chunks': changedChunks?.map((chunk) => chunk.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory FileChange.fromJson(Map<String, dynamic> json) {
    return FileChange(
      filePath: json['file_path'] as String,
      fileId: json['file_id'] as String,
      provider: CloudProvider.values.firstWhere(
        (p) => p.id == json['provider_id'],
      ),
      changeType: FileChangeType.values.firstWhere(
        (t) => t.name == json['change_type'],
      ),
      detectedAt: DateTime.parse(json['detected_at'] as String),
      lastModified: DateTime.parse(json['last_modified'] as String),
      fileSize: json['file_size'] as int,
      checksum: json['checksum'] as String?,
      previousChecksum: json['previous_checksum'] as String?,
      changedChunks: (json['changed_chunks'] as List<dynamic>?)
          ?.map((chunk) => FileChunk.fromJson(chunk as Map<String, dynamic>))
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  @override
  String toString() {
    return 'FileChange(path: $filePath, type: $changeType, '
        'size: $fileSize, changeSize: $changeSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileChange &&
        other.filePath == filePath &&
        other.provider == provider;
  }

  @override
  int get hashCode => Object.hash(filePath, provider);
}

/// Types of file changes that can be detected
enum FileChangeType {
  created,
  modified,
  deleted,
  moved,
  renamed,
  metadataChanged,
}

/// Represents a chunk of a file for delta synchronization
class FileChunk {
  final int index;
  final int offset;
  final int size;
  final String checksum;
  final bool isChanged;
  final List<int>? data; // Optional chunk data for immediate use

  const FileChunk({
    required this.index,
    required this.offset,
    required this.size,
    required this.checksum,
    required this.isChanged,
    this.data,
  });

  FileChunk copyWith({
    int? index,
    int? offset,
    int? size,
    String? checksum,
    bool? isChanged,
    List<int>? data,
  }) {
    return FileChunk(
      index: index ?? this.index,
      offset: offset ?? this.offset,
      size: size ?? this.size,
      checksum: checksum ?? this.checksum,
      isChanged: isChanged ?? this.isChanged,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'offset': offset,
      'size': size,
      'checksum': checksum,
      'is_changed': isChanged,
      // Note: data is not serialized to avoid large JSON objects
    };
  }

  factory FileChunk.fromJson(Map<String, dynamic> json) {
    return FileChunk(
      index: json['index'] as int,
      offset: json['offset'] as int,
      size: json['size'] as int,
      checksum: json['checksum'] as String,
      isChanged: json['is_changed'] as bool,
    );
  }

  @override
  String toString() {
    return 'FileChunk(index: $index, offset: $offset, size: $size, '
        'changed: $isChanged)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileChunk &&
        other.index == index &&
        other.offset == offset &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(index, offset, size);
}

/// Metadata about incremental sync for a file
class IncrementalSyncMetadata {
  final String filePath;
  final CloudProvider provider;
  final DateTime lastSyncTime;
  final String lastKnownChecksum;
  final int lastKnownSize;
  final List<FileChunk> chunks;
  final Map<String, dynamic> providerMetadata;

  const IncrementalSyncMetadata({
    required this.filePath,
    required this.provider,
    required this.lastSyncTime,
    required this.lastKnownChecksum,
    required this.lastKnownSize,
    required this.chunks,
    this.providerMetadata = const {},
  });

  IncrementalSyncMetadata copyWith({
    String? filePath,
    CloudProvider? provider,
    DateTime? lastSyncTime,
    String? lastKnownChecksum,
    int? lastKnownSize,
    List<FileChunk>? chunks,
    Map<String, dynamic>? providerMetadata,
  }) {
    return IncrementalSyncMetadata(
      filePath: filePath ?? this.filePath,
      provider: provider ?? this.provider,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastKnownChecksum: lastKnownChecksum ?? this.lastKnownChecksum,
      lastKnownSize: lastKnownSize ?? this.lastKnownSize,
      chunks: chunks ?? this.chunks,
      providerMetadata: providerMetadata ?? this.providerMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'provider_id': provider.id,
      'last_sync_time': lastSyncTime.toIso8601String(),
      'last_known_checksum': lastKnownChecksum,
      'last_known_size': lastKnownSize,
      'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
      'provider_metadata': providerMetadata,
    };
  }

  factory IncrementalSyncMetadata.fromJson(Map<String, dynamic> json) {
    return IncrementalSyncMetadata(
      filePath: json['file_path'] as String,
      provider: CloudProvider.values.firstWhere(
        (p) => p.id == json['provider_id'],
      ),
      lastSyncTime: DateTime.parse(json['last_sync_time'] as String),
      lastKnownChecksum: json['last_known_checksum'] as String,
      lastKnownSize: json['last_known_size'] as int,
      chunks: (json['chunks'] as List<dynamic>)
          .map((chunk) => FileChunk.fromJson(chunk as Map<String, dynamic>))
          .toList(),
      providerMetadata: Map<String, dynamic>.from(
        json['provider_metadata'] as Map,
      ),
    );
  }

  @override
  String toString() {
    return 'IncrementalSyncMetadata(path: $filePath, provider: ${provider.displayName}, '
        'chunks: ${chunks.length})';
  }
}
