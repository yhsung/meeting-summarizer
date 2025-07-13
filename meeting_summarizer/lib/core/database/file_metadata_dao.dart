import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';
import 'database_helper.dart';

/// Data Access Object for file metadata storage in SQLite
class FileMetadataDao {
  static const String tableName = 'file_metadata';

  /// SQL for creating the file metadata table
  static const String createTableSql =
      '''
    CREATE TABLE $tableName (
      id TEXT PRIMARY KEY,
      file_name TEXT NOT NULL,
      file_path TEXT NOT NULL UNIQUE,
      relative_path TEXT NOT NULL,
      category TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      modified_at INTEGER NOT NULL,
      accessed_at INTEGER,
      custom_metadata TEXT NOT NULL DEFAULT '{}',
      tags TEXT NOT NULL DEFAULT '[]',
      parent_file_id TEXT,
      description TEXT,
      is_archived INTEGER NOT NULL DEFAULT 0,
      checksum TEXT,
      FOREIGN KEY (parent_file_id) REFERENCES $tableName (id) ON DELETE SET NULL
    )
  ''';

  /// SQL for creating indexes
  static const List<String> createIndexesSql = [
    'CREATE INDEX idx_file_metadata_category ON $tableName (category)',
    'CREATE INDEX idx_file_metadata_created_at ON $tableName (created_at)',
    'CREATE INDEX idx_file_metadata_is_archived ON $tableName (is_archived)',
    'CREATE INDEX idx_file_metadata_parent_file_id ON $tableName (parent_file_id)',
    'CREATE INDEX idx_file_metadata_file_path ON $tableName (file_path)',
  ];

  /// SQL for full-text search virtual table
  static const String createFtsSql =
      '''
    CREATE VIRTUAL TABLE ${tableName}_fts USING fts5(
      id UNINDEXED,
      file_name,
      description,
      tags,
      content=$tableName,
      content_rowid=rowid
    )
  ''';

  /// SQL for FTS triggers
  static const List<String> createFtsTriggersSql = [
    '''
    CREATE TRIGGER ${tableName}_fts_insert AFTER INSERT ON $tableName
    BEGIN
      INSERT INTO ${tableName}_fts(rowid, id, file_name, description, tags)
      VALUES (new.rowid, new.id, new.file_name, new.description, new.tags);
    END
    ''',
    '''
    CREATE TRIGGER ${tableName}_fts_delete AFTER DELETE ON $tableName
    BEGIN
      INSERT INTO ${tableName}_fts(${tableName}_fts, rowid, id, file_name, description, tags)
      VALUES ('delete', old.rowid, old.id, old.file_name, old.description, old.tags);
    END
    ''',
    '''
    CREATE TRIGGER ${tableName}_fts_update AFTER UPDATE ON $tableName
    BEGIN
      INSERT INTO ${tableName}_fts(${tableName}_fts, rowid, id, file_name, description, tags)
      VALUES ('delete', old.rowid, old.id, old.file_name, old.description, old.tags);
      INSERT INTO ${tableName}_fts(rowid, id, file_name, description, tags)
      VALUES (new.rowid, new.id, new.file_name, new.description, new.tags);
    END
    ''',
  ];

  final DatabaseHelper _databaseHelper;

  FileMetadataDao(this._databaseHelper);

  /// Insert or update file metadata
  Future<void> insertOrUpdate(FileMetadata metadata) async {
    final db = await _databaseHelper.database;
    await db.insert(
      tableName,
      _toMap(metadata),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get file metadata by ID
  Future<FileMetadata?> getById(String id) async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  /// Get all files by category
  Future<List<FileMetadata>> getByCategory(
    FileCategory category, {
    bool includeArchived = false,
  }) async {
    final db = await _databaseHelper.database;
    final whereClause = includeArchived
        ? 'category = ?'
        : 'category = ? AND is_archived = 0';

    final results = await db.query(
      tableName,
      where: whereClause,
      whereArgs: [category.name],
      orderBy: 'created_at DESC',
    );

    return results.map(_fromMap).toList();
  }

  /// Get files by tags (using JSON_EXTRACT for SQLite 3.45+, fallback to LIKE)
  Future<List<FileMetadata>> getByTags(
    List<String> tags, {
    bool matchAll = false,
    bool includeArchived = false,
  }) async {
    final db = await _databaseHelper.database;

    // Build WHERE clause for tag matching
    final tagConditions = tags.map((tag) => "tags LIKE '%\"$tag\"%'").toList();
    final tagClause = matchAll
        ? tagConditions.join(' AND ')
        : tagConditions.join(' OR ');

    final archiveClause = includeArchived ? '' : ' AND is_archived = 0';
    final whereClause = '($tagClause)$archiveClause';

    final results = await db.query(
      tableName,
      where: whereClause,
      orderBy: 'created_at DESC',
    );

    return results.map(_fromMap).toList();
  }

  /// Search files using full-text search
  Future<List<FileMetadata>> search({
    String? query,
    List<FileCategory>? categories,
    List<String>? tags,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int? minSize,
    int? maxSize,
    bool includeArchived = false,
    int? limit,
    int? offset,
  }) async {
    final db = await _databaseHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // Archive filter
    if (!includeArchived) {
      whereClauses.add('is_archived = 0');
    }

    // Category filter
    if (categories != null && categories.isNotEmpty) {
      final categoryNames = categories.map((c) => c.name).toList();
      final placeholders = List.filled(categoryNames.length, '?').join(',');
      whereClauses.add('category IN ($placeholders)');
      whereArgs.addAll(categoryNames);
    }

    // Date filters
    if (createdAfter != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(createdAfter.millisecondsSinceEpoch);
    }
    if (createdBefore != null) {
      whereClauses.add('created_at <= ?');
      whereArgs.add(createdBefore.millisecondsSinceEpoch);
    }

    // Size filters
    if (minSize != null) {
      whereClauses.add('file_size >= ?');
      whereArgs.add(minSize);
    }
    if (maxSize != null) {
      whereClauses.add('file_size <= ?');
      whereArgs.add(maxSize);
    }

    // Tag filter
    if (tags != null && tags.isNotEmpty) {
      final tagConditions = tags
          .map((tag) => "tags LIKE '%\"$tag\"%'")
          .toList();
      whereClauses.add('(${tagConditions.join(' OR ')})');
    }

    // Full-text search
    String fromClause = tableName;
    if (query != null && query.isNotEmpty) {
      fromClause =
          '''
        $tableName 
        JOIN ${tableName}_fts ON $tableName.rowid = ${tableName}_fts.rowid
      ''';
      whereClauses.add("${tableName}_fts MATCH ?");
      whereArgs.insert(0, query); // FTS query should be first parameter
    }

    // Build final query
    final whereClause = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;

    final results = await db.query(
      fromClause,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: query != null ? 'rank' : 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return results.map(_fromMap).toList();
  }

  /// Update file metadata
  Future<bool> update(FileMetadata metadata) async {
    final db = await _databaseHelper.database;
    final rowsAffected = await db.update(
      tableName,
      _toMap(metadata),
      where: 'id = ?',
      whereArgs: [metadata.id],
    );
    return rowsAffected > 0;
  }

  /// Delete file metadata
  Future<bool> delete(String id) async {
    final db = await _databaseHelper.database;
    final rowsAffected = await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rowsAffected > 0;
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final db = await _databaseHelper.database;

    // Get overall stats
    final overallStats = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_files,
        SUM(file_size) as total_size,
        COUNT(CASE WHEN is_archived = 1 THEN 1 END) as archived_files,
        SUM(CASE WHEN is_archived = 1 THEN file_size ELSE 0 END) as archived_size
      FROM $tableName
    ''');

    // Get category stats
    final categoryStats = await db.rawQuery('''
      SELECT 
        category,
        COUNT(*) as file_count,
        SUM(file_size) as total_size,
        COUNT(CASE WHEN is_archived = 1 THEN 1 END) as archived_count,
        SUM(CASE WHEN is_archived = 1 THEN file_size ELSE 0 END) as archived_size,
        MIN(created_at) as oldest_file,
        MAX(created_at) as newest_file
      FROM $tableName
      GROUP BY category
    ''');

    return {'overall': overallStats.first, 'categories': categoryStats};
  }

  /// Get files by parent ID
  Future<List<FileMetadata>> getByParentId(String parentId) async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      tableName,
      where: 'parent_file_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at DESC',
    );

    return results.map(_fromMap).toList();
  }

  /// Get orphaned files (files whose parent no longer exists)
  Future<List<FileMetadata>> getOrphanedFiles() async {
    final db = await _databaseHelper.database;
    final results = await db.rawQuery('''
      SELECT f1.* FROM $tableName f1
      LEFT JOIN $tableName f2 ON f1.parent_file_id = f2.id
      WHERE f1.parent_file_id IS NOT NULL AND f2.id IS NULL
    ''');

    return results.map(_fromMap).toList();
  }

  /// Clean up orphaned files
  Future<int> cleanupOrphanedFiles() async {
    final db = await _databaseHelper.database;
    return await db.rawUpdate('''
      UPDATE $tableName 
      SET parent_file_id = NULL 
      WHERE parent_file_id IS NOT NULL 
      AND parent_file_id NOT IN (SELECT id FROM $tableName)
    ''');
  }

  /// Convert FileMetadata to database map
  Map<String, dynamic> _toMap(FileMetadata metadata) {
    return {
      'id': metadata.id,
      'file_name': metadata.fileName,
      'file_path': metadata.filePath,
      'relative_path': metadata.relativePath,
      'category': metadata.category.name,
      'file_size': metadata.fileSize,
      'created_at': metadata.createdAt.millisecondsSinceEpoch,
      'modified_at': metadata.modifiedAt.millisecondsSinceEpoch,
      'accessed_at': metadata.accessedAt?.millisecondsSinceEpoch,
      'custom_metadata': jsonEncode(metadata.customMetadata),
      'tags': jsonEncode(metadata.tags),
      'parent_file_id': metadata.parentFileId,
      'description': metadata.description,
      'is_archived': metadata.isArchived ? 1 : 0,
      'checksum': metadata.checksum,
    };
  }

  /// Convert database map to FileMetadata
  FileMetadata _fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      id: map['id'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      relativePath: map['relative_path'] as String,
      category: FileCategory.values.byName(map['category'] as String),
      fileSize: map['file_size'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['modified_at'] as int,
      ),
      accessedAt: map['accessed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['accessed_at'] as int)
          : null,
      customMetadata: Map<String, dynamic>.from(
        jsonDecode(map['custom_metadata'] as String),
      ),
      tags: List<String>.from(jsonDecode(map['tags'] as String)),
      parentFileId: map['parent_file_id'] as String?,
      description: map['description'] as String?,
      isArchived: (map['is_archived'] as int) == 1,
      checksum: map['checksum'] as String?,
    );
  }
}
