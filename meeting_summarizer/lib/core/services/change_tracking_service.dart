import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/file_change.dart';
import '../database/database_helper.dart';
import 'cloud_providers/cloud_provider_interface.dart';

/// Service for tracking file changes and determining what needs to be synchronized
class ChangeTrackingService {
  static ChangeTrackingService? _instance;
  static ChangeTrackingService get instance =>
      _instance ??= ChangeTrackingService._();
  ChangeTrackingService._();

  static const int _defaultChunkSize = 1024 * 1024; // 1MB chunks
  static const Duration _changeDetectionInterval = Duration(minutes: 5);

  DatabaseHelper? _database;
  Timer? _changeDetectionTimer;
  final Map<String, DateTime> _lastModificationTimes = {};
  final Map<String, String> _lastKnownChecksums = {};
  final StreamController<List<FileChange>> _changesController =
      StreamController<List<FileChange>>.broadcast();

  /// Stream of detected file changes
  Stream<List<FileChange>> get changesStream => _changesController.stream;

  /// Initialize the change tracking service
  Future<void> initialize() async {
    try {
      log('ChangeTrackingService: Initializing...');

      _database = DatabaseHelper();
      await _createChangeTrackingTables();
      await _loadLastKnownStates();

      // Start periodic change detection
      _startChangeDetection();

      log('ChangeTrackingService: Initialization complete');
    } catch (e, stackTrace) {
      log(
        'ChangeTrackingService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Detect changes for a specific file
  Future<FileChange?> detectFileChange({
    required String filePath,
    required CloudProvider provider,
    CloudProviderInterface? providerInterface,
  }) async {
    try {
      final file = File(filePath);
      final fileId = _generateFileId(filePath, provider);

      // Check if file exists
      if (!await file.exists()) {
        // File was deleted
        final lastKnownTime = _lastModificationTimes[fileId];
        if (lastKnownTime != null) {
          _lastModificationTimes.remove(fileId);
          _lastKnownChecksums.remove(fileId);

          return FileChange(
            filePath: filePath,
            fileId: fileId,
            provider: provider,
            changeType: FileChangeType.deleted,
            detectedAt: DateTime.now(),
            lastModified: lastKnownTime,
            fileSize: 0,
          );
        }
        return null; // File never existed in our tracking
      }

      // Get file stats
      final stat = await file.stat();
      final lastKnownTime = _lastModificationTimes[fileId];

      // Check if file is new or modified
      if (lastKnownTime == null) {
        // New file
        final checksum = await _calculateFileChecksum(filePath);
        _lastModificationTimes[fileId] = stat.modified;
        _lastKnownChecksums[fileId] = checksum;

        return FileChange(
          filePath: filePath,
          fileId: fileId,
          provider: provider,
          changeType: FileChangeType.created,
          detectedAt: DateTime.now(),
          lastModified: stat.modified,
          fileSize: stat.size,
          checksum: checksum,
        );
      }

      // Check if file was modified
      if (stat.modified.isAfter(lastKnownTime)) {
        final currentChecksum = await _calculateFileChecksum(filePath);
        final previousChecksum = _lastKnownChecksums[fileId];

        if (currentChecksum != previousChecksum) {
          // File content actually changed
          _lastModificationTimes[fileId] = stat.modified;
          _lastKnownChecksums[fileId] = currentChecksum;

          // Detect changed chunks for delta sync
          final changedChunks = await _detectChangedChunks(
            filePath,
            previousChecksum ?? '',
            currentChecksum,
          );

          return FileChange(
            filePath: filePath,
            fileId: fileId,
            provider: provider,
            changeType: FileChangeType.modified,
            detectedAt: DateTime.now(),
            lastModified: stat.modified,
            fileSize: stat.size,
            checksum: currentChecksum,
            previousChecksum: previousChecksum,
            changedChunks: changedChunks,
          );
        }
      }

      return null; // No changes detected
    } catch (e, stackTrace) {
      log(
        'ChangeTrackingService: Error detecting changes for $filePath: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Detect changes in a directory
  Future<List<FileChange>> detectDirectoryChanges({
    required String directoryPath,
    required CloudProvider provider,
    List<String> fileExtensions = const [],
    bool recursive = true,
  }) async {
    final changes = <FileChange>[];

    try {
      log('ChangeTrackingService: Detecting changes in $directoryPath');

      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        log('ChangeTrackingService: Directory $directoryPath does not exist');
        return changes;
      }

      await for (final entity in directory.list(recursive: recursive)) {
        if (entity is File) {
          // Filter by file extensions if specified
          if (fileExtensions.isNotEmpty) {
            final extension = path.extension(entity.path).toLowerCase();
            if (!fileExtensions.contains(extension)) {
              continue;
            }
          }

          final change = await detectFileChange(
            filePath: entity.path,
            provider: provider,
          );

          if (change != null) {
            changes.add(change);
          }
        }
      }

      log(
        'ChangeTrackingService: Detected ${changes.length} changes in $directoryPath',
      );

      // Emit changes if any were found
      if (changes.isNotEmpty) {
        _changesController.add(changes);
      }

      return changes;
    } catch (e, stackTrace) {
      log(
        'ChangeTrackingService: Error detecting directory changes: $e',
        stackTrace: stackTrace,
      );
      return changes;
    }
  }

  /// Compare local and remote file states to detect changes
  Future<List<FileChange>> compareWithRemote({
    required Map<CloudProvider, CloudProviderInterface> connectedProviders,
    String? specificFilePath,
  }) async {
    final allChanges = <FileChange>[];

    try {
      for (final entry in connectedProviders.entries) {
        final provider = entry.key;
        final providerInterface = entry.value;

        log('ChangeTrackingService: Comparing with ${provider.displayName}');

        if (specificFilePath != null) {
          // Compare specific file
          final change = await _compareFileWithRemote(
            specificFilePath,
            provider,
            providerInterface,
          );
          if (change != null) {
            allChanges.add(change);
          }
        } else {
          // Compare all tracked files
          final trackedFiles = await _getTrackedFiles(provider);
          for (final filePath in trackedFiles) {
            final change = await _compareFileWithRemote(
              filePath,
              provider,
              providerInterface,
            );
            if (change != null) {
              allChanges.add(change);
            }
          }
        }
      }

      log(
        'ChangeTrackingService: Found ${allChanges.length} changes vs remote',
      );

      if (allChanges.isNotEmpty) {
        _changesController.add(allChanges);
      }

      return allChanges;
    } catch (e, stackTrace) {
      log(
        'ChangeTrackingService: Error comparing with remote: $e',
        stackTrace: stackTrace,
      );
      return allChanges;
    }
  }

  /// Start periodic change detection
  void _startChangeDetection() {
    _stopChangeDetection();
    _changeDetectionTimer = Timer.periodic(
      _changeDetectionInterval,
      (_) => _performPeriodicScan(),
    );
    log('ChangeTrackingService: Started periodic change detection');
  }

  /// Stop periodic change detection
  void _stopChangeDetection() {
    _changeDetectionTimer?.cancel();
    _changeDetectionTimer = null;
  }

  /// Perform periodic file system scan
  Future<void> _performPeriodicScan() async {
    try {
      // This would typically scan known directories for changes
      // For now, we'll implement on-demand scanning
      log('ChangeTrackingService: Performing periodic scan...');
    } catch (e) {
      log('ChangeTrackingService: Error in periodic scan: $e');
    }
  }

  /// Calculate file checksum using SHA-256
  Future<String> _calculateFileChecksum(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      log('ChangeTrackingService: Error calculating checksum: $e');
      return '';
    }
  }

  /// Detect which chunks of a file have changed
  Future<List<FileChunk>> _detectChangedChunks(
    String filePath,
    String previousChecksum,
    String currentChecksum,
  ) async {
    final changedChunks = <FileChunk>[];

    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final chunkCount = (fileSize / _defaultChunkSize).ceil();

      // Read file in chunks and calculate checksums
      final randomAccessFile = await file.open();

      for (int i = 0; i < chunkCount; i++) {
        final offset = i * _defaultChunkSize;
        final remainingBytes = fileSize - offset;
        final chunkSize = remainingBytes > _defaultChunkSize
            ? _defaultChunkSize
            : remainingBytes;

        await randomAccessFile.setPosition(offset);
        final chunkData = await randomAccessFile.read(chunkSize);
        final chunkChecksum = sha256.convert(chunkData).toString();

        // For now, mark all chunks as changed (we'd need previous chunk data to compare)
        // In a real implementation, we'd store chunk checksums and compare
        changedChunks.add(
          FileChunk(
            index: i,
            offset: offset,
            size: chunkSize,
            checksum: chunkChecksum,
            isChanged: true, // Simplified for now
            data: chunkData,
          ),
        );
      }

      await randomAccessFile.close();

      log(
        'ChangeTrackingService: Detected ${changedChunks.length} changed chunks for $filePath',
      );
    } catch (e, stackTrace) {
      log(
        'ChangeTrackingService: Error detecting changed chunks: $e',
        stackTrace: stackTrace,
      );
    }

    return changedChunks;
  }

  /// Compare a local file with its remote counterpart
  Future<FileChange?> _compareFileWithRemote(
    String filePath,
    CloudProvider provider,
    CloudProviderInterface providerInterface,
  ) async {
    try {
      final localFile = File(filePath);
      final fileId = _generateFileId(filePath, provider);

      // Check local file
      if (!await localFile.exists()) {
        // Local file was deleted, check if it exists remotely
        if (await providerInterface.fileExists(filePath)) {
          return FileChange(
            filePath: filePath,
            fileId: fileId,
            provider: provider,
            changeType: FileChangeType.deleted,
            detectedAt: DateTime.now(),
            lastModified: DateTime.now(),
            fileSize: 0,
          );
        }
        return null; // File doesn't exist anywhere
      }

      // Check remote file
      if (!await providerInterface.fileExists(filePath)) {
        // Local file exists but not remote - needs upload
        final stat = await localFile.stat();
        final checksum = await _calculateFileChecksum(filePath);

        return FileChange(
          filePath: filePath,
          fileId: fileId,
          provider: provider,
          changeType: FileChangeType.created,
          detectedAt: DateTime.now(),
          lastModified: stat.modified,
          fileSize: stat.size,
          checksum: checksum,
        );
      }

      // Both files exist, compare modification times and sizes
      final localStat = await localFile.stat();
      final remoteSize = await providerInterface.getFileSize(filePath) ?? 0;
      final remoteModTime = await providerInterface.getFileModificationTime(
        filePath,
      );

      if (localStat.size != remoteSize ||
          (remoteModTime != null &&
              localStat.modified.isAfter(remoteModTime))) {
        // Files differ, need to sync
        final checksum = await _calculateFileChecksum(filePath);

        return FileChange(
          filePath: filePath,
          fileId: fileId,
          provider: provider,
          changeType: FileChangeType.modified,
          detectedAt: DateTime.now(),
          lastModified: localStat.modified,
          fileSize: localStat.size,
          checksum: checksum,
        );
      }

      return null; // Files are in sync
    } catch (e) {
      log('ChangeTrackingService: Error comparing file with remote: $e');
      return null;
    }
  }

  /// Create database tables for change tracking
  Future<void> _createChangeTrackingTables() async {
    await _database!.database.then((db) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS file_tracking (
          id TEXT PRIMARY KEY,
          file_path TEXT NOT NULL,
          provider_id TEXT NOT NULL,
          last_modification_time INTEGER NOT NULL,
          last_known_checksum TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          tracked_since INTEGER NOT NULL,
          UNIQUE(file_path, provider_id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_file_tracking_provider 
        ON file_tracking(provider_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_file_tracking_path 
        ON file_tracking(file_path)
      ''');
    });
  }

  /// Load last known file states from database
  Future<void> _loadLastKnownStates() async {
    try {
      final db = await _database!.database;
      final results = await db.query('file_tracking');

      for (final row in results) {
        final fileId = row['id'] as String;
        final modTime = DateTime.fromMillisecondsSinceEpoch(
          row['last_modification_time'] as int,
        );
        final checksum = row['last_known_checksum'] as String;

        _lastModificationTimes[fileId] = modTime;
        _lastKnownChecksums[fileId] = checksum;
      }

      log('ChangeTrackingService: Loaded ${results.length} tracked files');
    } catch (e) {
      log('ChangeTrackingService: Error loading last known states: $e');
    }
  }

  /// Get list of tracked files for a provider
  Future<List<String>> _getTrackedFiles(CloudProvider provider) async {
    try {
      final db = await _database!.database;
      final results = await db.query(
        'file_tracking',
        columns: ['file_path'],
        where: 'provider_id = ?',
        whereArgs: [provider.id],
      );

      return results.map((row) => row['file_path'] as String).toList();
    } catch (e) {
      log('ChangeTrackingService: Error getting tracked files: $e');
      return [];
    }
  }

  /// Generate unique file ID
  String _generateFileId(String filePath, CloudProvider provider) {
    return '${provider.id}_${filePath.hashCode.abs()}';
  }

  /// Record file state in database
  Future<void> recordFileState({
    required String filePath,
    required CloudProvider provider,
    required DateTime modificationTime,
    required String checksum,
    required int fileSize,
  }) async {
    try {
      final db = await _database!.database;
      final fileId = _generateFileId(filePath, provider);

      await db.insert('file_tracking', {
        'id': fileId,
        'file_path': filePath,
        'provider_id': provider.id,
        'last_modification_time': modificationTime.millisecondsSinceEpoch,
        'last_known_checksum': checksum,
        'file_size': fileSize,
        'tracked_since': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Update in-memory cache
      _lastModificationTimes[fileId] = modificationTime;
      _lastKnownChecksums[fileId] = checksum;
    } catch (e) {
      log('ChangeTrackingService: Error recording file state: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _stopChangeDetection();
    await _changesController.close();
    _lastModificationTimes.clear();
    _lastKnownChecksums.clear();
  }
}
