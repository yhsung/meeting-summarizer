/// Database performance monitoring and optimization service
///
/// This service provides comprehensive performance monitoring, analysis,
/// and optimization capabilities for the SQLite database.
library;

import 'dart:async';
import 'dart:math' hide log;
import 'dart:developer';

import '../database/database_helper.dart';

/// Performance threshold levels for alerting and optimization
enum PerformanceLevel { excellent, good, fair, poor, critical }

/// Performance monitoring service for database operations
class DatabasePerformanceService {
  static DatabasePerformanceService? _instance;
  final DatabaseHelper _dbHelper;

  // Performance metrics tracking
  final Map<String, List<int>> _queryTimes = {};
  final Map<String, int> _queryCount = {};
  Timer? _performanceMonitorTimer;
  bool _isMonitoring = false;

  DatabasePerformanceService._(this._dbHelper);

  /// Get singleton instance
  factory DatabasePerformanceService({DatabaseHelper? dbHelper}) {
    _instance ??= DatabasePerformanceService._(dbHelper ?? DatabaseHelper());
    return _instance!;
  }

  /// Start continuous performance monitoring
  Future<void> startMonitoring({
    Duration interval = const Duration(minutes: 5),
  }) async {
    if (_isMonitoring) return;

    log('DatabasePerformanceService: Starting performance monitoring');
    _isMonitoring = true;

    _performanceMonitorTimer = Timer.periodic(interval, (timer) async {
      await _performPerformanceCheck();
    });

    // Initial performance check
    await _performPerformanceCheck();
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    log('DatabasePerformanceService: Stopping performance monitoring');
    _performanceMonitorTimer?.cancel();
    _performanceMonitorTimer = null;
    _isMonitoring = false;
  }

  /// Record query execution time for monitoring
  void recordQueryTime(String queryType, int microseconds) {
    _queryTimes.putIfAbsent(queryType, () => []);
    _queryTimes[queryType]!.add(microseconds);

    // Keep only the last 100 measurements per query type
    if (_queryTimes[queryType]!.length > 100) {
      _queryTimes[queryType]!.removeAt(0);
    }

    _queryCount[queryType] = (_queryCount[queryType] ?? 0) + 1;
  }

  /// Get comprehensive performance report
  Future<Map<String, dynamic>> getPerformanceReport() async {
    final report = <String, dynamic>{};

    try {
      // Basic database statistics
      final stats = await _dbHelper.getPerformanceStats();
      report['database_stats'] = stats;

      // Performance level assessment
      final performanceLevel = await _assessPerformanceLevel(stats);
      report['performance_level'] = performanceLevel.name;
      report['performance_score'] = _calculatePerformanceScore(stats);

      // Query performance metrics
      report['query_metrics'] = _getQueryMetrics();

      // Optimization recommendations
      final suggestions = await _dbHelper.getOptimizationSuggestions();
      report['optimization_suggestions'] = suggestions;

      // Health indicators
      report['health_indicators'] = await _getHealthIndicators(stats);

      // Performance trends (if we have historical data)
      report['performance_trends'] = _getPerformanceTrends();

      // Last update timestamp
      report['generated_at'] = DateTime.now().toIso8601String();
      report['monitoring_active'] = _isMonitoring;

      return report;
    } catch (e) {
      log(
        'DatabasePerformanceService: Failed to generate performance report: $e',
      );
      return {
        'error': e.toString(),
        'generated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Optimize database performance automatically
  Future<Map<String, dynamic>> optimizePerformance({
    bool aggressive = false,
  }) async {
    final results = <String, dynamic>{};
    final startTime = DateTime.now();

    try {
      log('DatabasePerformanceService: Starting automatic optimization');

      // Run database optimization
      final optimizationResults = await _dbHelper.optimizeDatabase();
      results['database_optimization'] = optimizationResults;

      // Clear query metrics cache if optimization was successful
      if (optimizationResults['success'] == true) {
        _clearQueryMetrics();
        results['metrics_cleared'] = true;
      }

      // Aggressive optimization options
      if (aggressive) {
        // Run additional optimizations
        await _performAggressiveOptimization();
        results['aggressive_optimization'] = true;
      }

      // Re-assess performance after optimization
      final newStats = await _dbHelper.getPerformanceStats();
      final newLevel = await _assessPerformanceLevel(newStats);
      results['new_performance_level'] = newLevel.name;
      results['new_performance_score'] = _calculatePerformanceScore(newStats);

      final endTime = DateTime.now();
      results['total_optimization_time_ms'] =
          endTime.difference(startTime).inMilliseconds;
      results['success'] = true;

      log('DatabasePerformanceService: Optimization completed successfully');
      return results;
    } catch (e) {
      log('DatabasePerformanceService: Optimization failed: $e');
      results['success'] = false;
      results['error'] = e.toString();
      return results;
    }
  }

  /// Benchmark database performance with detailed analysis
  Future<Map<String, dynamic>> runPerformanceBenchmark({
    int iterations = 50,
    bool includeStressTest = false,
  }) async {
    final benchmarkResults = <String, dynamic>{};
    final startTime = DateTime.now();

    try {
      log('DatabasePerformanceService: Starting performance benchmark');

      // Standard query benchmarks
      final queryBenchmarks = await _dbHelper.benchmarkQueries(
        iterations: iterations,
      );
      benchmarkResults['query_benchmarks'] = queryBenchmarks;

      // Performance score calculation
      benchmarkResults['benchmark_score'] = _calculateBenchmarkScore(
        queryBenchmarks,
      );

      // Stress testing (if enabled)
      if (includeStressTest) {
        final stressResults = await _runStressTest();
        benchmarkResults['stress_test'] = stressResults;
      }

      // Performance comparison with baseline
      benchmarkResults['performance_comparison'] = _compareWithBaseline(
        queryBenchmarks,
      );

      // Benchmark metadata
      final endTime = DateTime.now();
      benchmarkResults['benchmark_duration_ms'] =
          endTime.difference(startTime).inMilliseconds;
      benchmarkResults['iterations'] = iterations;
      benchmarkResults['timestamp'] = endTime.toIso8601String();
      benchmarkResults['success'] = true;

      log('DatabasePerformanceService: Benchmark completed');
      return benchmarkResults;
    } catch (e) {
      log('DatabasePerformanceService: Benchmark failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get real-time performance metrics
  Map<String, dynamic> getRealtimeMetrics() {
    return {
      'query_counts': Map<String, int>.from(_queryCount),
      'query_averages': _getQueryAverages(),
      'monitoring_active': _isMonitoring,
      'total_queries': _queryCount.values.fold(0, (sum, count) => sum + count),
      'query_types_tracked': _queryTimes.keys.length,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Reset all performance metrics
  void resetMetrics() {
    _queryTimes.clear();
    _queryCount.clear();
    log('DatabasePerformanceService: Performance metrics reset');
  }

  // Private helper methods

  /// Perform periodic performance check
  Future<void> _performPerformanceCheck() async {
    try {
      final stats = await _dbHelper.getPerformanceStats();
      final level = await _assessPerformanceLevel(stats);

      // Log performance alerts
      if (level == PerformanceLevel.poor ||
          level == PerformanceLevel.critical) {
        log(
          'DatabasePerformanceService: Performance alert - Level: ${level.name}',
        );

        // Auto-optimize if performance is critical
        if (level == PerformanceLevel.critical) {
          await optimizePerformance();
        }
      }
    } catch (e) {
      log('DatabasePerformanceService: Performance check failed: $e');
    }
  }

  /// Assess overall performance level
  Future<PerformanceLevel> _assessPerformanceLevel(
    Map<String, dynamic> stats,
  ) async {
    try {
      final score = _calculatePerformanceScore(stats);

      if (score >= 90) return PerformanceLevel.excellent;
      if (score >= 75) return PerformanceLevel.good;
      if (score >= 60) return PerformanceLevel.fair;
      if (score >= 40) return PerformanceLevel.poor;
      return PerformanceLevel.critical;
    } catch (e) {
      log('DatabasePerformanceService: Failed to assess performance level: $e');
      return PerformanceLevel.fair;
    }
  }

  /// Calculate performance score (0-100)
  double _calculatePerformanceScore(Map<String, dynamic> stats) {
    try {
      double score = 100.0;

      // Database size penalty
      final dbSize = stats['database_size_bytes'] as int? ?? 0;
      if (dbSize > 100 * 1024 * 1024) {
        // > 100MB
        score -= 20;
      } else if (dbSize > 50 * 1024 * 1024) {
        // > 50MB
        score -= 10;
      }

      // Index usage score
      final indexUsage = stats['index_usage'] as Map<String, dynamic>? ?? {};
      final indexCount = indexUsage['total_indexes'] as int? ?? 0;
      if (indexCount < 10) {
        score -= 15;
      }

      // Query performance penalties based on recorded metrics
      final avgQueryTime = _getOverallAverageQueryTime();
      if (avgQueryTime > 10000) {
        // > 10ms average
        score -= 25;
      } else if (avgQueryTime > 5000) {
        // > 5ms average
        score -= 10;
      }

      return max(0, score);
    } catch (e) {
      log(
        'DatabasePerformanceService: Failed to calculate performance score: $e',
      );
      return 50.0; // Default middle score
    }
  }

  /// Get query performance metrics
  Map<String, dynamic> _getQueryMetrics() {
    return {
      'query_counts': Map<String, int>.from(_queryCount),
      'query_averages': _getQueryAverages(),
      'slowest_queries': _getSlowestQueries(),
      'fastest_queries': _getFastestQueries(),
      'total_queries_tracked': _queryCount.values.fold(
        0,
        (sum, count) => sum + count,
      ),
    };
  }

  /// Get query averages
  Map<String, double> _getQueryAverages() {
    final averages = <String, double>{};

    for (final entry in _queryTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        averages[entry.key] = times.reduce((a, b) => a + b) / times.length;
      }
    }

    return averages;
  }

  /// Get overall average query time
  double _getOverallAverageQueryTime() {
    final allTimes = <int>[];
    for (final times in _queryTimes.values) {
      allTimes.addAll(times);
    }

    if (allTimes.isEmpty) return 0.0;
    return allTimes.reduce((a, b) => a + b) / allTimes.length;
  }

  /// Get slowest queries
  List<Map<String, dynamic>> _getSlowestQueries() {
    final slowest = <Map<String, dynamic>>[];

    for (final entry in _queryTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        slowest.add({
          'query_type': entry.key,
          'max_time_microseconds': maxTime,
          'avg_time_microseconds': times.reduce((a, b) => a + b) / times.length,
        });
      }
    }

    slowest.sort(
      (a, b) => (b['max_time_microseconds'] as int).compareTo(
        a['max_time_microseconds'] as int,
      ),
    );
    return slowest.take(5).toList();
  }

  /// Get fastest queries
  List<Map<String, dynamic>> _getFastestQueries() {
    final fastest = <Map<String, dynamic>>[];

    for (final entry in _queryTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final minTime = times.reduce((a, b) => a < b ? a : b);
        fastest.add({
          'query_type': entry.key,
          'min_time_microseconds': minTime,
          'avg_time_microseconds': times.reduce((a, b) => a + b) / times.length,
        });
      }
    }

    fastest.sort(
      (a, b) => (a['min_time_microseconds'] as int).compareTo(
        b['min_time_microseconds'] as int,
      ),
    );
    return fastest.take(5).toList();
  }

  /// Get health indicators
  Future<Map<String, dynamic>> _getHealthIndicators(
    Map<String, dynamic> stats,
  ) async {
    final indicators = <String, dynamic>{};

    try {
      // Database size health
      final dbSize = stats['database_size_bytes'] as int? ?? 0;
      indicators['database_size_health'] = _getHealthStatus(
        dbSize,
        100 * 1024 * 1024,
        50 * 1024 * 1024,
      );

      // Index count health
      final indexUsage = stats['index_usage'] as Map<String, dynamic>? ?? {};
      final indexCount = indexUsage['total_indexes'] as int? ?? 0;
      indicators['index_count_health'] = _getHealthStatus(
        indexCount,
        5,
        15,
        reverse: true,
      );

      // Query performance health
      final avgQueryTime = _getOverallAverageQueryTime();
      indicators['query_performance_health'] = _getHealthStatus(
        avgQueryTime,
        10000,
        5000,
      );

      // Overall health score
      final healthValues = indicators.values.whereType<String>().toList();
      final excellentCount = healthValues.where((h) => h == 'excellent').length;
      final goodCount = healthValues.where((h) => h == 'good').length;
      final totalCount = healthValues.length;

      if (excellentCount >= totalCount * 0.7) {
        indicators['overall_health'] = 'excellent';
      } else if (excellentCount + goodCount >= totalCount * 0.6) {
        indicators['overall_health'] = 'good';
      } else {
        indicators['overall_health'] = 'needs_attention';
      }

      return indicators;
    } catch (e) {
      log('DatabasePerformanceService: Failed to get health indicators: $e');
      return {'overall_health': 'unknown'};
    }
  }

  /// Get health status based on thresholds
  String _getHealthStatus(
    num value,
    num poorThreshold,
    num goodThreshold, {
    bool reverse = false,
  }) {
    if (reverse) {
      if (value >= goodThreshold) return 'excellent';
      if (value >= poorThreshold) return 'good';
      return 'poor';
    } else {
      if (value <= goodThreshold) return 'excellent';
      if (value <= poorThreshold) return 'good';
      return 'poor';
    }
  }

  /// Get performance trends
  Map<String, dynamic> _getPerformanceTrends() {
    // For now, return basic trend information
    // In a full implementation, this would track historical performance data
    return {
      'trend_available': false,
      'reason': 'Historical data tracking not implemented yet',
      'current_session_queries': _queryCount.values.fold(
        0,
        (sum, count) => sum + count,
      ),
    };
  }

  /// Clear query metrics
  void _clearQueryMetrics() {
    _queryTimes.clear();
    _queryCount.clear();
  }

  /// Perform aggressive optimization
  Future<void> _performAggressiveOptimization() async {
    // Aggressive optimization steps
    await _dbHelper.vacuum();

    // Additional aggressive optimizations could include:
    // - Rebuilding indexes
    // - Defragmenting tables
    // - Optimizing cache settings
  }

  /// Calculate benchmark score
  double _calculateBenchmarkScore(Map<String, dynamic> benchmarks) {
    try {
      double totalScore = 0.0;
      int benchmarkCount = 0;

      for (final benchmark in benchmarks.values) {
        if (benchmark is Map<String, dynamic>) {
          final avgTime = benchmark['avg_microseconds'] as num? ?? 0;

          // Score based on performance (lower time = higher score)
          double score = 100.0;
          if (avgTime > 10000) {
            // > 10ms
            score = 50.0;
          } else if (avgTime > 5000) {
            // > 5ms
            score = 75.0;
          } else if (avgTime > 1000) {
            // > 1ms
            score = 90.0;
          }

          totalScore += score;
          benchmarkCount++;
        }
      }

      return benchmarkCount > 0 ? totalScore / benchmarkCount : 0.0;
    } catch (e) {
      log(
        'DatabasePerformanceService: Failed to calculate benchmark score: $e',
      );
      return 0.0;
    }
  }

  /// Compare benchmark results with baseline
  Map<String, dynamic> _compareWithBaseline(Map<String, dynamic> benchmarks) {
    // Baseline performance expectations (in microseconds)
    final baselines = {
      'simple_count': 1000.0,
      'recent_recordings': 5000.0,
      'filtered_recordings': 8000.0,
      'transcription_lookup': 3000.0,
      'summary_lookup': 3000.0,
      'settings_by_category': 2000.0,
    };

    final comparison = <String, Map<String, dynamic>>{};

    for (final entry in benchmarks.entries) {
      final queryType = entry.key;
      final benchmark = entry.value as Map<String, dynamic>;
      final avgTime = benchmark['avg_microseconds'] as num? ?? 0;
      final baseline = baselines[queryType] ?? 5000.0;

      final ratio = avgTime / baseline;
      String performance;

      if (ratio <= 0.5) {
        performance = 'excellent';
      } else if (ratio <= 1.0) {
        performance = 'good';
      } else if (ratio <= 2.0) {
        performance = 'fair';
      } else {
        performance = 'poor';
      }

      comparison[queryType] = {
        'current_avg_microseconds': avgTime,
        'baseline_microseconds': baseline,
        'performance_ratio': ratio,
        'performance_rating': performance,
      };
    }

    return {
      'query_comparisons': comparison,
      'overall_performance': _calculateOverallPerformanceRating(comparison),
    };
  }

  /// Calculate overall performance rating
  String _calculateOverallPerformanceRating(
    Map<String, Map<String, dynamic>> comparisons,
  ) {
    final ratings = comparisons.values
        .map((c) => c['performance_rating'] as String)
        .toList();

    final excellentCount = ratings.where((r) => r == 'excellent').length;
    final goodCount = ratings.where((r) => r == 'good').length;
    final totalCount = ratings.length;

    if (excellentCount >= totalCount * 0.7) return 'excellent';
    if (excellentCount + goodCount >= totalCount * 0.6) return 'good';
    if (goodCount >= totalCount * 0.4) return 'fair';
    return 'poor';
  }

  /// Run stress test
  Future<Map<String, dynamic>> _runStressTest() async {
    // Simplified stress test - in production this would be more comprehensive
    final stressResults = <String, dynamic>{};

    try {
      final startTime = DateTime.now();

      // Run multiple concurrent queries
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(_dbHelper.getDatabaseStats());
      }

      await Future.wait(futures);

      final endTime = DateTime.now();
      stressResults['concurrent_queries_duration_ms'] =
          endTime.difference(startTime).inMilliseconds;
      stressResults['success'] = true;

      return stressResults;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Dispose of the service
  void dispose() {
    stopMonitoring();
    _instance = null;
  }
}
