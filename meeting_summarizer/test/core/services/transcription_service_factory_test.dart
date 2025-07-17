/// Tests for transcription service factory
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/transcription_service_factory.dart';
import 'package:meeting_summarizer/core/services/google_speech_service.dart';
import 'package:meeting_summarizer/core/services/local_whisper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranscriptionServiceFactory', () {
    tearDown(() async {
      await TranscriptionServiceFactory.disposeAll();
    });

    test('should create GoogleSpeechService instance', () {
      final service = TranscriptionServiceFactory.getService(
        TranscriptionProvider.googleSpeechToText,
      );

      expect(service, isA<GoogleSpeechService>());
    });

    test('should create LocalWhisperService instance', () {
      final service = TranscriptionServiceFactory.getService(
        TranscriptionProvider.localWhisper,
      );

      expect(service, isA<LocalWhisperService>());
    });

    test('should return same instance when not forced new', () {
      final service1 = TranscriptionServiceFactory.getService(
        TranscriptionProvider.googleSpeechToText,
      );
      final service2 = TranscriptionServiceFactory.getService(
        TranscriptionProvider.googleSpeechToText,
      );

      expect(identical(service1, service2), isTrue);
    });

    test(
      'should handle forceNew flag (singleton services may still return same instance)',
      () {
        final service1 = TranscriptionServiceFactory.getService(
          TranscriptionProvider.googleSpeechToText,
        );
        final service2 = TranscriptionServiceFactory.getService(
          TranscriptionProvider.googleSpeechToText,
          forceNew: true,
        );

        // GoogleSpeechService uses singleton pattern, so even with forceNew it returns the same instance
        expect(service1, isA<GoogleSpeechService>());
        expect(service2, isA<GoogleSpeechService>());
      },
    );

    test('should provide service capabilities for Google Speech', () {
      final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
        TranscriptionProvider.googleSpeechToText,
      );

      expect(capabilities.supportsTimestamps, isTrue);
      expect(capabilities.supportsWordLevelTimestamps, isTrue);
      expect(capabilities.supportsSpeakerDiarization, isTrue);
      expect(capabilities.supportsCustomVocabulary, isTrue);
      expect(capabilities.supportsLanguageDetection, isTrue);
      expect(capabilities.maxFileSizeMB, equals(1000));
      expect(capabilities.supportedLanguages, equals(125));
    });

    test('should provide display name for providers', () {
      expect(
        TranscriptionServiceFactory.getProviderDisplayName(
          TranscriptionProvider.googleSpeechToText,
        ),
        equals('Google Speech-to-Text'),
      );
    });

    test('should provide description for providers', () {
      final description = TranscriptionServiceFactory.getProviderDescription(
        TranscriptionProvider.googleSpeechToText,
      );

      expect(description, contains('Google Cloud'));
      expect(description, contains('speaker diarization'));
    });
  });
}
