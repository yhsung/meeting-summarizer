// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_usage_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscriptionUsageStats _$TranscriptionUsageStatsFromJson(
  Map<String, dynamic> json,
) => TranscriptionUsageStats(
  totalRequests: (json['totalRequests'] as num).toInt(),
  successfulRequests: (json['successfulRequests'] as num).toInt(),
  failedRequests: (json['failedRequests'] as num).toInt(),
  totalProcessingTime: Duration(
    microseconds: (json['total_processing_time_ms'] as num).toInt(),
  ),
  averageProcessingTime: (json['averageProcessingTime'] as num).toDouble(),
  totalAudioMinutes: (json['totalAudioMinutes'] as num).toInt(),
  lastRequestTime: DateTime.parse(json['lastRequestTime'] as String),
  providerStats:
      (json['providerStats'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, ProviderUsageStats.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
  dailyStats:
      (json['dailyStats'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, DailyUsageStats.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
  errorCounts:
      (json['errorCounts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  peakMetrics: PeakUsageMetrics.fromJson(
    json['peakMetrics'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$TranscriptionUsageStatsToJson(
  TranscriptionUsageStats instance,
) => <String, dynamic>{
  'totalRequests': instance.totalRequests,
  'successfulRequests': instance.successfulRequests,
  'failedRequests': instance.failedRequests,
  'total_processing_time_ms': instance.totalProcessingTime.inMicroseconds,
  'averageProcessingTime': instance.averageProcessingTime,
  'totalAudioMinutes': instance.totalAudioMinutes,
  'lastRequestTime': instance.lastRequestTime.toIso8601String(),
  'providerStats': instance.providerStats,
  'dailyStats': instance.dailyStats,
  'errorCounts': instance.errorCounts,
  'peakMetrics': instance.peakMetrics,
};

ProviderUsageStats _$ProviderUsageStatsFromJson(Map<String, dynamic> json) =>
    ProviderUsageStats(
      totalRequests: (json['totalRequests'] as num).toInt(),
      successfulRequests: (json['successfulRequests'] as num).toInt(),
      failedRequests: (json['failedRequests'] as num).toInt(),
      totalProcessingTime: Duration(
        microseconds: (json['totalProcessingTime'] as num).toInt(),
      ),
      totalAudioMinutes: (json['totalAudioMinutes'] as num).toInt(),
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );

Map<String, dynamic> _$ProviderUsageStatsToJson(ProviderUsageStats instance) =>
    <String, dynamic>{
      'totalRequests': instance.totalRequests,
      'successfulRequests': instance.successfulRequests,
      'failedRequests': instance.failedRequests,
      'totalProcessingTime': instance.totalProcessingTime.inMicroseconds,
      'totalAudioMinutes': instance.totalAudioMinutes,
      'lastUsed': instance.lastUsed.toIso8601String(),
    };

DailyUsageStats _$DailyUsageStatsFromJson(Map<String, dynamic> json) =>
    DailyUsageStats(
      totalRequests: (json['totalRequests'] as num).toInt(),
      successfulRequests: (json['successfulRequests'] as num).toInt(),
      failedRequests: (json['failedRequests'] as num).toInt(),
      totalProcessingTime: Duration(
        microseconds: (json['totalProcessingTime'] as num).toInt(),
      ),
      totalAudioMinutes: (json['totalAudioMinutes'] as num).toInt(),
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$DailyUsageStatsToJson(DailyUsageStats instance) =>
    <String, dynamic>{
      'totalRequests': instance.totalRequests,
      'successfulRequests': instance.successfulRequests,
      'failedRequests': instance.failedRequests,
      'totalProcessingTime': instance.totalProcessingTime.inMicroseconds,
      'totalAudioMinutes': instance.totalAudioMinutes,
      'date': instance.date.toIso8601String(),
    };

PeakUsageMetrics _$PeakUsageMetricsFromJson(Map<String, dynamic> json) =>
    PeakUsageMetrics(
      longestProcessingTime: json['longestProcessingTime'] == null
          ? Duration.zero
          : Duration(
              microseconds: (json['longestProcessingTime'] as num).toInt(),
            ),
      largestAudioMinutes: (json['largestAudioMinutes'] as num?)?.toInt() ?? 0,
      peakDailyRequests: (json['peakDailyRequests'] as num?)?.toInt() ?? 0,
      peakDailyRequestsDate: json['peakDailyRequestsDate'] == null
          ? null
          : DateTime.parse(json['peakDailyRequestsDate'] as String),
      peakHourlyRequests: (json['peakHourlyRequests'] as num?)?.toInt() ?? 0,
      peakHourlyRequestsTime: json['peakHourlyRequestsTime'] == null
          ? null
          : DateTime.parse(json['peakHourlyRequestsTime'] as String),
    );

Map<String, dynamic> _$PeakUsageMetricsToJson(
  PeakUsageMetrics instance,
) => <String, dynamic>{
  'longestProcessingTime': instance.longestProcessingTime.inMicroseconds,
  'largestAudioMinutes': instance.largestAudioMinutes,
  'peakDailyRequests': instance.peakDailyRequests,
  'peakDailyRequestsDate': instance.peakDailyRequestsDate.toIso8601String(),
  'peakHourlyRequests': instance.peakHourlyRequests,
  'peakHourlyRequestsTime': instance.peakHourlyRequestsTime.toIso8601String(),
};
