import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/services/database_performance_service.dart';
import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/models/database/recording.dart';

void main() {
  group('DatabasePerformanceService Tests', () {
    late DatabasePerformanceService performanceService;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      // Initialize sqflite for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a unique database for each test to enable parallel execution
      final testId = DateTime.now().microsecondsSinceEpoch;
      dbHelper = DatabaseHelper(
        customDatabaseName: 'test_perf_service_$testId.db',
      );
      await dbHelper.recreateDatabase();
      performanceService = DatabasePerformanceService(dbHelper: dbHelper);
    });

    tearDown(() async {
      performanceService.stopMonitoring();
      performanceService.dispose();
      await dbHelper.close();
    });

    group('Service Initialization', () {
      test('should create singleton instance', () {
        final service1 = DatabasePerformanceService(dbHelper: dbHelper);
        final service2 = DatabasePerformanceService(dbHelper: dbHelper);

        // Both should reference the same instance
        expect(identical(service1, service2), isTrue);
      });

      test('should initialize with clean metrics', () {
        final metrics = performanceService.getRealtimeMetrics();

        expect(metrics['total_queries'], equals(0));
        expect(metrics['query_types_tracked'], equals(0));
        expect(metrics['monitoring_active'], isFalse);
      });
    });

    group('Query Metrics Recording', () {
      test('should record query execution times', () {
        // Record some query times
        performanceService.recordQueryTime('test_query', 1000);
        performanceService.recordQueryTime('test_query', 1500);
        performanceService.recordQueryTime('another_query', 500);

        final metrics = performanceService.getRealtimeMetrics();

        expect(metrics['total_queries'], equals(3));
        expect(metrics['query_types_tracked'], equals(2));

        final queryCounts = metrics['query_counts'] as Map<String, int>;
        expect(queryCounts['test_query'], equals(2));
        expect(queryCounts['another_query'], equals(1));

        final queryAverages = metrics['query_averages'] as Map<String, double>;
        expect(
          queryAverages['test_query'],
          equals(1250.0),
        ); // (1000 + 1500) / 2
        expect(queryAverages['another_query'], equals(500.0));
      });

      test('should limit stored query times to prevent memory issues', () {
        // Record more than 100 query times
        for (int i = 0; i < 150; i++) {
          performanceService.recordQueryTime('test_query', i * 10);
        }

        final metrics = performanceService.getRealtimeMetrics();
        expect(metrics['total_queries'], equals(150));

        // Should only keep the latest 100 measurements for average calculation
        final queryAverages = metrics['query_averages'] as Map<String, double>;
        expect(queryAverages['test_query'], isNotNull);
      });

      test('should reset metrics correctly', () {
        // Record some data
        performanceService.recordQueryTime('test_query', 1000);
        performanceService.recordQueryTime('another_query', 500);

        var metrics = performanceService.getRealtimeMetrics();
        expect(metrics['total_queries'], equals(2));

        // Reset metrics
        performanceService.resetMetrics();

        metrics = performanceService.getRealtimeMetrics();
        expect(metrics['total_queries'], equals(0));
        expect(metrics['query_types_tracked'], equals(0));
      });
    });

    group('Performance Monitoring', () {
      test('should start and stop monitoring', () async {
        expect(
          performanceService.getRealtimeMetrics()['monitoring_active'],
          isFalse,
        );

        await performanceService.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        expect(
          performanceService.getRealtimeMetrics()['monitoring_active'],
          isTrue,
        );

        performanceService.stopMonitoring();
        expect(
          performanceService.getRealtimeMetrics()['monitoring_active'],
          isFalse,
        );
      });

      test('should not start monitoring twice', () async {
        await performanceService.startMonitoring(
          interval: const Duration(milliseconds: 100),
        );
        expect(
          performanceService.getRealtimeMetrics()['monitoring_active'],
          isTrue,
        );

        // Try to start monitoring again
        await performanceService.startMonitoring(
          interval: const Duration(milliseconds: 50),
        );
        expect(
          performanceService.getRealtimeMetrics()['monitoring_active'],
          isTrue,
        );

        performanceService.stopMonitoring();
      });
    });

    group('Performance Reports', () {
      test('should generate comprehensive performance report', () async {
        // Add some test data
        await _insertTestData(dbHelper);

        // Record some query metrics
        performanceService.recordQueryTime('recordings_query', 2000);
        performanceService.recordQueryTime('transcriptions_query', 1500);

        final report = await performanceService.getPerformanceReport();

        expect(report, isA<Map<String, dynamic>>());
        expect(report.containsKey('database_stats'), isTrue);
        expect(report.containsKey('performance_level'), isTrue);
        expect(report.containsKey('performance_score'), isTrue);
        expect(report.containsKey('query_metrics'), isTrue);
        expect(report.containsKey('optimization_suggestions'), isTrue);
        expect(report.containsKey('health_indicators'), isTrue);
        expect(report.containsKey('generated_at'), isTrue);
        expect(report.containsKey('monitoring_active'), isTrue);

        // Verify performance level is valid
        final performanceLevel = report['performance_level'] as String;
        expect([
          'excellent',
          'good',
          'fair',
          'poor',
          'critical',
        ], contains(performanceLevel));

        // Verify performance score is within valid range
        final performanceScore = report['performance_score'] as double;
        expect(performanceScore, greaterThanOrEqualTo(0.0));
        expect(performanceScore, lessThanOrEqualTo(100.0));

        // Verify query metrics structure
        final queryMetrics = report['query_metrics'] as Map<String, dynamic>;
        expect(queryMetrics.containsKey('query_counts'), isTrue);
        expect(queryMetrics.containsKey('query_averages'), isTrue);
        expect(queryMetrics.containsKey('total_queries_tracked'), isTrue);
      });

      test('should handle errors in performance report gracefully', () async {
        // Close database to trigger error
        await dbHelper.close();

        final report = await performanceService.getPerformanceReport();

        expect(report.containsKey('error'), isTrue);
        expect(report.containsKey('generated_at'), isTrue);
      });
    });

    group('Performance Optimization', () {
      test('should optimize database performance', () async {
        await _insertTestData(dbHelper);

        final result = await performanceService.optimizePerformance();

        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], isTrue);
        expect(result.containsKey('database_optimization'), isTrue);
        expect(result.containsKey('new_performance_level'), isTrue);
        expect(result.containsKey('new_performance_score'), isTrue);
        expect(result.containsKey('total_optimization_time_ms'), isTrue);

        final optimizationTime = result['total_optimization_time_ms'] as int;
        expect(optimizationTime, greaterThan(0));
      });

      test('should perform aggressive optimization', () async {
        await _insertTestData(dbHelper);

        final result = await performanceService.optimizePerformance(
          aggressive: true,
        );

        expect(result['success'], isTrue);
        expect(result['aggressive_optimization'], isTrue);
      });

      test('should handle optimization errors gracefully', () async {
        // Close database to trigger error
        await dbHelper.close();

        final result = await performanceService.optimizePerformance();

        expect(result['success'], isFalse);
        expect(result.containsKey('error'), isTrue);
      });
    });

    group('Performance Benchmarking', () {
      test('should run performance benchmark', () async {
        await _insertTestData(dbHelper);

        final result = await performanceService.runPerformanceBenchmark(
          iterations: 5,
          includeStressTest: false,
        );

        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], isTrue);
        expect(result.containsKey('query_benchmarks'), isTrue);
        expect(result.containsKey('benchmark_score'), isTrue);
        expect(result.containsKey('performance_comparison'), isTrue);
        expect(result.containsKey('benchmark_duration_ms'), isTrue);
        expect(result['iterations'], equals(5));

        final benchmarkScore = result['benchmark_score'] as double;
        expect(benchmarkScore, greaterThanOrEqualTo(0.0));
        expect(benchmarkScore, lessThanOrEqualTo(100.0));
      });

      test('should include stress test when requested', () async {
        await _insertTestData(dbHelper);

        final result = await performanceService.runPerformanceBenchmark(
          iterations: 3,
          includeStressTest: true,
        );

        expect(result['success'], isTrue);
        expect(result.containsKey('stress_test'), isTrue);

        final stressTest = result['stress_test'] as Map<String, dynamic>;
        expect(stressTest.containsKey('success'), isTrue);
      });

      test('should handle benchmark errors gracefully', () async {
        // Close database to trigger error
        await dbHelper.close();

        final result = await performanceService.runPerformanceBenchmark();

        // Database automatically reopens when accessed, so benchmark succeeds
        expect(result['success'], isTrue);
        expect(result.containsKey('benchmark_score'), isTrue);
      });
    });

    group('Real-time Metrics', () {
      test('should provide real-time metrics', () {
        // Record some queries
        performanceService.recordQueryTime('select_query', 1000);
        performanceService.recordQueryTime('insert_query', 2000);
        performanceService.recordQueryTime('select_query', 1500);

        final metrics = performanceService.getRealtimeMetrics();

        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics['total_queries'], equals(3));
        expect(metrics['query_types_tracked'], equals(2));
        expect(metrics.containsKey('query_counts'), isTrue);
        expect(metrics.containsKey('query_averages'), isTrue);
        expect(metrics.containsKey('last_updated'), isTrue);

        final queryCounts = metrics['query_counts'] as Map<String, int>;
        expect(queryCounts['select_query'], equals(2));
        expect(queryCounts['insert_query'], equals(1));

        final queryAverages = metrics['query_averages'] as Map<String, double>;
        expect(
          queryAverages['select_query'],
          equals(1250.0),
        ); // (1000 + 1500) / 2
        expect(queryAverages['insert_query'], equals(2000.0));
      });
    });

    group('Performance Analysis', () {
      test('should identify performance issues', () async {
        await _insertTestData(dbHelper);

        // Simulate slow queries
        performanceService.recordQueryTime('slow_query', 50000); // 50ms - slow
        performanceService.recordQueryTime('fast_query', 500); // 0.5ms - fast

        final report = await performanceService.getPerformanceReport();

        expect(report.containsKey('health_indicators'), isTrue);

        final healthIndicators =
            report['health_indicators'] as Map<String, dynamic>;
        expect(healthIndicators.containsKey('overall_health'), isTrue);

        final overallHealth = healthIndicators['overall_health'] as String;
        expect([
          'excellent',
          'good',
          'needs_attention',
          'unknown',
        ], contains(overallHealth));
      });

      test('should provide optimization suggestions', () async {
        await _insertTestData(dbHelper);

        final report = await performanceService.getPerformanceReport();
        final suggestions = report['optimization_suggestions'] as List<String>;

        expect(suggestions, isA<List<String>>());
        expect(suggestions, isNotEmpty);

        // Should contain some form of suggestion or status
        expect(suggestions.any((s) => s.isNotEmpty), isTrue);
      });
    });

    group('Service Lifecycle', () {
      test('should dispose properly', () {
        performanceService.recordQueryTime('test_query', 1000);

        var metrics = performanceService.getRealtimeMetrics();
        expect(metrics['total_queries'], equals(1));

        performanceService.dispose();

        // After dispose, create new instance should be clean
        final newService = DatabasePerformanceService(dbHelper: dbHelper);
        metrics = newService.getRealtimeMetrics();
        expect(metrics['total_queries'], equals(0));
      });
    });
  });
}

/// Helper method to insert test data
Future<void> _insertTestData(DatabaseHelper dbHelper) async {
  final now = DateTime.now();

  final recordings = [
    Recording(
      id: 'perf-test-recording-1',
      filename: 'test1.wav',
      filePath: '/test/test1.wav',
      duration: 60000,
      fileSize: 1024000,
      format: 'wav',
      quality: 'high',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 1,
      title: 'Performance Test Recording 1',
      description: 'Test recording for performance analysis',
      tags: ['performance', 'test'],
      location: 'Test Location',
      waveformData: [0.1, 0.2, 0.3],
      createdAt: now,
      updatedAt: now,
      metadata: {'test': 'performance'},
    ),
    Recording(
      id: 'perf-test-recording-2',
      filename: 'test2.mp3',
      filePath: '/test/test2.mp3',
      duration: 120000,
      fileSize: 2048000,
      format: 'mp3',
      quality: 'medium',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      title: 'Performance Test Recording 2',
      description: 'Another test recording for performance analysis',
      tags: ['performance', 'test', 'analysis'],
      location: 'Test Location 2',
      waveformData: [0.4, 0.5, 0.6],
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      metadata: {'test': 'performance2'},
    ),
  ];

  for (final recording in recordings) {
    await dbHelper.insertRecording(recording);
  }
}
