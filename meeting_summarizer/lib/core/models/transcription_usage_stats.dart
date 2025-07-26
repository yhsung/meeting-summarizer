/// Model for tracking transcription service usage statistics
library;

import 'package:json_annotation/json_annotation.dart';

part 'transcription_usage_stats.g.dart';

/// Comprehensive usage statistics for transcription services
@JsonSerializable()
class TranscriptionUsageStats {
  /// Total number of transcription requests made
  final int totalRequests;

  /// Number of successful transcription requests
  final int successfulRequests;

  /// Number of failed transcription requests
  final int failedRequests;

  /// Total time spent processing transcriptions
  @JsonKey(name: 'total_processing_time_ms')
  final Duration totalProcessingTime;

  /// Average processing time per request in milliseconds
  final double averageProcessingTime;

  /// Total audio minutes processed
  final int totalAudioMinutes;

  /// Timestamp of the last request
  final DateTime lastRequestTime;

  /// Usage statistics by provider
  final Map<String, ProviderUsageStats> providerStats;

  /// Usage statistics by day (ISO date string -> DailyUsageStats)
  final Map<String, DailyUsageStats> dailyStats;

  /// Error statistics by type
  final Map<String, int> errorCounts;

  /// Peak usage metrics
  final PeakUsageMetrics peakMetrics;

  TranscriptionUsageStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.totalProcessingTime,
    required this.averageProcessingTime,
    required this.totalAudioMinutes,
    required this.lastRequestTime,
    this.providerStats = const {},
    this.dailyStats = const {},
    this.errorCounts = const {},
    required this.peakMetrics,
  });

  /// Create empty usage statistics
  factory TranscriptionUsageStats.empty() {
    return TranscriptionUsageStats(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalProcessingTime: Duration.zero,
      averageProcessingTime: 0.0,
      totalAudioMinutes: 0,
      lastRequestTime: DateTime.now(),
      providerStats: {},
      dailyStats: {},
      errorCounts: {},
      peakMetrics: PeakUsageMetrics(),
    );
  }

  /// Calculate success rate as a percentage
  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  /// Calculate failure rate as a percentage
  double get failureRate {
    if (totalRequests == 0) return 0.0;
    return (failedRequests / totalRequests) * 100;
  }

  /// Get requests per day (based on time since first request)
  double get averageRequestsPerDay {
    if (totalRequests == 0) return 0.0;

    // Estimate based on time span and total requests
    final daysSinceFirst =
        DateTime.now().difference(lastRequestTime).inDays + 1;
    return totalRequests / daysSinceFirst;
  }

  /// Get average audio minutes per request
  double get averageAudioMinutesPerRequest {
    if (totalRequests == 0) return 0.0;
    return totalAudioMinutes / totalRequests;
  }

  /// Get processing efficiency (audio minutes / processing time)
  double get processingEfficiency {
    if (totalProcessingTime.inMinutes == 0) return 0.0;
    return totalAudioMinutes / totalProcessingTime.inMinutes;
  }

  /// Get most used provider
  String? get mostUsedProvider {
    if (providerStats.isEmpty) return null;

    String? topProvider;
    int maxRequests = 0;

    for (final entry in providerStats.entries) {
      if (entry.value.totalRequests > maxRequests) {
        maxRequests = entry.value.totalRequests;
        topProvider = entry.key;
      }
    }

    return topProvider;
  }

  /// Get most common error type
  String? get mostCommonError {
    if (errorCounts.isEmpty) return null;

    String? topError;
    int maxCount = 0;

    for (final entry in errorCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topError = entry.key;
      }
    }

    return topError;
  }

  /// Create updated stats with new request data
  TranscriptionUsageStats copyWithNewRequest({
    required bool success,
    required Duration processingTime,
    required int audioDurationMs,
    required String provider,
    String? errorType,
  }) {
    final newTotalRequests = totalRequests + 1;
    final newSuccessfulRequests =
        success ? successfulRequests + 1 : successfulRequests;
    final newFailedRequests = success ? failedRequests : failedRequests + 1;
    final newTotalProcessingTime = totalProcessingTime + processingTime;
    final newAverageProcessingTime =
        newTotalProcessingTime.inMilliseconds / newTotalRequests;
    final newTotalAudioMinutes =
        totalAudioMinutes + (audioDurationMs / 60000).round();
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Update provider stats
    final updatedProviderStats = Map<String, ProviderUsageStats>.from(
      providerStats,
    );
    final currentProviderStats =
        updatedProviderStats[provider] ?? ProviderUsageStats.empty();
    updatedProviderStats[provider] = currentProviderStats.copyWithNewRequest(
      success: success,
      processingTime: processingTime,
      audioDurationMs: audioDurationMs,
    );

    // Update daily stats
    final updatedDailyStats = Map<String, DailyUsageStats>.from(dailyStats);
    final currentDailyStats =
        updatedDailyStats[todayKey] ?? DailyUsageStats.empty();
    updatedDailyStats[todayKey] = currentDailyStats.copyWithNewRequest(
      success: success,
      processingTime: processingTime,
      audioDurationMs: audioDurationMs,
    );

    // Update error counts
    final updatedErrorCounts = Map<String, int>.from(errorCounts);
    if (!success && errorType != null) {
      updatedErrorCounts[errorType] = (updatedErrorCounts[errorType] ?? 0) + 1;
    }

    // Update peak metrics
    final updatedPeakMetrics = peakMetrics.updateWithNewRequest(
      processingTime: processingTime,
      audioDurationMs: audioDurationMs,
      requestTime: now,
    );

    return TranscriptionUsageStats(
      totalRequests: newTotalRequests,
      successfulRequests: newSuccessfulRequests,
      failedRequests: newFailedRequests,
      totalProcessingTime: newTotalProcessingTime,
      averageProcessingTime: newAverageProcessingTime,
      totalAudioMinutes: newTotalAudioMinutes,
      lastRequestTime: now,
      providerStats: updatedProviderStats,
      dailyStats: updatedDailyStats,
      errorCounts: updatedErrorCounts,
      peakMetrics: updatedPeakMetrics,
    );
  }

  /// JSON serialization
  factory TranscriptionUsageStats.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionUsageStatsFromJson(json);

  /// JSON deserialization
  Map<String, dynamic> toJson() => _$TranscriptionUsageStatsToJson(this);

  @override
  String toString() {
    return 'TranscriptionUsageStats('
        'requests: $totalRequests, '
        'success_rate: ${successRate.toStringAsFixed(1)}%, '
        'total_audio: ${totalAudioMinutes}min, '
        'avg_processing: ${averageProcessingTime.toStringAsFixed(0)}ms'
        ')';
  }
}

/// Usage statistics for a specific provider
@JsonSerializable()
class ProviderUsageStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration totalProcessingTime;
  final int totalAudioMinutes;
  final DateTime lastUsed;

  const ProviderUsageStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.totalProcessingTime,
    required this.totalAudioMinutes,
    required this.lastUsed,
  });

  factory ProviderUsageStats.empty() {
    return ProviderUsageStats(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalProcessingTime: Duration.zero,
      totalAudioMinutes: 0,
      lastUsed: DateTime.now(),
    );
  }

  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  double get averageProcessingTime {
    if (totalRequests == 0) return 0.0;
    return totalProcessingTime.inMilliseconds / totalRequests;
  }

  ProviderUsageStats copyWithNewRequest({
    required bool success,
    required Duration processingTime,
    required int audioDurationMs,
  }) {
    return ProviderUsageStats(
      totalRequests: totalRequests + 1,
      successfulRequests: success ? successfulRequests + 1 : successfulRequests,
      failedRequests: success ? failedRequests : failedRequests + 1,
      totalProcessingTime: totalProcessingTime + processingTime,
      totalAudioMinutes: totalAudioMinutes + (audioDurationMs / 60000).round(),
      lastUsed: DateTime.now(),
    );
  }

  factory ProviderUsageStats.fromJson(Map<String, dynamic> json) =>
      _$ProviderUsageStatsFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderUsageStatsToJson(this);
}

/// Daily usage statistics
@JsonSerializable()
class DailyUsageStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration totalProcessingTime;
  final int totalAudioMinutes;
  final DateTime date;

  const DailyUsageStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.totalProcessingTime,
    required this.totalAudioMinutes,
    required this.date,
  });

  factory DailyUsageStats.empty() {
    return DailyUsageStats(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalProcessingTime: Duration.zero,
      totalAudioMinutes: 0,
      date: DateTime.now(),
    );
  }

  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  double get averageProcessingTime {
    if (totalRequests == 0) return 0.0;
    return totalProcessingTime.inMilliseconds / totalRequests;
  }

  DailyUsageStats copyWithNewRequest({
    required bool success,
    required Duration processingTime,
    required int audioDurationMs,
  }) {
    return DailyUsageStats(
      totalRequests: totalRequests + 1,
      successfulRequests: success ? successfulRequests + 1 : successfulRequests,
      failedRequests: success ? failedRequests : failedRequests + 1,
      totalProcessingTime: totalProcessingTime + processingTime,
      totalAudioMinutes: totalAudioMinutes + (audioDurationMs / 60000).round(),
      date: date,
    );
  }

  factory DailyUsageStats.fromJson(Map<String, dynamic> json) =>
      _$DailyUsageStatsFromJson(json);

  Map<String, dynamic> toJson() => _$DailyUsageStatsToJson(this);
}

/// Peak usage metrics
@JsonSerializable()
class PeakUsageMetrics {
  final Duration longestProcessingTime;
  final int largestAudioMinutes;
  final int peakDailyRequests;
  final DateTime peakDailyRequestsDate;
  final int peakHourlyRequests;
  final DateTime peakHourlyRequestsTime;

  PeakUsageMetrics({
    this.longestProcessingTime = Duration.zero,
    this.largestAudioMinutes = 0,
    this.peakDailyRequests = 0,
    DateTime? peakDailyRequestsDate,
    this.peakHourlyRequests = 0,
    DateTime? peakHourlyRequestsTime,
  })  : peakDailyRequestsDate =
            peakDailyRequestsDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        peakHourlyRequestsTime =
            peakHourlyRequestsTime ?? DateTime.fromMillisecondsSinceEpoch(0);

  PeakUsageMetrics updateWithNewRequest({
    required Duration processingTime,
    required int audioDurationMs,
    required DateTime requestTime,
  }) {
    final audioMinutes = (audioDurationMs / 60000).round();

    return PeakUsageMetrics(
      longestProcessingTime: processingTime > longestProcessingTime
          ? processingTime
          : longestProcessingTime,
      largestAudioMinutes: audioMinutes > largestAudioMinutes
          ? audioMinutes
          : largestAudioMinutes,
      peakDailyRequests: peakDailyRequests, // Updated separately
      peakDailyRequestsDate: peakDailyRequestsDate,
      peakHourlyRequests: peakHourlyRequests, // Updated separately
      peakHourlyRequestsTime: peakHourlyRequestsTime,
    );
  }

  factory PeakUsageMetrics.fromJson(Map<String, dynamic> json) =>
      _$PeakUsageMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$PeakUsageMetricsToJson(this);
}
