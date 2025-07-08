/// Interface for audio transcription services
///
/// This interface defines the contract for all transcription service implementations,
/// allowing for easy swapping between different providers (OpenAI Whisper, local models, etc.)
library;

import 'dart:io';

import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../enums/transcription_language.dart';

/// Abstract interface for transcription services
abstract interface class TranscriptionServiceInterface {
  /// Initialize the transcription service
  Future<void> initialize();

  /// Check if the service is available and configured
  Future<bool> isServiceAvailable();

  /// Transcribe an audio file
  ///
  /// [audioFile] - The audio file to transcribe
  /// [request] - Configuration for the transcription request
  ///
  /// Returns a [TranscriptionResult] containing the transcribed text and metadata
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  );

  /// Transcribe audio from bytes
  ///
  /// [audioBytes] - Raw audio data
  /// [request] - Configuration for the transcription request
  ///
  /// Returns a [TranscriptionResult] containing the transcribed text and metadata
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  );

  /// Get supported languages for transcription
  Future<List<TranscriptionLanguage>> getSupportedLanguages();

  /// Detect the language of the audio
  ///
  /// [audioFile] - The audio file to analyze
  ///
  /// Returns the detected language code
  Future<TranscriptionLanguage?> detectLanguage(File audioFile);

  /// Get the current usage statistics
  Future<TranscriptionUsageStats> getUsageStats();

  /// Dispose of resources
  Future<void> dispose();
}

/// Statistics about transcription service usage
class TranscriptionUsageStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final Duration totalProcessingTime;
  final double averageProcessingTime;
  final int totalAudioMinutes;
  final DateTime lastRequestTime;

  const TranscriptionUsageStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.totalProcessingTime,
    required this.averageProcessingTime,
    required this.totalAudioMinutes,
    required this.lastRequestTime,
  });

  /// Success rate as a percentage
  double get successRate {
    if (totalRequests == 0) return 0.0;
    return (successfulRequests / totalRequests) * 100;
  }

  /// Failure rate as a percentage
  double get failureRate {
    if (totalRequests == 0) return 0.0;
    return (failedRequests / totalRequests) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'totalProcessingTimeMs': totalProcessingTime.inMilliseconds,
      'averageProcessingTimeMs': averageProcessingTime,
      'totalAudioMinutes': totalAudioMinutes,
      'lastRequestTime': lastRequestTime.toIso8601String(),
      'successRate': successRate,
      'failureRate': failureRate,
    };
  }

  factory TranscriptionUsageStats.fromJson(Map<String, dynamic> json) {
    return TranscriptionUsageStats(
      totalRequests: json['totalRequests'] as int,
      successfulRequests: json['successfulRequests'] as int,
      failedRequests: json['failedRequests'] as int,
      totalProcessingTime: Duration(
        milliseconds: json['totalProcessingTimeMs'] as int,
      ),
      averageProcessingTime: json['averageProcessingTimeMs'] as double,
      totalAudioMinutes: json['totalAudioMinutes'] as int,
      lastRequestTime: DateTime.parse(json['lastRequestTime'] as String),
    );
  }
}
