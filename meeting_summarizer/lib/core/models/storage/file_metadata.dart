import 'dart:io';
import 'package:path/path.dart' as path;
import 'file_category.dart';

/// Extended file metadata for organized storage
class FileMetadata {
  final String id;
  final String fileName;
  final String filePath;
  final String relativePath;
  final FileCategory category;
  final int fileSize;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime? accessedAt;
  final Map<String, dynamic> customMetadata;
  final List<String> tags;
  final String? parentFileId;
  final String? description;
  final bool isArchived;
  final String? checksum;

  const FileMetadata({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.relativePath,
    required this.category,
    required this.fileSize,
    required this.createdAt,
    required this.modifiedAt,
    this.accessedAt,
    this.customMetadata = const {},
    this.tags = const [],
    this.parentFileId,
    this.description,
    this.isArchived = false,
    this.checksum,
  });

  /// File extension
  String get extension => path.extension(fileName).toLowerCase();

  /// File name without extension
  String get baseName => path.basenameWithoutExtension(fileName);

  /// Directory containing the file
  String get directory => path.dirname(filePath);

  /// Whether this file is a derivative of another file
  bool get hasParent => parentFileId != null;

  /// Whether this file exists on disk
  Future<bool> exists() async {
    return File(filePath).exists();
  }

  /// Get file size from disk (may differ from stored size)
  Future<int> getCurrentSize() async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Create a copy with updated fields
  FileMetadata copyWith({
    String? id,
    String? fileName,
    String? filePath,
    String? relativePath,
    FileCategory? category,
    int? fileSize,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? accessedAt,
    Map<String, dynamic>? customMetadata,
    List<String>? tags,
    String? parentFileId,
    String? description,
    bool? isArchived,
    String? checksum,
  }) {
    return FileMetadata(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      category: category ?? this.category,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      accessedAt: accessedAt ?? this.accessedAt,
      customMetadata: customMetadata ?? this.customMetadata,
      tags: tags ?? this.tags,
      parentFileId: parentFileId ?? this.parentFileId,
      description: description ?? this.description,
      isArchived: isArchived ?? this.isArchived,
      checksum: checksum ?? this.checksum,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'relativePath': relativePath,
      'category': category.name,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'accessedAt': accessedAt?.toIso8601String(),
      'customMetadata': customMetadata,
      'tags': tags,
      'parentFileId': parentFileId,
      'description': description,
      'isArchived': isArchived,
      'checksum': checksum,
    };
  }

  /// Create from JSON
  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      relativePath: json['relativePath'] as String,
      category: FileCategory.values.byName(json['category'] as String),
      fileSize: json['fileSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      accessedAt: json['accessedAt'] != null
          ? DateTime.parse(json['accessedAt'] as String)
          : null,
      customMetadata: Map<String, dynamic>.from(
        json['customMetadata'] as Map? ?? {},
      ),
      tags: List<String>.from(json['tags'] as List? ?? []),
      parentFileId: json['parentFileId'] as String?,
      description: json['description'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      checksum: json['checksum'] as String?,
    );
  }

  @override
  String toString() {
    return 'FileMetadata(id: $id, fileName: $fileName, category: ${category.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileMetadata && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
