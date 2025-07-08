/// Interface for audio transcription services
///
/// This interface defines the contract for all transcription service implementations,
/// allowing for easy swapping between different providers (OpenAI Whisper, local models, etc.)
library;

import 'dart:io';

import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
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
