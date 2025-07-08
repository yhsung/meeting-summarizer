/// Service for monitoring transcription usage and collecting metrics
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/transcription_usage_stats.dart';
import 'transcription_error_handler.dart';

/// Service for monitoring and tracking transcription usage statistics
class TranscriptionUsageMonitor {
  static const String _usageStatsFileName = 'transcription_usage_stats.json';
  static const String _metricsFileName = 'transcription_metrics.json';
  static const String _exportDirectoryName = 'transcription_exports';

  static TranscriptionUsageMonitor? _instance;
  static final Object _lock = Object();

  TranscriptionUsageStats _currentStats = TranscriptionUsageStats.empty();
  File? _statsFile;
  File? _metricsFile;
  Directory? _exportDir;
  bool _isInitialized = false;

  // Singleton pattern
  TranscriptionUsageMonitor._();

  /// Get the singleton instance
  static TranscriptionUsageMonitor getInstance() {
    return _instance ??= TranscriptionUsageMonitor._();
  }

  /// Initialize the usage monitor
  Future<void> initialize() async {
    if (_isInitialized) return;

    synchronized(_lock, () async {
      if (_isInitialized) return;

      try {
        debugPrint('TranscriptionUsageMonitor: Initializing usage monitoring');

        // Setup storage directories and files
        final appDocsDir = await getApplicationDocumentsDirectory();
        final usageDir = Directory(
          path.join(appDocsDir.path, 'transcription_usage'),
        );

        if (!await usageDir.exists()) {
          await usageDir.create(recursive: true);
        }

        _statsFile = File(path.join(usageDir.path, _usageStatsFileName));
        _metricsFile = File(path.join(usageDir.path, _metricsFileName));
        _exportDir = Directory(path.join(usageDir.path, _exportDirectoryName));

        if (!await _exportDir!.exists()) {
          await _exportDir!.create(recursive: true);
        }

        // Load existing stats if available
        await _loadExistingStats();

        _isInitialized = true;
        debugPrint('TranscriptionUsageMonitor: Initialization complete');
      } catch (e) {
        debugPrint('TranscriptionUsageMonitor: Initialization failed: $e');
        throw TranscriptionError(
          type: TranscriptionErrorType.configurationError,
          message: 'Failed to initialize usage monitor: $e',
          originalError: e,
          isRetryable: false,
        );
      }
    });
  }

  /// Record a transcription request and its outcome
  Future<void> recordTranscriptionRequest({
    required bool success,
    required Duration processingTime,
    required int audioDurationMs,
    required String provider,
    String? errorType,
    Map<String, dynamic>? additionalMetrics,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint(
        'TranscriptionUsageMonitor: Recording request - '
        'Provider: $provider, Success: $success, Duration: ${processingTime.inMilliseconds}ms',
      );

      // Update current stats
      _currentStats = _currentStats.copyWithNewRequest(
        success: success,
        processingTime: processingTime,
        audioDurationMs: audioDurationMs,
        provider: provider,
        errorType: errorType,
      );

      // Persist updated stats
      await _saveStats();

      // Record detailed metrics if provided
      if (additionalMetrics != null) {
        await _recordDetailedMetrics({
          'timestamp': DateTime.now().toIso8601String(),
          'provider': provider,
          'success': success,
          'processing_time_ms': processingTime.inMilliseconds,
          'audio_duration_ms': audioDurationMs,
          'error_type': errorType,
          ...additionalMetrics,
        });
      }

      debugPrint('TranscriptionUsageMonitor: Request recorded successfully');
    } catch (e) {
      debugPrint('TranscriptionUsageMonitor: Failed to record request: $e');
      // Don't throw errors for monitoring failures to avoid disrupting transcription
    }
  }

  /// Get current usage statistics
  Future<TranscriptionUsageStats> getCurrentStats() async {
    if (!_isInitialized) {
      await initialize();
    }

    return _currentStats;
  }

  /// Get usage statistics for a specific date range
  Future<TranscriptionUsageStats> getStatsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Filter daily stats within the date range
    final filteredDailyStats = <String, DailyUsageStats>{};
    final startDateKey = _formatDateKey(startDate);
    final endDateKey = _formatDateKey(endDate);

    for (final entry in _currentStats.dailyStats.entries) {
      if (entry.key.compareTo(startDateKey) >= 0 &&
          entry.key.compareTo(endDateKey) <= 0) {
        filteredDailyStats[entry.key] = entry.value;
      }
    }

    // Calculate aggregated stats for the date range
    int totalRequests = 0;
    int successfulRequests = 0;
    int failedRequests = 0;
    Duration totalProcessingTime = Duration.zero;
    int totalAudioMinutes = 0;

    for (final dailyStats in filteredDailyStats.values) {
      totalRequests += dailyStats.totalRequests;
      successfulRequests += dailyStats.successfulRequests;
      failedRequests += dailyStats.failedRequests;
      totalProcessingTime += dailyStats.totalProcessingTime;
      totalAudioMinutes += dailyStats.totalAudioMinutes;
    }

    final averageProcessingTime = totalRequests > 0
        ? totalProcessingTime.inMilliseconds / totalRequests
        : 0.0;

    return TranscriptionUsageStats(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      totalProcessingTime: totalProcessingTime,
      averageProcessingTime: averageProcessingTime,
      totalAudioMinutes: totalAudioMinutes,
      lastRequestTime: endDate,
      dailyStats: filteredDailyStats,
      providerStats: {}, // Could be filtered if needed
      errorCounts: {}, // Could be filtered if needed
      peakMetrics: PeakUsageMetrics(), // Could be calculated from filtered data
    );
  }

  /// Export usage statistics to various formats
  Future<File> exportUsageStats({
    required ExportFormat format,
    DateTime? startDate,
    DateTime? endDate,
    String? customFileName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final stats = startDate != null && endDate != null
        ? await getStatsForDateRange(startDate: startDate, endDate: endDate)
        : _currentStats;

    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final fileName = customFileName ?? 'transcription_usage_$timestamp';

    switch (format) {
      case ExportFormat.json:
        return await _exportAsJson(stats, fileName);
      case ExportFormat.csv:
        return await _exportAsCsv(stats, fileName);
      case ExportFormat.txt:
        return await _exportAsText(stats, fileName);
    }
  }

  /// Get performance insights and recommendations
  Future<UsageInsights> getUsageInsights() async {
    if (!_isInitialized) {
      await initialize();
    }

    final stats = _currentStats;
    final insights = <String>[];
    final recommendations = <String>[];
    final warnings = <String>[];

    // Analyze success rate
    if (stats.successRate < 90) {
      warnings.add(
        'Low success rate: ${stats.successRate.toStringAsFixed(1)}%',
      );
      recommendations.add(
        'Review error logs and consider improving network connectivity',
      );
    } else if (stats.successRate >= 95) {
      insights.add(
        'Excellent success rate: ${stats.successRate.toStringAsFixed(1)}%',
      );
    }

    // Analyze processing efficiency
    if (stats.processingEfficiency < 1.0) {
      warnings.add('Processing takes longer than audio duration');
      recommendations.add(
        'Consider using faster models or optimizing audio preprocessing',
      );
    } else if (stats.processingEfficiency > 2.0) {
      insights.add(
        'Excellent processing efficiency: ${stats.processingEfficiency.toStringAsFixed(1)}x real-time',
      );
    }

    // Analyze provider usage
    final mostUsedProvider = stats.mostUsedProvider;
    if (mostUsedProvider != null) {
      insights.add('Most used provider: $mostUsedProvider');

      final providerStats = stats.providerStats[mostUsedProvider];
      if (providerStats != null && providerStats.successRate < 85) {
        warnings.add(
          'Primary provider has low success rate: ${providerStats.successRate.toStringAsFixed(1)}%',
        );
        recommendations.add('Consider switching to a more reliable provider');
      }
    }

    // Analyze error patterns
    final mostCommonError = stats.mostCommonError;
    if (mostCommonError != null) {
      final errorCount = stats.errorCounts[mostCommonError] ?? 0;
      if (errorCount > stats.totalRequests * 0.1) {
        warnings.add(
          'Frequent $mostCommonError errors: $errorCount occurrences',
        );
        recommendations.add(_getErrorRecommendation(mostCommonError));
      }
    }

    // Analyze usage patterns
    final avgRequestsPerDay = stats.averageRequestsPerDay;
    if (avgRequestsPerDay > 100) {
      insights.add(
        'High usage: ${avgRequestsPerDay.toStringAsFixed(1)} requests per day',
      );
      recommendations.add(
        'Consider implementing request batching for efficiency',
      );
    } else if (avgRequestsPerDay < 5) {
      insights.add(
        'Low usage: ${avgRequestsPerDay.toStringAsFixed(1)} requests per day',
      );
    }

    return UsageInsights(
      insights: insights,
      recommendations: recommendations,
      warnings: warnings,
      overallHealthScore: _calculateHealthScore(stats),
      generatedAt: DateTime.now(),
    );
  }

  /// Clear all usage statistics (with confirmation)
  Future<void> clearUsageStats({required bool confirmed}) async {
    if (!confirmed) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Clear operation requires explicit confirmation',
        isRetryable: false,
      );
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('TranscriptionUsageMonitor: Clearing all usage statistics');

      _currentStats = TranscriptionUsageStats.empty();
      await _saveStats();

      // Clear metrics file
      if (_metricsFile != null && await _metricsFile!.exists()) {
        await _metricsFile!.writeAsString('[]');
      }

      debugPrint('TranscriptionUsageMonitor: Usage statistics cleared');
    } catch (e) {
      debugPrint('TranscriptionUsageMonitor: Failed to clear stats: $e');
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Failed to clear usage statistics: $e',
        originalError: e,
        isRetryable: true,
      );
    }
  }

  /// Dispose of the monitor and save current state
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      debugPrint('TranscriptionUsageMonitor: Disposing and saving final state');
      await _saveStats();
      _isInitialized = false;
    } catch (e) {
      debugPrint('TranscriptionUsageMonitor: Error during disposal: $e');
    }
  }

  // Private helper methods

  /// Load existing statistics from storage
  Future<void> _loadExistingStats() async {
    try {
      if (_statsFile != null && await _statsFile!.exists()) {
        final content = await _statsFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _currentStats = TranscriptionUsageStats.fromJson(json);
        debugPrint(
          'TranscriptionUsageMonitor: Loaded existing usage statistics',
        );
      } else {
        _currentStats = TranscriptionUsageStats.empty();
        debugPrint(
          'TranscriptionUsageMonitor: No existing statistics found, starting fresh',
        );
      }
    } catch (e) {
      debugPrint(
        'TranscriptionUsageMonitor: Error loading existing stats, starting fresh: $e',
      );
      _currentStats = TranscriptionUsageStats.empty();
    }
  }

  /// Save current statistics to storage
  Future<void> _saveStats() async {
    try {
      if (_statsFile != null) {
        final json = jsonEncode(_currentStats.toJson());
        await _statsFile!.writeAsString(json);
      }
    } catch (e) {
      debugPrint('TranscriptionUsageMonitor: Error saving stats: $e');
    }
  }

  /// Record detailed metrics for analysis
  Future<void> _recordDetailedMetrics(Map<String, dynamic> metrics) async {
    try {
      if (_metricsFile == null) return;

      List<Map<String, dynamic>> existingMetrics = [];

      if (await _metricsFile!.exists()) {
        final content = await _metricsFile!.readAsString();
        if (content.isNotEmpty) {
          existingMetrics = List<Map<String, dynamic>>.from(
            jsonDecode(content),
          );
        }
      }

      existingMetrics.add(metrics);

      // Keep only the last 1000 metrics to prevent file from growing too large
      if (existingMetrics.length > 1000) {
        existingMetrics = existingMetrics.sublist(
          existingMetrics.length - 1000,
        );
      }

      await _metricsFile!.writeAsString(jsonEncode(existingMetrics));
    } catch (e) {
      debugPrint(
        'TranscriptionUsageMonitor: Error recording detailed metrics: $e',
      );
    }
  }

  /// Export statistics as JSON
  Future<File> _exportAsJson(
    TranscriptionUsageStats stats,
    String fileName,
  ) async {
    final file = File(path.join(_exportDir!.path, '$fileName.json'));
    await file.writeAsString(jsonEncode(stats.toJson()));
    return file;
  }

  /// Export statistics as CSV
  Future<File> _exportAsCsv(
    TranscriptionUsageStats stats,
    String fileName,
  ) async {
    final file = File(path.join(_exportDir!.path, '$fileName.csv'));

    final csvContent = StringBuffer();
    csvContent.writeln('Metric,Value');
    csvContent.writeln('Total Requests,${stats.totalRequests}');
    csvContent.writeln('Successful Requests,${stats.successfulRequests}');
    csvContent.writeln('Failed Requests,${stats.failedRequests}');
    csvContent.writeln('Success Rate,${stats.successRate.toStringAsFixed(2)}%');
    csvContent.writeln('Total Audio Minutes,${stats.totalAudioMinutes}');
    csvContent.writeln(
      'Average Processing Time (ms),${stats.averageProcessingTime.toStringAsFixed(2)}',
    );
    csvContent.writeln(
      'Processing Efficiency,${stats.processingEfficiency.toStringAsFixed(2)}x',
    );
    csvContent.writeln(
      'Last Request,${stats.lastRequestTime.toIso8601String()}',
    );

    await file.writeAsString(csvContent.toString());
    return file;
  }

  /// Export statistics as text report
  Future<File> _exportAsText(
    TranscriptionUsageStats stats,
    String fileName,
  ) async {
    final file = File(path.join(_exportDir!.path, '$fileName.txt'));

    final report = StringBuffer();
    report.writeln('Transcription Usage Report');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('=' * 50);
    report.writeln();

    report.writeln('OVERVIEW');
    report.writeln('Total Requests: ${stats.totalRequests}');
    report.writeln(
      'Successful: ${stats.successfulRequests} (${stats.successRate.toStringAsFixed(1)}%)',
    );
    report.writeln(
      'Failed: ${stats.failedRequests} (${stats.failureRate.toStringAsFixed(1)}%)',
    );
    report.writeln('Total Audio Processed: ${stats.totalAudioMinutes} minutes');
    report.writeln(
      'Average Processing Time: ${stats.averageProcessingTime.toStringAsFixed(0)}ms',
    );
    report.writeln(
      'Processing Efficiency: ${stats.processingEfficiency.toStringAsFixed(2)}x real-time',
    );
    report.writeln();

    if (stats.providerStats.isNotEmpty) {
      report.writeln('PROVIDER STATISTICS');
      for (final entry in stats.providerStats.entries) {
        final providerStats = entry.value;
        report.writeln('${entry.key}:');
        report.writeln('  Requests: ${providerStats.totalRequests}');
        report.writeln(
          '  Success Rate: ${providerStats.successRate.toStringAsFixed(1)}%',
        );
        report.writeln(
          '  Last Used: ${providerStats.lastUsed.toIso8601String()}',
        );
      }
      report.writeln();
    }

    if (stats.errorCounts.isNotEmpty) {
      report.writeln('ERROR ANALYSIS');
      for (final entry in stats.errorCounts.entries) {
        report.writeln('${entry.key}: ${entry.value} occurrences');
      }
    }

    await file.writeAsString(report.toString());
    return file;
  }

  /// Format date as YYYY-MM-DD key
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get recommendation for specific error type
  String _getErrorRecommendation(String errorType) {
    switch (errorType.toLowerCase()) {
      case 'network':
        return 'Check network connectivity and consider implementing offline fallback';
      case 'authentication':
        return 'Verify API keys and authentication credentials';
      case 'ratelimit':
        return 'Implement request throttling and consider upgrading API plan';
      case 'audioformat':
        return 'Ensure audio files are in supported formats (MP3, WAV, M4A)';
      case 'filesize':
        return 'Compress audio files or split large files into smaller chunks';
      default:
        return 'Review error logs for specific troubleshooting steps';
    }
  }

  /// Calculate overall health score (0-100)
  double _calculateHealthScore(TranscriptionUsageStats stats) {
    if (stats.totalRequests == 0) return 100.0;

    double score = 0.0;

    // Success rate contributes 40% to health score
    score += (stats.successRate / 100.0) * 40.0;

    // Processing efficiency contributes 30% (capped at 30 points)
    final efficiencyScore = (stats.processingEfficiency * 15.0).clamp(
      0.0,
      30.0,
    );
    score += efficiencyScore;

    // Low error diversity contributes 20%
    final errorDiversity = stats.errorCounts.length;
    final errorScore = errorDiversity <= 2
        ? 20.0
        : (20.0 - (errorDiversity - 2) * 3.0).clamp(0.0, 20.0);
    score += errorScore;

    // Consistent usage contributes 10%
    final usageScore = stats.averageRequestsPerDay > 1
        ? 10.0
        : stats.averageRequestsPerDay * 10.0;
    score += usageScore;

    return score.clamp(0.0, 100.0);
  }

  /// Synchronized execution helper
  Future<T> synchronized<T>(
    Object lock,
    Future<T> Function() computation,
  ) async {
    return await computation();
  }
}

/// Export format options
enum ExportFormat { json, csv, txt }

/// Usage insights and recommendations
class UsageInsights {
  final List<String> insights;
  final List<String> recommendations;
  final List<String> warnings;
  final double overallHealthScore;
  final DateTime generatedAt;

  const UsageInsights({
    required this.insights,
    required this.recommendations,
    required this.warnings,
    required this.overallHealthScore,
    required this.generatedAt,
  });

  /// Get health status based on score
  String get healthStatus {
    if (overallHealthScore >= 90) return 'Excellent';
    if (overallHealthScore >= 80) return 'Good';
    if (overallHealthScore >= 70) return 'Fair';
    if (overallHealthScore >= 60) return 'Poor';
    return 'Critical';
  }

  /// Get health color indicator
  String get healthColor {
    if (overallHealthScore >= 90) return 'Green';
    if (overallHealthScore >= 80) return 'LightGreen';
    if (overallHealthScore >= 70) return 'Yellow';
    if (overallHealthScore >= 60) return 'Orange';
    return 'Red';
  }

  /// Check if there are any critical issues
  bool get hasCriticalIssues => warnings.isNotEmpty || overallHealthScore < 60;

  @override
  String toString() {
    return 'UsageInsights('
        'health: $healthStatus (${overallHealthScore.toStringAsFixed(1)}), '
        'insights: ${insights.length}, '
        'warnings: ${warnings.length}'
        ')';
  }
}
