import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';

void main() {
  group('FileMetadata', () {
    late FileMetadata sampleMetadata;

    setUp(() {
      sampleMetadata = FileMetadata(
        id: 'test-id',
        fileName: 'test_file.wav',
        filePath: '/path/to/test_file.wav',
        relativePath: 'recordings/test_file.wav',
        category: FileCategory.recordings,
        fileSize: 1024,
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        modifiedAt: DateTime(2024, 1, 1, 12, 30, 0),
        accessedAt: DateTime(2024, 1, 1, 13, 0, 0),
        customMetadata: {'quality': 'high', 'duration': 120},
        tags: ['audio', 'meeting', 'important'],
        parentFileId: 'parent-id',
        description: 'Test audio file',
        isArchived: false,
        checksum: 'abc123',
      );
    });

    group('getters', () {
      test('should return correct extension', () {
        expect(sampleMetadata.extension, '.wav');
      });

      test('should return correct base name', () {
        expect(sampleMetadata.baseName, 'test_file');
      });

      test('should return correct directory', () {
        expect(sampleMetadata.directory, '/path/to');
      });

      test('should correctly identify if file has parent', () {
        expect(sampleMetadata.hasParent, true);

        // Create a new metadata without parent since copyWith might not handle null properly
        final orphanFile = FileMetadata(
          id: sampleMetadata.id,
          fileName: sampleMetadata.fileName,
          filePath: sampleMetadata.filePath,
          relativePath: sampleMetadata.relativePath,
          category: sampleMetadata.category,
          fileSize: sampleMetadata.fileSize,
          createdAt: sampleMetadata.createdAt,
          modifiedAt: sampleMetadata.modifiedAt,
          accessedAt: sampleMetadata.accessedAt,
          customMetadata: sampleMetadata.customMetadata,
          tags: sampleMetadata.tags,
          parentFileId: null,
          description: sampleMetadata.description,
          isArchived: sampleMetadata.isArchived,
          checksum: sampleMetadata.checksum,
        );
        expect(orphanFile.hasParent, false);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final updated = sampleMetadata.copyWith(
          description: 'Updated description',
          isArchived: true,
        );

        expect(updated.description, 'Updated description');
        expect(updated.isArchived, true);
        expect(updated.id, sampleMetadata.id); // unchanged
        expect(updated.fileName, sampleMetadata.fileName); // unchanged
      });

      test('should create identical copy when no parameters provided', () {
        final copy = sampleMetadata.copyWith();

        expect(copy.id, sampleMetadata.id);
        expect(copy.fileName, sampleMetadata.fileName);
        expect(copy.description, sampleMetadata.description);
        expect(copy.isArchived, sampleMetadata.isArchived);
      });
    });

    group('JSON serialization', () {
      test('should convert to JSON correctly', () {
        final json = sampleMetadata.toJson();

        expect(json['id'], 'test-id');
        expect(json['fileName'], 'test_file.wav');
        expect(json['category'], 'recordings');
        expect(json['fileSize'], 1024);
        expect(json['createdAt'], '2024-01-01T12:00:00.000');
        expect(json['modifiedAt'], '2024-01-01T12:30:00.000');
        expect(json['accessedAt'], '2024-01-01T13:00:00.000');
        expect(json['customMetadata'], {'quality': 'high', 'duration': 120});
        expect(json['tags'], ['audio', 'meeting', 'important']);
        expect(json['parentFileId'], 'parent-id');
        expect(json['description'], 'Test audio file');
        expect(json['isArchived'], false);
        expect(json['checksum'], 'abc123');
      });

      test('should handle null accessedAt in JSON', () {
        final metadataWithoutAccess = FileMetadata(
          id: sampleMetadata.id,
          fileName: sampleMetadata.fileName,
          filePath: sampleMetadata.filePath,
          relativePath: sampleMetadata.relativePath,
          category: sampleMetadata.category,
          fileSize: sampleMetadata.fileSize,
          createdAt: sampleMetadata.createdAt,
          modifiedAt: sampleMetadata.modifiedAt,
          accessedAt: null, // Explicitly set to null
          customMetadata: sampleMetadata.customMetadata,
          tags: sampleMetadata.tags,
          parentFileId: sampleMetadata.parentFileId,
          description: sampleMetadata.description,
          isArchived: sampleMetadata.isArchived,
          checksum: sampleMetadata.checksum,
        );
        final json = metadataWithoutAccess.toJson();

        expect(json['accessedAt'], null);
      });

      test('should convert from JSON correctly', () {
        final json = sampleMetadata.toJson();
        final restored = FileMetadata.fromJson(json);

        expect(restored.id, sampleMetadata.id);
        expect(restored.fileName, sampleMetadata.fileName);
        expect(restored.filePath, sampleMetadata.filePath);
        expect(restored.category, sampleMetadata.category);
        expect(restored.fileSize, sampleMetadata.fileSize);
        expect(restored.createdAt, sampleMetadata.createdAt);
        expect(restored.modifiedAt, sampleMetadata.modifiedAt);
        expect(restored.accessedAt, sampleMetadata.accessedAt);
        expect(restored.customMetadata, sampleMetadata.customMetadata);
        expect(restored.tags, sampleMetadata.tags);
        expect(restored.parentFileId, sampleMetadata.parentFileId);
        expect(restored.description, sampleMetadata.description);
        expect(restored.isArchived, sampleMetadata.isArchived);
        expect(restored.checksum, sampleMetadata.checksum);
      });

      test('should handle minimal JSON data', () {
        final minimalJson = {
          'id': 'min-id',
          'fileName': 'min.txt',
          'filePath': '/min.txt',
          'relativePath': 'min.txt',
          'category': 'cache',
          'fileSize': 100,
          'createdAt': '2024-01-01T12:00:00.000',
          'modifiedAt': '2024-01-01T12:00:00.000',
        };

        final metadata = FileMetadata.fromJson(minimalJson);

        expect(metadata.id, 'min-id');
        expect(metadata.fileName, 'min.txt');
        expect(metadata.category, FileCategory.cache);
        expect(metadata.accessedAt, null);
        expect(metadata.customMetadata, isEmpty);
        expect(metadata.tags, isEmpty);
        expect(metadata.parentFileId, null);
        expect(metadata.description, null);
        expect(metadata.isArchived, false);
        expect(metadata.checksum, null);
      });
    });

    group('equality and hashCode', () {
      test('should be equal when IDs match', () {
        final other = FileMetadata(
          id: 'test-id', // Same ID
          fileName: 'different_name.mp3', // Different other fields
          filePath: '/different/path.mp3',
          relativePath: 'different/path.mp3',
          category: FileCategory.exports,
          fileSize: 2048,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        expect(sampleMetadata == other, true);
        expect(sampleMetadata.hashCode, other.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final other = sampleMetadata.copyWith(id: 'different-id');

        expect(sampleMetadata == other, false);
        expect(sampleMetadata.hashCode, isNot(other.hashCode));
      });

      test('should be equal to itself', () {
        expect(sampleMetadata == sampleMetadata, true);
        expect(sampleMetadata.hashCode, sampleMetadata.hashCode);
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final string = sampleMetadata.toString();

        expect(string, contains('FileMetadata'));
        expect(string, contains('test-id'));
        expect(string, contains('test_file.wav'));
        expect(string, contains('recordings'));
      });
    });
  });
}
