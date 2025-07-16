/// Tests for LocalWhisperService
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/local_whisper_service.dart';
import 'package:meeting_summarizer/core/models/transcription_request.dart';
import 'package:meeting_summarizer/core/enums/transcription_language.dart';
import 'package:meeting_summarizer/core/services/transcription_error_handler.dart';

void main() {
  group('LocalWhisperService', () {
    late LocalWhisperService service;

    setUp(() {
      service = LocalWhisperService.getInstance();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        final instance1 = LocalWhisperService.getInstance();
        final instance2 = LocalWhisperService.getInstance();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Model Management', () {
      test('should list available models', () {
        final models = service.getAvailableModels();
        expect(models, isNotEmpty);
        expect(models.any((m) => m.name == 'whisper-base'), isTrue);
        expect(models.any((m) => m.name == 'whisper-tiny'), isTrue);
        expect(models.any((m) => m.name == 'whisper-small'), isTrue);
      });
    });

    group('Error Handling', () {
      test('should throw configuration error when not initialized', () async {
        final audioFile = File('test_audio.wav');
        final request = TranscriptionRequest(
          language: TranscriptionLanguage.auto,
        );

        expect(
          () => service.transcribeAudioFile(audioFile, request),
          throwsA(
            isA<TranscriptionError>().having(
              (e) => e.type,
              'type',
              TranscriptionErrorType.configurationError,
            ),
          ),
        );
      });

      test(
        'should throw configuration error for invalid files when not initialized',
        () async {
          final invalidFile = File('nonexistent.wav');
          final request = TranscriptionRequest(
            language: TranscriptionLanguage.auto,
          );

          // The service checks initialization first, so we expect configurationError
          expect(
            () => service.transcribeAudioFile(invalidFile, request),
            throwsA(
              isA<TranscriptionError>().having(
                (e) => e.type,
                'type',
                TranscriptionErrorType.configurationError,
              ),
            ),
          );
        },
      );
    });
  });
}
