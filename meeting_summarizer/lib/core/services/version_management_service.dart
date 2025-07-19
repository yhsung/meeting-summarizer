import 'dart:developer';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_conflict.dart';
import '../database/database_helper.dart';

/// Service for managing file versions and tracking changes
class VersionManagementService {
  static VersionManagementService? _instance;
  static VersionManagementService get instance =>
      _instance ??= VersionManagementService._();
  VersionManagementService._();

  Database? _database;

  /// Initialize the version management service
  Future<void> initialize() async {
    try {
      _database = await DatabaseHelper().database;
      await _createVersionTables();
      log('VersionManagementService: Initialized successfully');
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Record a new file version
  Future<String> recordFileVersion({
    required String filePath,
    required CloudProvider provider,
    required FileVersion version,
    String? previousVersionId,
    VersionChangeType changeType = VersionChangeType.modified,
  }) async {
    try {
      if (_database == null) await initialize();

      final versionId = _generateVersionId();
      final now = DateTime.now();

      await _database!.insert('file_versions', {
        'id': versionId,
        'file_path': filePath,
        'provider_id': provider.id,
        'size': version.size,
        'checksum': version.checksum,
        'mime_type': version.mimeType,
        'modified_at': version.modifiedAt.toIso8601String(),
        'recorded_at': now.toIso8601String(),
        'change_type': changeType.name,
        'previous_version_id': previousVersionId,
        'exists': version.exists ? 1 : 0,
        'metadata': _serializeMetadata(version.metadata),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      log(
        'VersionManagementService: Recorded version $versionId for $filePath',
      );
      return versionId;
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Error recording version: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the latest version for a file
  Future<FileVersionRecord?> getLatestVersion({
    required String filePath,
    CloudProvider? provider,
  }) async {
    try {
      if (_database == null) await initialize();

      String whereClause = 'file_path = ?';
      List<dynamic> whereArgs = [filePath];

      if (provider != null) {
        whereClause += ' AND provider_id = ?';
        whereArgs.add(provider.id);
      }

      final results = await _database!.query(
        'file_versions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'recorded_at DESC',
        limit: 1,
      );

      if (results.isEmpty) return null;

      return FileVersionRecord.fromMap(results.first);
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Error getting latest version: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get version history for a file
  Future<List<FileVersionRecord>> getVersionHistory({
    required String filePath,
    CloudProvider? provider,
    int limit = 50,
  }) async {
    try {
      if (_database == null) await initialize();

      String whereClause = 'file_path = ?';
      List<dynamic> whereArgs = [filePath];

      if (provider != null) {
        whereClause += ' AND provider_id = ?';
        whereArgs.add(provider.id);
      }

      final results = await _database!.query(
        'file_versions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'recorded_at DESC',
        limit: limit,
      );

      return results.map((map) => FileVersionRecord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Error getting version history: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Detect changes by comparing current file state with last recorded version
  Future<VersionChangeResult> detectChanges({
    required String filePath,
    required CloudProvider provider,
    required FileVersion currentVersion,
  }) async {
    try {
      final latestRecord = await getLatestVersion(
        filePath: filePath,
        provider: provider,
      );

      if (latestRecord == null) {
        return VersionChangeResult(
          hasChanges: true,
          changeType: VersionChangeType.created,
          description: 'New file detected',
        );
      }

      final lastVersion = latestRecord.toFileVersion();

      // Check if file was deleted
      if (!currentVersion.exists && lastVersion.exists) {
        return VersionChangeResult(
          hasChanges: true,
          changeType: VersionChangeType.deleted,
          description: 'File was deleted',
          previousVersion: lastVersion,
        );
      }

      // Check if file was restored
      if (currentVersion.exists && !lastVersion.exists) {
        return VersionChangeResult(
          hasChanges: true,
          changeType: VersionChangeType.restored,
          description: 'File was restored',
          previousVersion: lastVersion,
        );
      }

      if (!currentVersion.exists && !lastVersion.exists) {
        return VersionChangeResult(
          hasChanges: false,
          changeType: VersionChangeType.noChange,
          description: 'File remains deleted',
        );
      }

      // Compare existing file versions
      final changes = _compareVersions(lastVersion, currentVersion);

      if (changes.isEmpty) {
        return VersionChangeResult(
          hasChanges: false,
          changeType: VersionChangeType.noChange,
          description: 'No changes detected',
        );
      }

      final changeType = _determineChangeType(changes);
      final description = _generateChangeDescription(changes);

      return VersionChangeResult(
        hasChanges: true,
        changeType: changeType,
        description: description,
        previousVersion: lastVersion,
        changes: changes,
      );
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Error detecting changes: $e',
        stackTrace: stackTrace,
      );
      return VersionChangeResult(
        hasChanges: false,
        changeType: VersionChangeType.error,
        description: 'Error detecting changes: $e',
      );
    }
  }

  /// Compare two file versions and return list of changes
  List<FileChange> _compareVersions(FileVersion old, FileVersion current) {
    final changes = <FileChange>[];

    if (old.size != current.size) {
      changes.add(
        FileChange(
          property: 'size',
          oldValue: old.size.toString(),
          newValue: current.size.toString(),
          type: ChangeType.modified,
        ),
      );
    }

    if (old.modifiedAt != current.modifiedAt) {
      changes.add(
        FileChange(
          property: 'modifiedAt',
          oldValue: old.modifiedAt.toIso8601String(),
          newValue: current.modifiedAt.toIso8601String(),
          type: ChangeType.modified,
        ),
      );
    }

    if (old.checksum != current.checksum) {
      changes.add(
        FileChange(
          property: 'checksum',
          oldValue: old.checksum ?? 'null',
          newValue: current.checksum ?? 'null',
          type: ChangeType.modified,
        ),
      );
    }

    if (old.mimeType != current.mimeType) {
      changes.add(
        FileChange(
          property: 'mimeType',
          oldValue: old.mimeType ?? 'null',
          newValue: current.mimeType ?? 'null',
          type: ChangeType.modified,
        ),
      );
    }

    return changes;
  }

  /// Determine the primary change type from a list of changes
  VersionChangeType _determineChangeType(List<FileChange> changes) {
    if (changes.any((c) => c.property == 'checksum')) {
      return VersionChangeType.contentChanged;
    }
    if (changes.any((c) => c.property == 'size')) {
      return VersionChangeType.modified;
    }
    if (changes.any((c) => c.property == 'mimeType')) {
      return VersionChangeType.typeChanged;
    }
    return VersionChangeType.metadataChanged;
  }

  /// Generate human-readable description of changes
  String _generateChangeDescription(List<FileChange> changes) {
    final descriptions = <String>[];

    for (final change in changes) {
      switch (change.property) {
        case 'size':
          final oldSize = int.parse(change.oldValue);
          final newSize = int.parse(change.newValue);
          final diff = newSize - oldSize;
          descriptions.add('Size changed by ${diff > 0 ? '+' : ''}$diff bytes');
          break;
        case 'checksum':
          descriptions.add('Content modified');
          break;
        case 'mimeType':
          descriptions.add(
            'Type changed from ${change.oldValue} to ${change.newValue}',
          );
          break;
        case 'modifiedAt':
          descriptions.add('Modification time updated');
          break;
      }
    }

    return descriptions.join(', ');
  }

  /// Calculate file checksum
  Future<String> calculateFileChecksum(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return '';
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      log('VersionManagementService: Error calculating checksum: $e');
      return '';
    }
  }

  /// Clean up old versions beyond retention period
  Future<int> cleanupOldVersions({
    Duration retentionPeriod = const Duration(days: 90),
    int maxVersionsPerFile = 10,
  }) async {
    try {
      if (_database == null) await initialize();

      final cutoffDate = DateTime.now().subtract(retentionPeriod);

      // Delete versions older than retention period, but keep at least one version per file
      final result = await _database!.delete(
        'file_versions',
        where: '''
          recorded_at < ? AND id NOT IN (
            SELECT id FROM (
              SELECT id, ROW_NUMBER() OVER (
                PARTITION BY file_path, provider_id 
                ORDER BY recorded_at DESC
              ) as rn
              FROM file_versions
            ) ranked WHERE rn <= ?
          )
        ''',
        whereArgs: [cutoffDate.toIso8601String(), maxVersionsPerFile],
      );

      log('VersionManagementService: Cleaned up $result old versions');
      return result;
    } catch (e, stackTrace) {
      log(
        'VersionManagementService: Error cleaning up versions: $e',
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Create necessary database tables
  Future<void> _createVersionTables() async {
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS file_versions (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        size INTEGER NOT NULL,
        checksum TEXT,
        mime_type TEXT,
        modified_at TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        change_type TEXT NOT NULL,
        previous_version_id TEXT,
        exists INTEGER NOT NULL DEFAULT 1,
        metadata TEXT,
        FOREIGN KEY (previous_version_id) REFERENCES file_versions(id)
      )
    ''');

    await _database!.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_versions_path_provider 
      ON file_versions(file_path, provider_id)
    ''');

    await _database!.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_versions_recorded_at 
      ON file_versions(recorded_at)
    ''');
  }

  /// Generate unique version ID
  String _generateVersionId() {
    return 'ver_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Serialize metadata map to JSON string
  String _serializeMetadata(Map<String, dynamic> metadata) {
    try {
      return metadata.toString(); // Simple toString for now
    } catch (e) {
      return '{}';
    }
  }
}

/// Record of a file version stored in the database
class FileVersionRecord {
  final String id;
  final String filePath;
  final String providerId;
  final int size;
  final String? checksum;
  final String? mimeType;
  final DateTime modifiedAt;
  final DateTime recordedAt;
  final VersionChangeType changeType;
  final String? previousVersionId;
  final bool exists;
  final Map<String, dynamic> metadata;

  const FileVersionRecord({
    required this.id,
    required this.filePath,
    required this.providerId,
    required this.size,
    this.checksum,
    this.mimeType,
    required this.modifiedAt,
    required this.recordedAt,
    required this.changeType,
    this.previousVersionId,
    required this.exists,
    this.metadata = const {},
  });

  /// Convert to FileVersion model
  FileVersion toFileVersion() {
    return FileVersion(
      path: filePath,
      size: size,
      modifiedAt: modifiedAt,
      checksum: checksum,
      mimeType: mimeType,
      exists: exists,
      metadata: metadata,
    );
  }

  /// Create from database map
  factory FileVersionRecord.fromMap(Map<String, dynamic> map) {
    return FileVersionRecord(
      id: map['id'] as String,
      filePath: map['file_path'] as String,
      providerId: map['provider_id'] as String,
      size: map['size'] as int,
      checksum: map['checksum'] as String?,
      mimeType: map['mime_type'] as String?,
      modifiedAt: DateTime.parse(map['modified_at'] as String),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      changeType: VersionChangeType.values.firstWhere(
        (type) => type.name == map['change_type'],
      ),
      previousVersionId: map['previous_version_id'] as String?,
      exists: (map['exists'] as int) == 1,
      metadata: {}, // TODO: Parse metadata JSON
    );
  }
}

/// Result of change detection
class VersionChangeResult {
  final bool hasChanges;
  final VersionChangeType changeType;
  final String description;
  final FileVersion? previousVersion;
  final List<FileChange> changes;

  const VersionChangeResult({
    required this.hasChanges,
    required this.changeType,
    required this.description,
    this.previousVersion,
    this.changes = const [],
  });
}

/// Individual file change
class FileChange {
  final String property;
  final String oldValue;
  final String newValue;
  final ChangeType type;

  const FileChange({
    required this.property,
    required this.oldValue,
    required this.newValue,
    required this.type,
  });
}

/// Types of version changes
enum VersionChangeType {
  created,
  modified,
  deleted,
  restored,
  contentChanged,
  typeChanged,
  metadataChanged,
  noChange,
  error,
}

/// Types of individual changes
enum ChangeType { added, modified, removed }
