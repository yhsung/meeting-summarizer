import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/preview_service.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/preview/preview_config.dart';
import 'package:meeting_summarizer/core/enums/preview_type.dart';
import 'package:meeting_summarizer/core/enums/thumbnail_size.dart';
import 'dart:io';

void main() {
  group('PreviewService', () {
    late PreviewService previewService;
    late Directory tempDir;

    setUp(() async {
      // Create temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('preview_test_');
      previewService = await PreviewService.create(
        cacheDirectory: tempDir.path,
        memoryCacheLimit: 10,
      );
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Preview Type Detection', () {
      test('should detect image preview type', () {
        final file = FileMetadata(
          id: 'test1',
          fileName: 'image.jpg',
          filePath: '/test/image.jpg',
          relativePath: 'test/image.jpg',
          category: FileCategory.imports,
          fileSize: 1024,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final type = previewService.getPreviewType(file);
        expect(type, equals(PreviewType.image));
      });

      test('should detect video preview type', () {
        final file = FileMetadata(
          id: 'test2',
          fileName: 'video.mp4',
          filePath: '/test/video.mp4',
          relativePath: 'test/video.mp4',
          category: FileCategory.imports,
          fileSize: 1048576,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final type = previewService.getPreviewType(file);
        expect(type, equals(PreviewType.video));
      });

      test('should detect PDF preview type', () {
        final file = FileMetadata(
          id: 'test3',
          fileName: 'document.pdf',
          filePath: '/test/document.pdf',
          relativePath: 'test/document.pdf',
          category: FileCategory.imports,
          fileSize: 2048,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final type = previewService.getPreviewType(file);
        expect(type, equals(PreviewType.pdf));
      });

      test('should detect text preview type', () {
        final file = FileMetadata(
          id: 'test4',
          fileName: 'document.txt',
          filePath: '/test/document.txt',
          relativePath: 'test/document.txt',
          category: FileCategory.imports,
          fileSize: 512,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final type = previewService.getPreviewType(file);
        expect(type, equals(PreviewType.text));
      });

      test('should detect unsupported preview type', () {
        final file = FileMetadata(
          id: 'test5',
          fileName: 'unknown.xyz',
          filePath: '/test/unknown.xyz',
          relativePath: 'test/unknown.xyz',
          category: FileCategory.imports,
          fileSize: 256,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final type = previewService.getPreviewType(file);
        expect(type, equals(PreviewType.unsupported));
      });
    });

    group('Preview Support', () {
      test('should support image files', () {
        final file = FileMetadata(
          id: 'test6',
          fileName: 'image.png',
          filePath: '/test/image.png',
          relativePath: 'test/image.png',
          category: FileCategory.imports,
          fileSize: 1024,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        expect(previewService.canPreview(file), isTrue);
      });

      test('should not support unsupported files', () {
        final file = FileMetadata(
          id: 'test7',
          fileName: 'unknown.xyz',
          filePath: '/test/unknown.xyz',
          relativePath: 'test/unknown.xyz',
          category: FileCategory.imports,
          fileSize: 256,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        expect(previewService.canPreview(file), isFalse);
      });
    });

    group('Preview Generation', () {
      test('should fail gracefully for non-existent files', () async {
        final file = FileMetadata(
          id: 'test8',
          fileName: 'nonexistent.jpg',
          filePath: '/nonexistent/path.jpg',
          relativePath: 'nonexistent/path.jpg',
          category: FileCategory.imports,
          fileSize: 1024,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final config = PreviewConfig.image(thumbnailSize: ThumbnailSize.small);
        final result = await previewService.generatePreview(file, config);

        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.type, equals(PreviewType.image));
      });

      test('should return error for unsupported file types', () async {
        final file = FileMetadata(
          id: 'test9',
          fileName: 'unsupported.xyz',
          filePath: '/test/unsupported.xyz',
          relativePath: 'test/unsupported.xyz',
          category: FileCategory.imports,
          fileSize: 256,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );

        final config = PreviewConfig(
          type: PreviewType.unsupported,
          thumbnailSize: ThumbnailSize.medium,
        );
        final result = await previewService.generatePreview(file, config);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Unsupported file type'));
      });
    });

    group('Cache Management', () {
      test('should return null for non-existent cache', () async {
        final cached = await previewService.getCachedPreview(
          'nonexistent',
          ThumbnailSize.medium,
        );

        expect(cached, isNull);
      });

      test('should clear cache for specific file', () async {
        // This test verifies the cache clearing mechanism
        await previewService.clearCache('test_file_id');

        // Verify that no cache exists for this file
        final cached = await previewService.getCachedPreview(
          'test_file_id',
          ThumbnailSize.medium,
        );
        expect(cached, isNull);
      });

      test('should clear all caches', () async {
        await previewService.clearAllCaches();

        // After clearing all caches, should have empty cache
        final stats = await previewService.getCacheStats();
        expect(stats.cachedThumbnails, equals(0));
      });

      test('should get cache statistics', () async {
        final stats = await previewService.getCacheStats();

        expect(stats.totalFiles, isA<int>());
        expect(stats.cachedThumbnails, isA<int>());
        expect(stats.totalSizeBytes, isA<int>());
        expect(stats.averageSizeBytes, isA<int>());
        expect(stats.lastCleanup, isA<DateTime>());
      });

      test('should cleanup old cache files', () async {
        // This test verifies that cleanup runs without errors
        await previewService.cleanupCache();

        // Should complete without throwing exceptions
        expect(true, isTrue);
      });
    });

    group('Supported Formats', () {
      test('should return list of supported formats', () {
        final formats = previewService.getSupportedTypes();

        expect(formats, isA<List<PreviewType>>());
        expect(formats, contains(PreviewType.image));
        expect(formats, contains(PreviewType.video));
        expect(formats, contains(PreviewType.pdf));
        expect(formats, contains(PreviewType.audio));
        expect(formats, contains(PreviewType.text));
        expect(formats, isNot(contains(PreviewType.unsupported)));
      });
    });

    group('Generation Tracking', () {
      test('should track generation state', () {
        expect(previewService.isGenerating('test_file'), isFalse);
      });

      test('should cancel generation', () async {
        final result = await previewService.cancelGeneration('test_file');
        expect(
          result,
          isFalse,
        ); // Should return false for non-existent generation
      });

      test('should provide generation progress stream', () {
        final progressStream = previewService.getGenerationProgress();
        expect(progressStream, isA<Stream>());
      });
    });

    group('Batch Operations', () {
      test('should generate previews for multiple files', () async {
        final files = [
          FileMetadata(
            id: 'batch1',
            fileName: 'file1.jpg',
            filePath: '/test/file1.jpg',
            relativePath: 'test/file1.jpg',
            category: FileCategory.imports,
            fileSize: 1024,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
          FileMetadata(
            id: 'batch2',
            fileName: 'file2.png',
            filePath: '/test/file2.png',
            relativePath: 'test/file2.png',
            category: FileCategory.imports,
            fileSize: 2048,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
        ];

        final config = PreviewConfig.image();
        final results = await previewService.generatePreviews(files, config);

        expect(results.length, equals(2));
        expect(results[0].type, equals(PreviewType.image));
        expect(results[1].type, equals(PreviewType.image));
      });

      test('should pre-generate thumbnails with progress callback', () async {
        final files = [
          FileMetadata(
            id: 'pregenerate1',
            fileName: 'file1.jpg',
            filePath: '/test/file1.jpg',
            relativePath: 'test/file1.jpg',
            category: FileCategory.imports,
            fileSize: 1024,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
        ];

        int progressCalls = 0;
        await previewService.preGenerateThumbnails(
          files,
          size: ThumbnailSize.small,
          onProgress: (processed, total) {
            progressCalls++;
            expect(processed, lessThanOrEqualTo(total));
          },
        );

        expect(progressCalls, greaterThan(0));
      });
    });
  });

  group('PreviewConfig', () {
    test('should create image config with defaults', () {
      final config = PreviewConfig.image();

      expect(config.type, equals(PreviewType.image));
      expect(config.thumbnailSize, equals(ThumbnailSize.medium));
      expect(config.quality, equals(85));
      expect(config.enableCache, isTrue);
    });

    test('should create video config with custom options', () {
      final config = PreviewConfig.video(
        thumbnailSize: ThumbnailSize.large,
        quality: 60,
        timeMs: 5000,
      );

      expect(config.type, equals(PreviewType.video));
      expect(config.thumbnailSize, equals(ThumbnailSize.large));
      expect(config.quality, equals(60));
      expect(config.typeSpecificOptions['timeMs'], equals(5000));
    });

    test('should create PDF config with page option', () {
      final config = PreviewConfig.pdf(page: 2);

      expect(config.type, equals(PreviewType.pdf));
      expect(config.typeSpecificOptions['page'], equals(2));
    });

    test('should provide default cache expiry for different types', () {
      final imageConfig = PreviewConfig.image();
      final videoConfig = PreviewConfig.video();
      final textConfig = PreviewConfig.text();

      expect(imageConfig.defaultCacheExpiry, equals(const Duration(days: 7)));
      expect(videoConfig.defaultCacheExpiry, equals(const Duration(days: 3)));
      expect(textConfig.defaultCacheExpiry, equals(const Duration(hours: 12)));
    });

    test('should copy config with modifications', () {
      final original = PreviewConfig.image();
      final modified = original.copyWith(
        thumbnailSize: ThumbnailSize.large,
        quality: 90,
      );

      expect(modified.type, equals(original.type));
      expect(modified.thumbnailSize, equals(ThumbnailSize.large));
      expect(modified.quality, equals(90));
      expect(modified.enableCache, equals(original.enableCache));
    });
  });

  group('PreviewType', () {
    test('should determine preview type from file extension', () {
      expect(PreviewType.fromExtension('.jpg'), equals(PreviewType.image));
      expect(PreviewType.fromExtension('.mp4'), equals(PreviewType.video));
      expect(PreviewType.fromExtension('.pdf'), equals(PreviewType.pdf));
      expect(PreviewType.fromExtension('.txt'), equals(PreviewType.text));
      expect(PreviewType.fromExtension('.zip'), equals(PreviewType.archive));
      expect(
        PreviewType.fromExtension('.xyz'),
        equals(PreviewType.unsupported),
      );
    });

    test('should check thumbnail support capabilities', () {
      expect(PreviewType.image.supportsThumbnails, isTrue);
      expect(PreviewType.video.supportsThumbnails, isTrue);
      expect(PreviewType.pdf.supportsThumbnails, isTrue);
      expect(PreviewType.audio.supportsThumbnails, isFalse);
      expect(PreviewType.text.supportsThumbnails, isFalse);
    });

    test('should check zoom support capabilities', () {
      expect(PreviewType.image.supportsZoom, isTrue);
      expect(PreviewType.pdf.supportsZoom, isTrue);
      expect(PreviewType.video.supportsZoom, isFalse);
      expect(PreviewType.audio.supportsZoom, isFalse);
    });

    test('should check fullscreen support capabilities', () {
      expect(PreviewType.image.supportsFullscreen, isTrue);
      expect(PreviewType.video.supportsFullscreen, isTrue);
      expect(PreviewType.pdf.supportsFullscreen, isTrue);
      expect(PreviewType.audio.supportsFullscreen, isFalse);
    });
  });

  group('ThumbnailSize', () {
    test('should provide correct size values', () {
      expect(ThumbnailSize.small.size, equals(64));
      expect(ThumbnailSize.medium.size, equals(128));
      expect(ThumbnailSize.large.size, equals(256));
      expect(ThumbnailSize.extraLarge.size, equals(512));
    });

    test('should determine size from integer value', () {
      expect(ThumbnailSize.fromSize(50), equals(ThumbnailSize.small));
      expect(ThumbnailSize.fromSize(100), equals(ThumbnailSize.medium));
      expect(ThumbnailSize.fromSize(200), equals(ThumbnailSize.large));
      expect(ThumbnailSize.fromSize(400), equals(ThumbnailSize.extraLarge));
    });

    test('should determine size for context', () {
      expect(ThumbnailSize.forContext('list'), equals(ThumbnailSize.small));
      expect(ThumbnailSize.forContext('grid'), equals(ThumbnailSize.medium));
      expect(ThumbnailSize.forContext('detail'), equals(ThumbnailSize.large));
      expect(
        ThumbnailSize.forContext('preview'),
        equals(ThumbnailSize.extraLarge),
      );
      expect(ThumbnailSize.forContext('unknown'), equals(ThumbnailSize.medium));
    });

    test('should provide size multipliers', () {
      expect(ThumbnailSize.small.sizeMultiplier, equals(0.25));
      expect(ThumbnailSize.medium.sizeMultiplier, equals(1.0));
      expect(ThumbnailSize.large.sizeMultiplier, equals(4.0));
      expect(ThumbnailSize.extraLarge.sizeMultiplier, equals(16.0));
    });
  });
}
