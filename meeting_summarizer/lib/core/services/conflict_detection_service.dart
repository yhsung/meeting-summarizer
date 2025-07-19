import 'dart:developer';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_conflict.dart';
import 'cloud_providers/cloud_provider_interface.dart';

/// Service for detecting synchronization conflicts between local and remote files
class ConflictDetectionService {
  static ConflictDetectionService? _instance;
  static ConflictDetectionService get instance =>
      _instance ??= ConflictDetectionService._();
  ConflictDetectionService._();

  /// Detect conflicts for a specific file across providers
  Future<List<SyncConflict>> detectFileConflicts({
    required String filePath,
    required Map<CloudProvider, CloudProviderInterface> connectedProviders,
    String? localFilePath,
  }) async {
    final conflicts = <SyncConflict>[];

    try {
      log('ConflictDetectionService: Detecting conflicts for $filePath');

      // Get local file version if it exists
      FileVersion? localVersion;
      if (localFilePath != null) {
        localVersion = await _getLocalFileVersion(localFilePath);
      }

      // Check each connected provider for conflicts
      for (final entry in connectedProviders.entries) {
        final provider = entry.key;
        final providerInterface = entry.value;

        try {
          final remoteVersion = await _getRemoteFileVersion(
            filePath,
            providerInterface,
          );

          if (remoteVersion != null && localVersion != null) {
            final conflict = await _detectConflictBetweenVersions(
              filePath: filePath,
              provider: provider,
              localVersion: localVersion,
              remoteVersion: remoteVersion,
            );

            if (conflict != null) {
              conflicts.add(conflict);
            }
          } else if (localVersion != null && remoteVersion == null) {
            // Local file exists but remote doesn't - potential deletion conflict
            final deletionConflict = await _detectDeletionConflict(
              filePath: filePath,
              provider: provider,
              localVersion: localVersion,
              isRemoteDeleted: true,
            );
            if (deletionConflict != null) {
              conflicts.add(deletionConflict);
            }
          } else if (localVersion == null && remoteVersion != null) {
            // Remote file exists but local doesn't - potential deletion conflict
            final deletionConflict = await _detectDeletionConflict(
              filePath: filePath,
              provider: provider,
              localVersion: remoteVersion,
              isRemoteDeleted: false,
            );
            if (deletionConflict != null) {
              conflicts.add(deletionConflict);
            }
          }
        } catch (e) {
          log(
            'ConflictDetectionService: Error checking ${provider.displayName}: $e',
          );
        }
      }

      log(
        'ConflictDetectionService: Found ${conflicts.length} conflicts for $filePath',
      );
      return conflicts;
    } catch (e, stackTrace) {
      log(
        'ConflictDetectionService: Error detecting conflicts: $e',
        stackTrace: stackTrace,
      );
      return conflicts;
    }
  }

  /// Detect conflicts across all files in connected providers
  Future<List<SyncConflict>> detectAllConflicts({
    required Map<CloudProvider, CloudProviderInterface> connectedProviders,
    String? localDirectory,
  }) async {
    final allConflicts = <SyncConflict>[];

    try {
      log(
        'ConflictDetectionService: Starting comprehensive conflict detection',
      );

      // Get all unique file paths from all providers
      final allFilePaths = <String>{};

      // Add local file paths if directory provided
      if (localDirectory != null) {
        final localFiles = await _getLocalFilePaths(localDirectory);
        allFilePaths.addAll(localFiles);
      }

      // Add remote file paths from all providers
      for (final entry in connectedProviders.entries) {
        try {
          final providerInterface = entry.value;
          final remoteFiles = await providerInterface.listFiles(
            recursive: true,
          );
          allFilePaths.addAll(remoteFiles.map((file) => file.path));
        } catch (e) {
          log(
            'ConflictDetectionService: Error getting files from ${entry.key.displayName}: $e',
          );
        }
      }

      log(
        'ConflictDetectionService: Checking ${allFilePaths.length} unique files',
      );

      // Check each unique file path for conflicts
      for (final filePath in allFilePaths) {
        final localFilePath = localDirectory != null
            ? '$localDirectory/$filePath'
            : null;

        final fileConflicts = await detectFileConflicts(
          filePath: filePath,
          connectedProviders: connectedProviders,
          localFilePath: localFilePath,
        );

        allConflicts.addAll(fileConflicts);
      }

      log(
        'ConflictDetectionService: Found ${allConflicts.length} total conflicts',
      );
      return allConflicts;
    } catch (e, stackTrace) {
      log(
        'ConflictDetectionService: Error in comprehensive detection: $e',
        stackTrace: stackTrace,
      );
      return allConflicts;
    }
  }

  /// Get local file version information
  Future<FileVersion?> _getLocalFileVersion(String localFilePath) async {
    try {
      final file = File(localFilePath);
      if (!await file.exists()) {
        return FileVersion(
          path: localFilePath,
          size: 0,
          modifiedAt: DateTime.now(),
          exists: false,
        );
      }

      final stat = await file.stat();
      final bytes = await file.readAsBytes();
      final checksum = _calculateChecksum(bytes);

      return FileVersion(
        path: localFilePath,
        size: stat.size,
        modifiedAt: stat.modified,
        checksum: checksum,
        mimeType: _getMimeType(localFilePath),
        exists: true,
        metadata: {
          'lastAccessed': stat.accessed.toIso8601String(),
          'fileMode': stat.mode.toString(),
        },
      );
    } catch (e) {
      log('ConflictDetectionService: Error getting local file version: $e');
      return null;
    }
  }

  /// Get remote file version information
  Future<FileVersion?> _getRemoteFileVersion(
    String filePath,
    CloudProviderInterface provider,
  ) async {
    try {
      if (!await provider.fileExists(filePath)) {
        return FileVersion(
          path: filePath,
          size: 0,
          modifiedAt: DateTime.now(),
          exists: false,
        );
      }

      final metadata = await provider.getFileMetadata(filePath);
      if (metadata == null) return null;

      final size = await provider.getFileSize(filePath) ?? 0;
      final modifiedAt =
          await provider.getFileModificationTime(filePath) ?? DateTime.now();

      return FileVersion(
        path: filePath,
        size: size,
        modifiedAt: modifiedAt,
        mimeType: metadata['mimeType'] as String?,
        exists: true,
        metadata: Map<String, dynamic>.from(metadata),
      );
    } catch (e) {
      log('ConflictDetectionService: Error getting remote file version: $e');
      return null;
    }
  }

  /// Detect conflict between two file versions
  Future<SyncConflict?> _detectConflictBetweenVersions({
    required String filePath,
    required CloudProvider provider,
    required FileVersion localVersion,
    required FileVersion remoteVersion,
  }) async {
    try {
      // No conflict if files are identical
      if (_areVersionsIdentical(localVersion, remoteVersion)) {
        return null;
      }

      ConflictType conflictType;
      ConflictSeverity severity;

      // Determine conflict type and severity
      if (!localVersion.exists && !remoteVersion.exists) {
        return null; // Both deleted, no conflict
      } else if (!localVersion.exists) {
        conflictType = ConflictType.deletedLocal;
        severity = ConflictSeverity.medium;
      } else if (!remoteVersion.exists) {
        conflictType = ConflictType.deletedRemote;
        severity = ConflictSeverity.medium;
      } else if (_hasSignificantSizeDifference(localVersion, remoteVersion)) {
        conflictType = ConflictType.sizeMismatch;
        severity = ConflictSeverity.high;
      } else if (_hasChecksumMismatch(localVersion, remoteVersion)) {
        conflictType = ConflictType.checksumMismatch;
        severity = ConflictSeverity.high;
      } else if (_hasMimeTypeMismatch(localVersion, remoteVersion)) {
        conflictType = ConflictType.typeChanged;
        severity = ConflictSeverity.medium;
      } else {
        // Both files exist and have been modified
        conflictType = ConflictType.modifiedBoth;
        severity = _calculateModificationSeverity(localVersion, remoteVersion);
      }

      return SyncConflict(
        id: _generateConflictId(filePath, provider),
        filePath: filePath,
        provider: provider,
        type: conflictType,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
        detectedAt: DateTime.now(),
        severity: severity,
        description: _generateConflictDescription(
          conflictType,
          localVersion,
          remoteVersion,
        ),
        metadata: {
          'detectionMethod': 'version_comparison',
          'timeDifference': remoteVersion.modifiedAt
              .difference(localVersion.modifiedAt)
              .inSeconds,
          'sizeDifference': (remoteVersion.size - localVersion.size).abs(),
        },
      );
    } catch (e) {
      log('ConflictDetectionService: Error detecting conflict: $e');
      return null;
    }
  }

  /// Detect deletion conflicts
  Future<SyncConflict?> _detectDeletionConflict({
    required String filePath,
    required CloudProvider provider,
    required FileVersion localVersion,
    required bool isRemoteDeleted,
  }) async {
    // Only create conflict if local file was modified recently
    final timeSinceModification = DateTime.now().difference(
      localVersion.modifiedAt,
    );

    // Don't create conflict for old files (more than 30 days)
    if (timeSinceModification.inDays > 30) {
      return null;
    }

    final conflictType = isRemoteDeleted
        ? ConflictType.deletedRemote
        : ConflictType.deletedLocal;

    final remoteVersion = FileVersion(
      path: filePath,
      size: 0,
      modifiedAt: DateTime.now(),
      exists: false,
    );

    return SyncConflict(
      id: _generateConflictId(filePath, provider),
      filePath: filePath,
      provider: provider,
      type: conflictType,
      localVersion: isRemoteDeleted ? localVersion : remoteVersion,
      remoteVersion: isRemoteDeleted ? remoteVersion : localVersion,
      detectedAt: DateTime.now(),
      severity: ConflictSeverity.medium,
      description: isRemoteDeleted
          ? 'File was deleted remotely but exists locally'
          : 'File was deleted locally but exists remotely',
      metadata: {
        'detectionMethod': 'deletion_detection',
        'daysSinceModification': timeSinceModification.inDays,
      },
    );
  }

  /// Check if two versions are identical
  bool _areVersionsIdentical(FileVersion local, FileVersion remote) {
    if (local.exists != remote.exists) return false;
    if (!local.exists && !remote.exists) return true;

    // Compare size and modification time
    if (local.size != remote.size) return false;

    // Consider files identical if modified within 1 second of each other
    final timeDifference =
        (local.modifiedAt.millisecondsSinceEpoch -
                remote.modifiedAt.millisecondsSinceEpoch)
            .abs();
    if (timeDifference > 1000) return false;

    // Compare checksums if available
    if (local.checksum != null && remote.checksum != null) {
      return local.checksum == remote.checksum;
    }

    return true;
  }

  /// Check for significant size differences
  bool _hasSignificantSizeDifference(FileVersion local, FileVersion remote) {
    if (local.size == 0 || remote.size == 0) return false;

    final sizeDifference = (local.size - remote.size).abs();
    final percentageDifference = sizeDifference / local.size * 100;

    // Consider significant if more than 10% difference or 1MB absolute difference
    return percentageDifference > 10 || sizeDifference > 1024 * 1024;
  }

  /// Check for checksum mismatches
  bool _hasChecksumMismatch(FileVersion local, FileVersion remote) {
    if (local.checksum == null || remote.checksum == null) return false;
    return local.checksum != remote.checksum;
  }

  /// Check for MIME type mismatches
  bool _hasMimeTypeMismatch(FileVersion local, FileVersion remote) {
    if (local.mimeType == null || remote.mimeType == null) return false;
    return local.mimeType != remote.mimeType;
  }

  /// Calculate severity based on modification patterns
  ConflictSeverity _calculateModificationSeverity(
    FileVersion local,
    FileVersion remote,
  ) {
    final timeDifference =
        (local.modifiedAt.millisecondsSinceEpoch -
                remote.modifiedAt.millisecondsSinceEpoch)
            .abs();

    // Recent simultaneous modifications are high severity
    if (timeDifference < Duration(minutes: 5).inMilliseconds) {
      return ConflictSeverity.high;
    }

    // Modifications within an hour are medium severity
    if (timeDifference < Duration(hours: 1).inMilliseconds) {
      return ConflictSeverity.medium;
    }

    return ConflictSeverity.low;
  }

  /// Generate human-readable conflict description
  String _generateConflictDescription(
    ConflictType type,
    FileVersion local,
    FileVersion remote,
  ) {
    switch (type) {
      case ConflictType.modifiedBoth:
        final timeDiff = remote.modifiedAt.difference(local.modifiedAt);
        if (timeDiff.isNegative) {
          return 'Local file is newer by ${timeDiff.abs().inMinutes} minutes';
        } else {
          return 'Remote file is newer by ${timeDiff.inMinutes} minutes';
        }
      case ConflictType.sizeMismatch:
        final sizeDiff = (remote.size - local.size);
        final diffStr = sizeDiff > 0 ? '+$sizeDiff' : '$sizeDiff';
        return 'Size difference: $diffStr bytes (${local.formattedSize} vs ${remote.formattedSize})';
      case ConflictType.checksumMismatch:
        return 'File contents differ (checksum mismatch)';
      case ConflictType.typeChanged:
        return 'File type changed: ${local.mimeType} → ${remote.mimeType}';
      default:
        return 'Synchronization conflict detected';
    }
  }

  /// Get local file paths recursively
  Future<List<String>> _getLocalFilePaths(String directory) async {
    final paths = <String>[];
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) return paths;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = entity.path.substring(directory.length + 1);
          paths.add(relativePath);
        }
      }
    } catch (e) {
      log('ConflictDetectionService: Error getting local file paths: $e');
    }
    return paths;
  }

  /// Calculate file checksum
  String _calculateChecksum(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get MIME type from file extension
  String? _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        return null;
    }
  }

  /// Generate unique conflict ID
  String _generateConflictId(String filePath, CloudProvider provider) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pathHash = filePath.hashCode.abs();
    return 'conflict_${provider.id}_${pathHash}_$timestamp';
  }
}
