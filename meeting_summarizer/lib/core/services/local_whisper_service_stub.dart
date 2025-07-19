/// Stub implementation of LocalWhisperService for web platform
///
/// This stub implementation throws UnsupportedError for all operations
/// since local Whisper models cannot run on web platform.
library;

import 'dart:developer';
import 'dart:io';

import 'transcription_service_interface.dart';
import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
import '../enums/transcription_language.dart';

/// Stub implementation of LocalWhisperService for web platform
class LocalWhisperService implements TranscriptionServiceInterface {
  // Singleton pattern
  static LocalWhisperService? _instance;
  static LocalWhisperService getInstance() {
    _instance ??= LocalWhisperService._internal();
    return _instance!;
  }

  // Private constructor
  LocalWhisperService._internal();

  @override
  Future<void> initialize({
    Function(double progress, String status)? onProgress,
  }) async {
    throw UnsupportedError(
      'Local Whisper service is not supported on web platform',
    );
  }

  @override
  Future<bool> isServiceAvailable() async {
    log('LocalWhisperService: Not available on web platform');
    return false;
  }

  Future<TranscriptionResult> transcribe(TranscriptionRequest request) async {
    throw UnsupportedError(
      'Local Whisper transcription is not supported on web platform',
    );
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    throw UnsupportedError(
      'Local Whisper transcription is not supported on web platform',
    );
  }

  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    throw UnsupportedError(
      'Local Whisper transcription is not supported on web platform',
    );
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    throw UnsupportedError(
      'Language detection is not supported on web platform',
    );
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    return [];
  }

  Future<bool> validateConfiguration() async {
    return false;
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    return TranscriptionUsageStats(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      totalProcessingTime: Duration.zero,
      averageProcessingTime: 0.0,
      totalAudioMinutes: 0,
      lastRequestTime: DateTime.now(),
      peakMetrics: PeakUsageMetrics(),
    );
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose for stub
  }

  String get serviceName => 'Local Whisper (Web Stub)';

  String get serviceDescription =>
      'Local Whisper is not supported on web platform';
}
