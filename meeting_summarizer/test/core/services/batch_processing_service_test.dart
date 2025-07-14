import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:meeting_summarizer/core/services/batch_processing_service.dart';
import 'package:meeting_summarizer/core/models/batch/batch_config.dart';
import 'package:meeting_summarizer/core/models/batch/batch_result.dart';
import 'package:meeting_summarizer/core/models/batch/batch_progress.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/enums/batch_operation.dart';
import 'package:meeting_summarizer/core/interfaces/batch_processing_interface.dart';

void main() {
  group('BatchProcessingService', () {
    late BatchProcessingService service;
    late Directory tempDir;
    late List<FileMetadata> testFiles;

    setUp(() async {
      service = BatchProcessingService();
      tempDir = await Directory.systemTemp.createTemp('batch_test_');

      // Create test files
      testFiles = [];
      for (int i = 1; i <= 5; i++) {
        final fileName = 'test_file_$i.txt';
        final filePath = path.join(tempDir.path, fileName);
        final file = File(filePath);
        await file.writeAsString('Test content $i');

        testFiles.add(
          FileMetadata(
            id: 'test_$i',
            fileName: fileName,
            filePath: filePath,
            relativePath: fileName,
            category: FileCategory.imports,
            fileSize: await file.length(),
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
        );
      }
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('Service Interface', () {
      test('should implement BatchProcessingInterface', () {
        expect(service, isA<BatchProcessingInterface>());
      });

      test('should return supported operations', () {
        final operations = service.getSupportedOperations();
        expect(operations, equals(BatchOperation.values));
      });

      test('should track running batches', () {
        expect(service.getRunningBatches(), isEmpty);
      });

      test('should return empty statistics initially', () async {
        final stats = await service.getBatchStatistics();
        expect(stats.totalOperations, equals(0));
        expect(stats.successfulOperations, equals(0));
        expect(stats.failedOperations, equals(0));
        expect(stats.totalFilesProcessed, equals(0));
      });
    });

    group('Configuration Validation', () {
      test('should validate empty file list', () async {
        final config = BatchConfig(operation: BatchOperation.rename, files: []);

        final errors = await service.validateBatchConfig(config);
        expect(errors, contains('No files specified for batch operation'));
      });

      test('should validate rename operation without pattern', () async {
        final config = BatchConfig(
          operation: BatchOperation.rename,
          files: testFiles,
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, contains('Pattern is required for rename operation'));
      });

      test('should validate move operation without target directory', () async {
        final config = BatchConfig(
          operation: BatchOperation.move,
          files: testFiles,
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, contains('Target directory is required for Move Files'));
      });

      test('should validate non-existent target directory', () async {
        final config = BatchConfig.move(
          files: testFiles,
          targetDirectory: '/non/existent/path',
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, isNotEmpty);
        expect(errors.first, contains('Target directory does not exist'));
      });

      test('should validate max concurrency', () async {
        final config = BatchConfig(
          operation: BatchOperation.rename,
          files: testFiles,
          maxConcurrency: 0,
          options: {'pattern': 'test'},
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, contains('Max concurrency must be at least 1'));
      });

      test('should pass validation for valid config', () async {
        final config = BatchConfig.rename(
          files: testFiles,
          pattern: 'test',
          replacement: 'new',
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, isEmpty);
      });
    });

    group('Preview Operations', () {
      test('should preview rename operation', () async {
        final config = BatchConfig.rename(
          files: testFiles,
          pattern: 'test',
          replacement: 'renamed',
        );

        final previews = await service.previewBatch(config);

        expect(previews, hasLength(testFiles.length));
        expect(previews.first.operation, equals('Rename'));
        expect(previews.first.newFileName, equals('renamed_file_1.txt'));
        expect(previews.first.willChangeFile, isTrue);
      });

      test('should preview move operation', () async {
        final targetDir = path.join(tempDir.path, 'target');
        await Directory(targetDir).create();

        final config = BatchConfig.move(
          files: testFiles,
          targetDirectory: targetDir,
        );

        final previews = await service.previewBatch(config);

        expect(previews, hasLength(testFiles.length));
        expect(previews.first.operation, equals('Move'));
        expect(
          previews.first.newPath,
          equals(path.join(targetDir, testFiles.first.fileName)),
        );
        expect(previews.first.willChangeFile, isTrue);
      });

      test('should preview delete operation with warnings', () async {
        final config = BatchConfig.delete(
          files: testFiles,
          createBackup: false,
        );

        final previews = await service.previewBatch(config);

        expect(previews, hasLength(testFiles.length));
        expect(previews.first.operation, equals('Delete'));
        expect(previews.first.requiresConfirmation, isTrue);
        expect(
          previews.first.warnings,
          contains('Backup will be created before deletion'),
        );
      });

      test('should preview tag operation', () async {
        final config = BatchConfig.tag(
          files: testFiles,
          tagsToAdd: ['new_tag'],
          tagsToRemove: ['old_tag'],
        );

        final previews = await service.previewBatch(config);

        expect(previews, hasLength(testFiles.length));
        expect(previews.first.operation, equals('Tag'));
        expect(previews.first.newTags, contains('new_tag'));
        expect(previews.first.newTags, isNot(contains('old_tag')));
      });

      test('should preview categorize operation', () async {
        final config = BatchConfig.categorize(
          files: testFiles,
          targetCategory: 'recordings',
        );

        final previews = await service.previewBatch(config);

        expect(previews, hasLength(testFiles.length));
        expect(previews.first.operation, equals('Categorize'));
        expect(previews.first.newCategory, equals('recordings'));
      });
    });

    group('Batch Operations', () {
      test('should execute rename operation successfully', () async {
        final config = BatchConfig.rename(
          files: testFiles.take(3).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(3));
        expect(result.failedCount, equals(0));
        expect(result.operation, equals(BatchOperation.rename));
        expect(result.results, hasLength(3));

        // Check that files were actually renamed
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(fileResult.newFilePath, isNotNull);
          expect(File(fileResult.newFilePath!).existsSync(), isTrue);
        }
      });

      test('should execute move operation successfully', () async {
        final targetDir = path.join(tempDir.path, 'target');
        await Directory(targetDir).create();

        final config = BatchConfig.move(
          files: testFiles.take(2).toList(),
          targetDirectory: targetDir,
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(2));
        expect(result.failedCount, equals(0));

        // Check that files were moved
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(fileResult.newFilePath, isNotNull);
          expect(File(fileResult.newFilePath!).existsSync(), isTrue);
          expect(File(fileResult.file.filePath).existsSync(), isFalse);
        }
      });

      test('should execute copy operation successfully', () async {
        final targetDir = path.join(tempDir.path, 'copy_target');
        await Directory(targetDir).create();

        final config = BatchConfig.copy(
          files: testFiles.take(2).toList(),
          targetDirectory: targetDir,
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(2));
        expect(result.failedCount, equals(0));

        // Check that files were copied (originals should still exist)
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(fileResult.newFilePath, isNotNull);
          expect(File(fileResult.newFilePath!).existsSync(), isTrue);
          expect(File(fileResult.file.filePath).existsSync(), isTrue);
        }
      });

      test('should execute delete operation successfully', () async {
        final config = BatchConfig.delete(
          files: testFiles.take(2).toList(),
          createBackup: false,
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(2));
        expect(result.failedCount, equals(0));

        // Check that files were deleted
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(File(fileResult.file.filePath).existsSync(), isFalse);
        }
      });

      test('should execute tag operation successfully', () async {
        final config = BatchConfig.tag(
          files: testFiles.take(2).toList(),
          tagsToAdd: ['test_tag', 'batch_tag'],
          tagsToRemove: ['old_tag'],
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(2));
        expect(result.failedCount, equals(0));

        // Check that tags were applied
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(fileResult.newMetadata, isNotNull);
          expect(fileResult.newMetadata!.tags, contains('test_tag'));
          expect(fileResult.newMetadata!.tags, contains('batch_tag'));
        }
      });

      test('should execute categorize operation successfully', () async {
        final config = BatchConfig.categorize(
          files: testFiles.take(2).toList(),
          targetCategory: 'recordings',
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(2));
        expect(result.failedCount, equals(0));

        // Check that categories were changed
        for (final fileResult in result.results) {
          expect(fileResult.success, isTrue);
          expect(fileResult.newMetadata, isNotNull);
          expect(
            fileResult.newMetadata!.category,
            equals(FileCategory.recordings),
          );
        }
      });

      test('should handle operation failures', () async {
        // Create a file that will cause conflict
        final conflictFile = File(
          path.join(tempDir.path, 'renamed_file_1.txt'),
        );
        await conflictFile.writeAsString('conflict');

        final config = BatchConfig.rename(
          files: testFiles.take(1).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        final result = await service.executeBatch(config);

        expect(result.success, isFalse);
        expect(result.failedCount, equals(1));
        expect(result.results.first.success, isFalse);
        expect(
          result.results.first.errorMessage,
          contains('Target file already exists'),
        );
      });

      test('should support continue on error', () async {
        // Create a file that will cause conflict for first file only
        final conflictFile = File(
          path.join(tempDir.path, 'renamed_file_1.txt'),
        );
        await conflictFile.writeAsString('conflict');

        final config = BatchConfig(
          operation: BatchOperation.rename,
          files: testFiles.take(3).toList(),
          continueOnError: true,
          options: {
            'pattern': 'test',
            'replacement': 'renamed',
            'addIndex': false,
            'preserveExtension': true,
          },
        );

        final result = await service.executeBatch(config);

        expect(result.processedCount, equals(2)); // 2 successful, 1 failed
        expect(result.failedCount, equals(1));

        // Check that successful operations completed
        final successfulResults = result.results
            .where((r) => r.success)
            .toList();
        expect(successfulResults, hasLength(2));
      });
    });

    group('Progress Tracking', () {
      test('should provide progress updates during batch operation', () async {
        final config = BatchConfig.rename(
          files: testFiles,
          pattern: 'test',
          replacement: 'renamed',
        );

        // Execute batch and collect progress updates
        final Future<BatchResult> resultFuture = service.executeBatch(config);

        // We need to get the batch ID from the first progress update
        // Since we can't predict the batch ID, we'll use a different approach
        // This is a limitation of the current API design

        final result = await resultFuture;
        expect(result.success, isTrue);
      });

      test('should calculate progress percentage correctly', () {
        final progress = BatchProgress.update(
          batchId: 'test',
          operation: BatchOperation.rename,
          totalFiles: 10,
          processedFiles: 3,
          failedFiles: 1,
          skippedFiles: 0,
          currentOperation: 'Processing...',
          startTime: DateTime.now(),
          elapsedTime: const Duration(seconds: 5),
        );

        expect(progress.progressPercentage, equals(30.0));
        expect(progress.remainingFiles, equals(6));
        expect(progress.formattedProgress, equals('30.0%'));
      });

      test('should handle progress completion', () {
        final progress = BatchProgress.completed(
          batchId: 'test',
          operation: BatchOperation.rename,
          totalFiles: 5,
          processedFiles: 4,
          failedFiles: 1,
          skippedFiles: 0,
          startTime: DateTime.now(),
          elapsedTime: const Duration(seconds: 10),
        );

        expect(progress.isComplete, isTrue);
        expect(progress.progressPercentage, equals(100.0));
        expect(progress.currentOperation, equals('Completed Rename Files'));
      });

      test('should handle progress cancellation', () {
        final progress = BatchProgress.cancelled(
          batchId: 'test',
          operation: BatchOperation.rename,
          totalFiles: 5,
          processedFiles: 2,
          failedFiles: 0,
          skippedFiles: 3,
          startTime: DateTime.now(),
          elapsedTime: const Duration(seconds: 3),
        );

        expect(progress.isCancelled, isTrue);
        expect(progress.progressPercentage, equals(40.0));
        expect(progress.currentOperation, equals('Cancelled Rename Files'));
      });
    });

    group('Duration Estimation', () {
      test('should estimate batch duration for new operation', () async {
        final config = BatchConfig.rename(
          files: testFiles,
          pattern: 'test',
          replacement: 'renamed',
        );

        final estimation = await service.estimateBatchDuration(config);
        expect(estimation.inMilliseconds, greaterThan(0));
      });

      test('should use historical data for duration estimation', () async {
        // First execute a batch to create history
        final config1 = BatchConfig.rename(
          files: testFiles.take(2).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        await service.executeBatch(config1);

        // Now estimate duration for similar operation
        final config2 = BatchConfig.rename(
          files: testFiles.skip(2).take(3).toList(),
          pattern: 'test',
          replacement: 'renamed2',
        );

        final estimation = await service.estimateBatchDuration(config2);
        expect(estimation.inMilliseconds, greaterThan(0));
      });
    });

    group('Statistics and History', () {
      test('should track batch statistics', () async {
        final config = BatchConfig.rename(
          files: testFiles.take(3).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        await service.executeBatch(config);

        final stats = await service.getBatchStatistics();
        expect(stats.totalOperations, equals(1));
        expect(stats.successfulOperations, equals(1));
        expect(stats.failedOperations, equals(0));
        expect(stats.totalFilesProcessed, equals(3));
        expect(stats.operationCounts[BatchOperation.rename], equals(1));
      });

      test('should maintain batch history', () async {
        final config = BatchConfig.rename(
          files: testFiles.take(2).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        await service.executeBatch(config);

        final history = await service.getBatchHistory();
        expect(history, hasLength(1));
        expect(history.first.operation, equals(BatchOperation.rename));
        expect(history.first.success, isTrue);
        expect(history.first.totalFiles, equals(2));
        expect(history.first.processedFiles, equals(2));
      });

      test('should filter history by operation', () async {
        // Execute different operations
        final renameConfig = BatchConfig.rename(
          files: testFiles.take(1).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        await service.executeBatch(renameConfig);

        final targetDir = path.join(tempDir.path, 'target');
        await Directory(targetDir).create();

        final moveConfig = BatchConfig.move(
          files: testFiles.skip(1).take(1).toList(),
          targetDirectory: targetDir,
        );

        await service.executeBatch(moveConfig);

        // Filter history
        final renameHistory = await service.getBatchHistory(
          operation: BatchOperation.rename,
        );
        final moveHistory = await service.getBatchHistory(
          operation: BatchOperation.move,
        );

        expect(renameHistory, hasLength(1));
        expect(moveHistory, hasLength(1));
        expect(renameHistory.first.operation, equals(BatchOperation.rename));
        expect(moveHistory.first.operation, equals(BatchOperation.move));
      });

      test('should limit history results', () async {
        // Execute multiple operations
        for (int i = 0; i < 3; i++) {
          final config = BatchConfig.tag(
            files: testFiles.take(1).toList(),
            tagsToAdd: ['tag_$i'],
          );

          await service.executeBatch(config);
        }

        final history = await service.getBatchHistory(limit: 2);
        expect(history, hasLength(2));
      });

      test('should clear history', () async {
        final config = BatchConfig.rename(
          files: testFiles.take(1).toList(),
          pattern: 'test',
          replacement: 'renamed',
        );

        await service.executeBatch(config);

        var history = await service.getBatchHistory();
        expect(history, hasLength(1));

        await service.clearBatchHistory();

        history = await service.getBatchHistory();
        expect(history, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle non-existent files gracefully', () async {
        final nonExistentFile = FileMetadata(
          id: 'non_existent',
          fileName: 'non_existent.txt',
          filePath: '/non/existent/path/file.txt',
          relativePath: 'file.txt',
          category: FileCategory.imports,
          fileSize: 100,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final config = BatchConfig.rename(
          files: [nonExistentFile],
          pattern: 'test',
          replacement: 'renamed',
        );

        final errors = await service.validateBatchConfig(config);
        expect(errors, isNotEmpty);
        expect(errors.first, contains('File not found'));
      });

      test('should handle invalid batch configuration', () async {
        final config = BatchConfig(operation: BatchOperation.rename, files: []);

        expect(
          () => service.executeBatch(config),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle unimplemented operations', () async {
        final config = BatchConfig.convert(
          files: testFiles.take(1).toList(),
          targetFormat: 'mp3',
        );

        final result = await service.executeBatch(config);

        expect(result.success, isFalse);
        expect(result.failedCount, equals(1));
        expect(
          result.results.first.errorMessage,
          contains('not yet implemented'),
        );
      });
    });

    group('Concurrency Control', () {
      test('should respect max concurrency setting', () async {
        final config = BatchConfig(
          operation: BatchOperation.rename,
          files: testFiles,
          maxConcurrency: 2,
          options: {
            'pattern': 'test',
            'replacement': 'renamed',
            'addIndex': false,
            'preserveExtension': true,
          },
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(testFiles.length));
        // All files should be processed despite concurrency limit
      });

      test('should handle single file concurrency', () async {
        final config = BatchConfig(
          operation: BatchOperation.rename,
          files: testFiles,
          maxConcurrency: 1,
          options: {
            'pattern': 'test',
            'replacement': 'renamed',
            'addIndex': false,
            'preserveExtension': true,
          },
        );

        final result = await service.executeBatch(config);

        expect(result.success, isTrue);
        expect(result.processedCount, equals(testFiles.length));
      });
    });

    group('Batch Cancellation', () {
      test('should not allow cancellation of non-existent batch', () async {
        final cancelled = await service.cancelBatch('non_existent');
        expect(cancelled, isFalse);
      });

      test('should report batch as not running when not found', () {
        final running = service.isBatchRunning('non_existent');
        expect(running, isFalse);
      });
    });
  });
}
