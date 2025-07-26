import 'dart:developer';
import 'dart:io';

import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_conflict.dart';
import 'cloud_providers/cloud_provider_interface.dart';

/// Service for resolving synchronization conflicts
class ConflictResolutionService {
  static ConflictResolutionService? _instance;
  static ConflictResolutionService get instance =>
      _instance ??= ConflictResolutionService._();
  ConflictResolutionService._();

  /// Resolve a conflict using the specified resolution strategy
  Future<ConflictResolutionResult> resolveConflict({
    required SyncConflict conflict,
    required ConflictResolution resolution,
    required CloudProviderInterface providerInterface,
    String? userInput,
  }) async {
    try {
      log(
        'ConflictResolutionService: Resolving conflict ${conflict.id} with $resolution',
      );

      switch (resolution) {
        case ConflictResolution.keepLocal:
          return await _resolveKeepLocal(conflict, providerInterface);

        case ConflictResolution.keepRemote:
          return await _resolveKeepRemote(conflict, providerInterface);

        case ConflictResolution.keepBoth:
          return await _resolveKeepBoth(conflict, providerInterface);

        case ConflictResolution.merge:
          return await _resolveMerge(conflict, providerInterface, userInput);

        case ConflictResolution.manual:
          return ConflictResolutionResult(
            success: false,
            requiresUserInput: true,
            message: 'Manual resolution required - please choose an option',
          );
      }
    } catch (e, stackTrace) {
      log(
        'ConflictResolutionService: Error resolving conflict: $e',
        stackTrace: stackTrace,
      );
      return ConflictResolutionResult(
        success: false,
        message: 'Error resolving conflict: $e',
      );
    }
  }

  /// Auto-resolve conflicts that can be safely resolved without user input
  Future<List<ConflictResolutionResult>> autoResolveConflicts({
    required List<SyncConflict> conflicts,
    required Map<CloudProvider, CloudProviderInterface> connectedProviders,
    AutoResolutionStrategy strategy = AutoResolutionStrategy.conservative,
  }) async {
    final results = <ConflictResolutionResult>[];

    for (final conflict in conflicts) {
      if (!conflict.canAutoResolve &&
          strategy == AutoResolutionStrategy.conservative) {
        results.add(
          ConflictResolutionResult(
            conflictId: conflict.id,
            success: false,
            requiresUserInput: true,
            message: 'Conflict requires manual resolution',
          ),
        );
        continue;
      }

      final providerInterface = connectedProviders[conflict.provider];
      if (providerInterface == null) {
        results.add(
          ConflictResolutionResult(
            conflictId: conflict.id,
            success: false,
            message: 'Provider ${conflict.provider.displayName} not connected',
          ),
        );
        continue;
      }

      ConflictResolution resolution;
      switch (strategy) {
        case AutoResolutionStrategy.conservative:
          resolution = conflict.suggestedResolution;
          break;
        case AutoResolutionStrategy.favorLocal:
          resolution = _getFavorLocalResolution(conflict);
          break;
        case AutoResolutionStrategy.favorRemote:
          resolution = _getFavorRemoteResolution(conflict);
          break;
        case AutoResolutionStrategy.favorNewer:
          resolution = _getFavorNewerResolution(conflict);
          break;
        case AutoResolutionStrategy.keepBothWhenUnsure:
          resolution = conflict.canAutoResolve
              ? conflict.suggestedResolution
              : ConflictResolution.keepBoth;
          break;
      }

      final result = await resolveConflict(
        conflict: conflict,
        resolution: resolution,
        providerInterface: providerInterface,
      );

      result.conflictId = conflict.id;
      results.add(result);

      if (result.success) {
        log(
          'ConflictResolutionService: Auto-resolved conflict ${conflict.id} with $resolution',
        );
      }
    }

    return results;
  }

  /// Resolve by keeping local version and uploading to remote
  Future<ConflictResolutionResult> _resolveKeepLocal(
    SyncConflict conflict,
    CloudProviderInterface providerInterface,
  ) async {
    try {
      if (!conflict.localVersion.exists) {
        // Local file doesn't exist, delete remote
        final deleted = await providerInterface.deleteFile(conflict.filePath);
        return ConflictResolutionResult(
          success: deleted,
          message: deleted
              ? 'Remote file deleted to match local state'
              : 'Failed to delete remote file',
          actionTaken: ConflictAction.deletedRemote,
        );
      }

      // Upload local file to remote
      final uploaded = await providerInterface.uploadFile(
        localFilePath: conflict.localVersion.path,
        remoteFilePath: conflict.filePath,
        onProgress: (progress) {
          log('ConflictResolutionService: Upload progress: ${progress * 100}%');
        },
      );

      return ConflictResolutionResult(
        success: uploaded,
        message: uploaded
            ? 'Local version uploaded to remote'
            : 'Failed to upload local version',
        actionTaken: ConflictAction.uploadedLocal,
      );
    } catch (e) {
      return ConflictResolutionResult(
        success: false,
        message: 'Error keeping local version: $e',
      );
    }
  }

  /// Resolve by keeping remote version and downloading to local
  Future<ConflictResolutionResult> _resolveKeepRemote(
    SyncConflict conflict,
    CloudProviderInterface providerInterface,
  ) async {
    try {
      if (!conflict.remoteVersion.exists) {
        // Remote file doesn't exist, delete local
        final localFile = File(conflict.localVersion.path);
        if (await localFile.exists()) {
          await localFile.delete();
        }
        return ConflictResolutionResult(
          success: true,
          message: 'Local file deleted to match remote state',
          actionTaken: ConflictAction.deletedLocal,
        );
      }

      // Download remote file to local
      final downloaded = await providerInterface.downloadFile(
        remoteFilePath: conflict.filePath,
        localFilePath: conflict.localVersion.path,
        onProgress: (progress) {
          log(
            'ConflictResolutionService: Download progress: ${progress * 100}%',
          );
        },
      );

      return ConflictResolutionResult(
        success: downloaded,
        message: downloaded
            ? 'Remote version downloaded to local'
            : 'Failed to download remote version',
        actionTaken: ConflictAction.downloadedRemote,
      );
    } catch (e) {
      return ConflictResolutionResult(
        success: false,
        message: 'Error keeping remote version: $e',
      );
    }
  }

  /// Resolve by keeping both versions with suffixes
  Future<ConflictResolutionResult> _resolveKeepBoth(
    SyncConflict conflict,
    CloudProviderInterface providerInterface,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _getFileNameWithoutExtension(conflict.filePath);
      final extension = _getFileExtension(conflict.filePath);

      final localSuffix = '_local_$timestamp';
      final remoteSuffix = '_remote_$timestamp';

      final localVersionPath = '$baseName$localSuffix$extension';
      final remoteVersionPath = '$baseName$remoteSuffix$extension';

      var success = true;
      final actions = <String>[];

      // Handle local version
      if (conflict.localVersion.exists) {
        final uploaded = await providerInterface.uploadFile(
          localFilePath: conflict.localVersion.path,
          remoteFilePath: localVersionPath,
        );
        if (uploaded) {
          actions.add('Local version saved as $localVersionPath');
        } else {
          success = false;
          actions.add('Failed to save local version');
        }
      }

      // Handle remote version
      if (conflict.remoteVersion.exists) {
        final remoteLocalPath =
            '${_getDirectoryPath(conflict.localVersion.path)}/$remoteVersionPath';
        final downloaded = await providerInterface.downloadFile(
          remoteFilePath: conflict.filePath,
          localFilePath: remoteLocalPath,
        );
        if (downloaded) {
          actions.add('Remote version saved as $remoteVersionPath');
        } else {
          success = false;
          actions.add('Failed to save remote version');
        }
      }

      return ConflictResolutionResult(
        success: success,
        message: actions.join('; '),
        actionTaken: ConflictAction.keptBoth,
        additionalFiles: [localVersionPath, remoteVersionPath],
      );
    } catch (e) {
      return ConflictResolutionResult(
        success: false,
        message: 'Error keeping both versions: $e',
      );
    }
  }

  /// Resolve by attempting to merge files (text files only)
  Future<ConflictResolutionResult> _resolveMerge(
    SyncConflict conflict,
    CloudProviderInterface providerInterface,
    String? userInput,
  ) async {
    try {
      // Check if files can be merged (text files)
      if (!_canMergeFiles(conflict)) {
        return ConflictResolutionResult(
          success: false,
          message: 'Files cannot be merged automatically (non-text files)',
          requiresUserInput: true,
        );
      }

      // For now, implement a simple merge strategy
      // In a real implementation, this would use proper merge algorithms
      final localContent = conflict.localVersion.exists
          ? await _readFileContent(conflict.localVersion.path)
          : '';

      // Download remote content to temporary location
      final remoteContent = conflict.remoteVersion.exists
          ? await _downloadRemoteContent(conflict, providerInterface)
          : '';

      final mergedContent = _performSimpleMerge(
        localContent,
        remoteContent,
        userInput,
      );

      // Write merged content to local file
      final localFile = File(conflict.localVersion.path);
      await localFile.writeAsString(mergedContent);

      // Upload merged file to remote
      final uploaded = await providerInterface.uploadFile(
        localFilePath: conflict.localVersion.path,
        remoteFilePath: conflict.filePath,
      );

      return ConflictResolutionResult(
        success: uploaded,
        message: uploaded
            ? 'Files merged successfully'
            : 'Merge completed locally but failed to upload',
        actionTaken: ConflictAction.merged,
      );
    } catch (e) {
      return ConflictResolutionResult(
        success: false,
        message: 'Error merging files: $e',
      );
    }
  }

  /// Get resolution strategy that favors local files
  ConflictResolution _getFavorLocalResolution(SyncConflict conflict) {
    if (conflict.type == ConflictType.deletedRemote) {
      return ConflictResolution.keepLocal;
    }
    if (conflict.localVersion.exists) {
      return ConflictResolution.keepLocal;
    }
    return ConflictResolution.keepRemote;
  }

  /// Get resolution strategy that favors remote files
  ConflictResolution _getFavorRemoteResolution(SyncConflict conflict) {
    if (conflict.type == ConflictType.deletedLocal) {
      return ConflictResolution.keepRemote;
    }
    if (conflict.remoteVersion.exists) {
      return ConflictResolution.keepRemote;
    }
    return ConflictResolution.keepLocal;
  }

  /// Get resolution strategy that favors newer files
  ConflictResolution _getFavorNewerResolution(SyncConflict conflict) {
    if (!conflict.localVersion.exists) return ConflictResolution.keepRemote;
    if (!conflict.remoteVersion.exists) return ConflictResolution.keepLocal;

    return conflict.localVersion.modifiedAt.isAfter(
      conflict.remoteVersion.modifiedAt,
    )
        ? ConflictResolution.keepLocal
        : ConflictResolution.keepRemote;
  }

  /// Check if files can be merged
  bool _canMergeFiles(SyncConflict conflict) {
    final textExtensions = {'.txt', '.md', '.json', '.xml', '.csv', '.log'};
    final extension = _getFileExtension(conflict.filePath).toLowerCase();
    return textExtensions.contains(extension);
  }

  /// Read file content as string
  Future<String> _readFileContent(String filePath) async {
    try {
      final file = File(filePath);
      return await file.readAsString();
    } catch (e) {
      log('ConflictResolutionService: Error reading file content: $e');
      return '';
    }
  }

  /// Download remote file content
  Future<String> _downloadRemoteContent(
    SyncConflict conflict,
    CloudProviderInterface providerInterface,
  ) async {
    try {
      final tempFile = File(
        '${Directory.systemTemp.path}/conflict_temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      final downloaded = await providerInterface.downloadFile(
        remoteFilePath: conflict.filePath,
        localFilePath: tempFile.path,
      );

      if (!downloaded) return '';

      final content = await tempFile.readAsString();
      await tempFile.delete();
      return content;
    } catch (e) {
      log('ConflictResolutionService: Error downloading remote content: $e');
      return '';
    }
  }

  /// Perform simple merge of text content
  String _performSimpleMerge(String local, String remote, String? userInput) {
    if (userInput != null) {
      return userInput; // User provided manual merge
    }

    // Simple merge strategy: combine unique lines
    final localLines = local.split('\n').toSet();
    final remoteLines = remote.split('\n').toSet();
    final mergedLines = <String>{...localLines, ...remoteLines};

    return mergedLines.join('\n');
  }

  /// Get file name without extension
  String _getFileNameWithoutExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  /// Get file extension
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot);
  }

  /// Get directory path from file path
  String _getDirectoryPath(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) return '.';
    return filePath.substring(0, lastSlash);
  }
}

/// Result of a conflict resolution operation
class ConflictResolutionResult {
  String? conflictId;
  final bool success;
  final String message;
  final bool requiresUserInput;
  final ConflictAction? actionTaken;
  final List<String> additionalFiles;

  ConflictResolutionResult({
    this.conflictId,
    required this.success,
    required this.message,
    this.requiresUserInput = false,
    this.actionTaken,
    this.additionalFiles = const [],
  });

  @override
  String toString() {
    return 'ConflictResolutionResult(success: $success, message: $message, action: $actionTaken)';
  }
}

/// Actions taken during conflict resolution
enum ConflictAction {
  uploadedLocal,
  downloadedRemote,
  deletedLocal,
  deletedRemote,
  keptBoth,
  merged,
}

/// Auto-resolution strategies
enum AutoResolutionStrategy {
  /// Only resolve conflicts that are clearly safe
  conservative,

  /// Prefer local versions when in doubt
  favorLocal,

  /// Prefer remote versions when in doubt
  favorRemote,

  /// Prefer newer versions based on modification time
  favorNewer,

  /// Keep both versions when resolution is unclear
  keepBothWhenUnsure,
}
