import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';

/// Abstract interface for cloud provider implementations
abstract class CloudProviderInterface {
  /// The provider this interface represents
  CloudProvider get provider;

  /// Initialize the provider with credentials
  Future<void> initialize(Map<String, String> credentials);

  /// Connect to the cloud provider
  Future<bool> connect();

  /// Disconnect from the cloud provider
  Future<void> disconnect();

  /// Check if currently connected
  Future<bool> isConnected();

  /// Upload a file to the cloud
  Future<bool> uploadFile({
    required String localFilePath,
    required String remoteFilePath,
    Map<String, dynamic> metadata = const {},
    Function(double progress)? onProgress,
  });

  /// Download a file from the cloud
  Future<bool> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    Function(double progress)? onProgress,
  });

  /// Delete a file from the cloud
  Future<bool> deleteFile(String remoteFilePath);

  /// Check if a file exists in the cloud
  Future<bool> fileExists(String remoteFilePath);

  /// Get file metadata from the cloud
  Future<Map<String, dynamic>?> getFileMetadata(String remoteFilePath);

  /// List files in a directory
  Future<List<CloudFileInfo>> listFiles({
    String? directoryPath,
    bool recursive = false,
  });

  /// Get storage quota information
  Future<CloudStorageQuota> getStorageQuota();

  /// Get the last modification time of a file
  Future<DateTime?> getFileModificationTime(String remoteFilePath);

  /// Get the size of a file
  Future<int?> getFileSize(String remoteFilePath);

  /// Create a directory
  Future<bool> createDirectory(String directoryPath);

  /// Delete a directory
  Future<bool> deleteDirectory(String directoryPath);

  /// Move/rename a file
  Future<bool> moveFile({required String fromPath, required String toPath});

  /// Copy a file
  Future<bool> copyFile({required String fromPath, required String toPath});

  /// Get a shareable link for a file
  Future<String?> getShareableLink(String remoteFilePath);

  /// Sync changes from the cloud to local
  Future<List<CloudFileChange>> getRemoteChanges({
    DateTime? since,
    String? directoryPath,
  });

  /// Get provider-specific configuration
  Map<String, dynamic> getConfiguration();

  /// Update provider configuration
  Future<void> updateConfiguration(Map<String, dynamic> config);

  /// Test the connection
  Future<bool> testConnection();

  /// Get error information for the last operation
  String? getLastError();
}

/// Information about a file in the cloud
class CloudFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modifiedAt;
  final bool isDirectory;
  final String? mimeType;
  final String? checksum;
  final Map<String, dynamic> metadata;

  const CloudFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modifiedAt,
    required this.isDirectory,
    this.mimeType,
    this.checksum,
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
    final lastDot = name.lastIndexOf('.');
    if (lastDot == -1) return '';
    return name.substring(lastDot + 1).toLowerCase();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'modifiedAt': modifiedAt.toIso8601String(),
      'isDirectory': isDirectory,
      'mimeType': mimeType,
      'checksum': checksum,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory CloudFileInfo.fromJson(Map<String, dynamic> json) {
    return CloudFileInfo(
      path: json['path'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      isDirectory: json['isDirectory'] as bool,
      mimeType: json['mimeType'] as String?,
      checksum: json['checksum'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Represents a change in a cloud file
class CloudFileChange {
  final String path;
  final CloudChangeType type;
  final DateTime timestamp;
  final CloudFileInfo? fileInfo;

  const CloudFileChange({
    required this.path,
    required this.type,
    required this.timestamp,
    this.fileInfo,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'fileInfo': fileInfo?.toJson(),
    };
  }

  /// Create from JSON
  factory CloudFileChange.fromJson(Map<String, dynamic> json) {
    return CloudFileChange(
      path: json['path'] as String,
      type: CloudChangeType.values.firstWhere(
        (type) => type.name == json['type'],
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileInfo: json['fileInfo'] != null
          ? CloudFileInfo.fromJson(json['fileInfo'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Types of changes that can occur to cloud files
enum CloudChangeType {
  /// File was created
  created,

  /// File was modified
  modified,

  /// File was deleted
  deleted,

  /// File was moved/renamed
  moved,
}
