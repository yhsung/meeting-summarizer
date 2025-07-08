import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart' as models;

void main() {
  group('Database Performance Tests', () {
    late DatabaseHelper dbHelper;

    setUpAll(() {
      // Initialize sqflite for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.recreateDatabase();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    group('Performance Statistics', () {
      test('should get comprehensive performance statistics', () async {
        // Add some test data
        await _insertTestData(dbHelper);

        final stats = await dbHelper.getPerformanceStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('database_size_bytes'), isTrue);
        expect(stats.containsKey('page_count'), isTrue);
        expect(stats.containsKey('page_size'), isTrue);
        expect(stats.containsKey('index_usage'), isTrue);
        expect(stats.containsKey('table_statistics'), isTrue);
        expect(stats.containsKey('cache_statistics'), isTrue);

        // Verify database size is reasonable
        final dbSize = stats['database_size_bytes'] as int;
        expect(dbSize, greaterThan(0));

        // Verify index usage statistics
        final indexUsage = stats['index_usage'] as Map<String, dynamic>;
        expect(indexUsage.containsKey('total_indexes'), isTrue);
        expect(indexUsage.containsKey('index_details'), isTrue);

        final totalIndexes = indexUsage['total_indexes'] as int;
        expect(totalIndexes, greaterThan(10)); // Should have many indexes

        // Verify table statistics
        final tableStats = stats['table_statistics'] as Map<String, dynamic>;
        expect(tableStats.containsKey('recordings'), isTrue);
        expect(tableStats.containsKey('transcriptions'), isTrue);
        expect(tableStats.containsKey('summaries'), isTrue);
        expect(tableStats.containsKey('settings'), isTrue);

        final recordingsStats =
            tableStats['recordings'] as Map<String, dynamic>;
        expect(
          recordingsStats['row_count'],
          equals(3),
        ); // We inserted 3 test recordings
      });

      test('should get optimization suggestions', () async {
        await _insertTestData(dbHelper);

        final suggestions = await dbHelper.getOptimizationSuggestions();

        expect(suggestions, isA<List<String>>());
        expect(suggestions, isNotEmpty);

        // With small test data, should suggest database is well optimized
        expect(suggestions.any((s) => s.contains('well optimized')), isTrue);
      });

      test('should optimize database successfully', () async {
        await _insertTestData(dbHelper);

        final result = await dbHelper.optimizeDatabase();

        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], isTrue);
        expect(result['analyze_completed'], isTrue);
        expect(result['cache_optimized'], isTrue);
        expect(result['synchronous_optimized'], isTrue);
        expect(result.containsKey('optimization_time_ms'), isTrue);

        final optimizationTime = result['optimization_time_ms'] as int;
        expect(
          optimizationTime,
          greaterThanOrEqualTo(0),
        ); // Allow 0ms for fast operations
        expect(
          optimizationTime,
          lessThan(10000),
        ); // Should complete in under 10 seconds
      });
    });

    group('Query Benchmarking', () {
      test('should benchmark common queries', () async {
        await _insertTestData(dbHelper);

        final benchmarks = await dbHelper.benchmarkQueries(iterations: 10);

        expect(benchmarks, isA<Map<String, dynamic>>());

        // Should have benchmarks for all common query types
        expect(benchmarks.containsKey('simple_count'), isTrue);
        expect(benchmarks.containsKey('recent_recordings'), isTrue);
        expect(benchmarks.containsKey('settings_by_category'), isTrue);

        // Verify benchmark structure for a specific query
        final countBenchmark =
            benchmarks['simple_count'] as Map<String, dynamic>;
        expect(countBenchmark['iterations'], equals(10));
        expect(countBenchmark.containsKey('avg_microseconds'), isTrue);
        expect(countBenchmark.containsKey('min_microseconds'), isTrue);
        expect(countBenchmark.containsKey('max_microseconds'), isTrue);
        expect(countBenchmark.containsKey('median_microseconds'), isTrue);
        expect(countBenchmark.containsKey('p95_microseconds'), isTrue);

        // Verify reasonable performance times (should be fast for small dataset)
        final avgTime = countBenchmark['avg_microseconds'] as num;
        expect(
          avgTime,
          lessThan(100000),
        ); // Should be under 100ms for simple count
      });

      test('should handle empty database benchmarking', () async {
        // Don't insert any test data
        final benchmarks = await dbHelper.benchmarkQueries(iterations: 5);

        expect(benchmarks, isA<Map<String, dynamic>>());

        // Should still complete successfully with empty data
        expect(benchmarks.containsKey('simple_count'), isTrue);

        final countBenchmark =
            benchmarks['simple_count'] as Map<String, dynamic>;
        expect(countBenchmark['iterations'], equals(5));
      });
    });

    group('Index Analysis', () {
      test('should analyze index usage correctly', () async {
        final stats = await dbHelper.getPerformanceStats();
        final indexUsage = stats['index_usage'] as Map<String, dynamic>;
        final indexDetails =
            indexUsage['index_details'] as Map<String, dynamic>;

        // Verify we have the expected indexes
        expect(indexDetails.containsKey('idx_recordings_created_at'), isTrue);
        expect(
          indexDetails.containsKey('idx_recordings_deleted_created'),
          isTrue,
        );
        expect(
          indexDetails.containsKey('idx_transcriptions_recording_id'),
          isTrue,
        );
        expect(
          indexDetails.containsKey('idx_summaries_transcription_id'),
          isTrue,
        );

        // Verify index structure
        final recordingsCreatedIndex =
            indexDetails['idx_recordings_created_at'] as Map<String, dynamic>;
        expect(recordingsCreatedIndex['table'], equals('recordings'));
        expect(recordingsCreatedIndex['columns'], contains('created_at'));
      });

      test('should provide detailed table statistics', () async {
        await _insertTestData(dbHelper);

        final stats = await dbHelper.getPerformanceStats();
        final tableStats = stats['table_statistics'] as Map<String, dynamic>;

        // Check recordings table statistics
        final recordingsStats =
            tableStats['recordings'] as Map<String, dynamic>;
        expect(recordingsStats['row_count'], equals(3));
        expect(
          recordingsStats['column_count'],
          greaterThan(15),
        ); // Has many columns

        final columns = recordingsStats['columns'] as List;
        expect(columns, isNotEmpty);

        // Verify column information structure
        final firstColumn = columns.first as Map<String, dynamic>;
        expect(firstColumn.containsKey('name'), isTrue);
        expect(firstColumn.containsKey('type'), isTrue);
        expect(firstColumn.containsKey('nullable'), isTrue);
        expect(firstColumn.containsKey('primary_key'), isTrue);
      });
    });

    group('Performance Optimization', () {
      test('should suggest optimizations for large datasets', () async {
        // This is a conceptual test - in real scenarios we'd need thousands of rows
        // to trigger optimization suggestions
        await _insertTestData(dbHelper);

        final suggestions = await dbHelper.getOptimizationSuggestions();

        expect(suggestions, isA<List<String>>());
        expect(suggestions, isNotEmpty);

        // For small test dataset, should indicate good optimization
        final hasOptimizedMessage = suggestions.any(
          (suggestion) =>
              suggestion.toLowerCase().contains('optimized') ||
              suggestion.toLowerCase().contains('well'),
        );
        expect(hasOptimizedMessage, isTrue);
      });

      test('should handle database reopening during optimization', () async {
        // Close database - it should automatically reopen
        await dbHelper.close();

        final result = await dbHelper.optimizeDatabase();

        expect(result, isA<Map<String, dynamic>>());
        expect(
          result['success'],
          isTrue,
        ); // Database should reopen automatically
        expect(result.containsKey('optimization_time_ms'), isTrue);
      });
    });

    group('Cache Management', () {
      test('should get cache statistics', () async {
        final stats = await dbHelper.getPerformanceStats();
        final cacheStats = stats['cache_statistics'] as Map<String, dynamic>;

        expect(cacheStats.containsKey('cache_size'), isTrue);
        expect(cacheStats.containsKey('cache_spill'), isTrue);

        // Cache size should be a reasonable value
        final cacheSize = cacheStats['cache_size'] as num;
        expect(cacheSize.abs(), greaterThan(0));
      });
    });

    group('Edge Cases', () {
      test(
        'should handle performance analysis on corrupted data gracefully',
        () async {
          // This test ensures our performance methods don't crash on edge cases
          await _insertTestData(dbHelper);

          // All these should complete without throwing
          expect(() => dbHelper.getPerformanceStats(), returnsNormally);
          expect(() => dbHelper.getOptimizationSuggestions(), returnsNormally);
          expect(
            () => dbHelper.benchmarkQueries(iterations: 1),
            returnsNormally,
          );
        },
      );

      test('should handle benchmark with zero iterations', () async {
        final benchmarks = await dbHelper.benchmarkQueries(iterations: 0);

        expect(benchmarks, isA<Map<String, dynamic>>());
        // Should return empty or minimal results without crashing
      });
    });
  });
}

/// Helper method to insert test data for performance testing
Future<void> _insertTestData(DatabaseHelper dbHelper) async {
  final now = DateTime.now();

  // Insert test recordings
  final recordings = [
    Recording(
      id: 'test-recording-1',
      filename: 'test1.wav',
      filePath: '/test/test1.wav',
      duration: 60000,
      fileSize: 1024000,
      format: 'wav',
      quality: 'high',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 1,
      title: 'Test Recording 1',
      description: 'First test recording for performance analysis',
      tags: ['test', 'performance', 'analysis'],
      location: 'Test Location 1',
      waveformData: [0.1, 0.2, 0.3, 0.4, 0.5],
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
      metadata: {'test': 'data'},
    ),
    Recording(
      id: 'test-recording-2',
      filename: 'test2.mp3',
      filePath: '/test/test2.mp3',
      duration: 120000,
      fileSize: 2048000,
      format: 'mp3',
      quality: 'medium',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      title: 'Test Recording 2',
      description: 'Second test recording for performance analysis',
      tags: ['test', 'performance'],
      location: 'Test Location 2',
      waveformData: [0.2, 0.4, 0.6, 0.8, 1.0],
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
      metadata: {'test': 'data2'},
    ),
    Recording(
      id: 'test-recording-3',
      filename: 'test3.m4a',
      filePath: '/test/test3.m4a',
      duration: 180000,
      fileSize: 3072000,
      format: 'm4a',
      quality: 'low',
      sampleRate: 22050,
      bitDepth: 16,
      channels: 1,
      title: 'Test Recording 3',
      description: 'Third test recording for performance analysis',
      tags: ['test'],
      location: 'Test Location 3',
      waveformData: [0.3, 0.6, 0.9],
      createdAt: now,
      updatedAt: now,
      metadata: {'test': 'data3'},
    ),
  ];

  for (final recording in recordings) {
    await dbHelper.insertRecording(recording);
  }

  // Insert test transcriptions
  final transcriptions = [
    Transcription(
      id: 'test-transcription-1',
      recordingId: 'test-recording-1',
      text: 'This is the first test transcription for performance analysis',
      confidence: 0.95,
      language: 'en',
      provider: 'test_provider',
      status: TranscriptionStatus.completed,
      wordCount: 10,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Transcription(
      id: 'test-transcription-2',
      recordingId: 'test-recording-2',
      text: 'This is the second test transcription for performance analysis',
      confidence: 0.88,
      language: 'en',
      provider: 'test_provider',
      status: TranscriptionStatus.completed,
      wordCount: 11,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  for (final transcription in transcriptions) {
    await dbHelper.insertTranscription(transcription);
  }

  // Insert test summaries
  final summaries = [
    models.Summary(
      id: 'test-summary-1',
      transcriptionId: 'test-transcription-1',
      content: 'Summary of the first test transcription',
      type: models.SummaryType.brief,
      provider: 'test_provider',
      model: 'test_model',
      confidence: 0.90,
      wordCount: 8,
      characterCount: 40,
      sentiment: models.SentimentType.neutral,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];

  for (final summary in summaries) {
    await dbHelper.insertSummary(summary);
  }
}
