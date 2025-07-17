/// Tests for Google Speech-to-Text service implementation
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/google_speech_service.dart';
import 'package:meeting_summarizer/core/models/transcription_request.dart';
import 'package:meeting_summarizer/core/enums/transcription_language.dart';
import 'package:meeting_summarizer/core/services/transcription_error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GoogleSpeechService', () {
    late GoogleSpeechService service;

    setUp(() {
      service = GoogleSpeechService.getInstance();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should be a singleton', () {
      final instance1 = GoogleSpeechService.getInstance();
      final instance2 = GoogleSpeechService.getInstance();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize without API key or service account path', () async {
      expect(
        () async => await service.initialize(),
        throwsA(isA<TranscriptionError>()),
      );
    });

    test('should report service as unavailable when not initialized', () async {
      final isAvailable = await service.isServiceAvailable();
      expect(isAvailable, isFalse);
    });

    test('should return supported languages', () async {
      final languages = await service.getSupportedLanguages();
      expect(languages, isNotEmpty);
      expect(languages, contains(TranscriptionLanguage.english));
      expect(languages, contains(TranscriptionLanguage.spanish));
    });

    test('should create default transcription request', () {
      final request = TranscriptionRequest.withDefaults(
        language: TranscriptionLanguage.english,
      );

      expect(request.language, equals(TranscriptionLanguage.english));
      expect(request.enableTimestamps, isTrue);
      expect(request.quality, equals(TranscriptionQuality.balanced));
    });

    test('should create high-quality transcription request', () {
      final request = TranscriptionRequest.highQuality(
        language: TranscriptionLanguage.english,
        customVocabulary: ['AI', 'machine learning'],
      );

      expect(request.language, equals(TranscriptionLanguage.english));
      expect(request.enableTimestamps, isTrue);
      expect(request.enableWordTimestamps, isTrue);
      expect(request.enableSpeakerDiarization, isTrue);
      expect(request.quality, equals(TranscriptionQuality.high));
      expect(request.customVocabulary, contains('AI'));
    });

    test('should create fast transcription request', () {
      final request = TranscriptionRequest.fast(
        language: TranscriptionLanguage.english,
      );

      expect(request.language, equals(TranscriptionLanguage.english));
      expect(request.quality, equals(TranscriptionQuality.fast));
      expect(request.enableTimestamps, isFalse);
      expect(request.enableWordTimestamps, isFalse);
    });

    test('should get usage statistics', () async {
      final stats = await service.getUsageStats();
      expect(stats, isNotNull);
      expect(stats.totalRequests, isA<int>());
      expect(stats.successfulRequests, isA<int>());
      expect(stats.failedRequests, isA<int>());
    });

    test('should handle audio file validation', () async {
      // Create a mock empty file
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_empty.wav');
      await testFile.create();
      await testFile.writeAsBytes([]);

      final request = TranscriptionRequest.withDefaults();

      expect(
        () async => await service.transcribeAudioFile(testFile, request),
        throwsA(isA<TranscriptionError>()),
      );

      // Clean up
      await testFile.delete();
    });

    test('should handle unsupported audio format', () async {
      // Create a mock file with unsupported extension
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test.unsupported');
      await testFile.create();
      await testFile.writeAsBytes([1, 2, 3, 4]);

      final request = TranscriptionRequest.withDefaults();

      expect(
        () async => await service.transcribeAudioFile(testFile, request),
        throwsA(isA<TranscriptionError>()),
      );

      // Clean up
      await testFile.delete();
    });

    test('should validate audio bytes', () async {
      final request = TranscriptionRequest.withDefaults();

      expect(
        () async => await service.transcribeAudioBytes([], request),
        throwsA(isA<TranscriptionError>()),
      );
    });

    test('should handle language detection without initialization', () async {
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test.wav');
      await testFile.create();
      await testFile.writeAsBytes([1, 2, 3, 4]);

      final language = await service.detectLanguage(testFile);
      expect(language, isNull);

      // Clean up
      await testFile.delete();
    });

    group('Google Speech language extension', () {
      test('should provide correct Google Speech language codes', () {
        expect(TranscriptionLanguage.english.googleSpeechCode, equals('en-US'));
        expect(TranscriptionLanguage.spanish.googleSpeechCode, equals('es-ES'));
        expect(TranscriptionLanguage.french.googleSpeechCode, equals('fr-FR'));
        expect(TranscriptionLanguage.german.googleSpeechCode, equals('de-DE'));
        expect(TranscriptionLanguage.italian.googleSpeechCode, equals('it-IT'));
        expect(
          TranscriptionLanguage.portuguese.googleSpeechCode,
          equals('pt-BR'),
        );
        expect(TranscriptionLanguage.russian.googleSpeechCode, equals('ru-RU'));
        expect(
          TranscriptionLanguage.japanese.googleSpeechCode,
          equals('ja-JP'),
        );
        expect(TranscriptionLanguage.korean.googleSpeechCode, equals('ko-KR'));
        expect(
          TranscriptionLanguage.chineseSimplified.googleSpeechCode,
          equals('zh-CN'),
        );
        expect(TranscriptionLanguage.arabic.googleSpeechCode, equals('ar-SA'));
        expect(TranscriptionLanguage.hindi.googleSpeechCode, equals('hi-IN'));
        expect(TranscriptionLanguage.dutch.googleSpeechCode, equals('nl-NL'));
        expect(TranscriptionLanguage.polish.googleSpeechCode, equals('pl-PL'));
        expect(TranscriptionLanguage.turkish.googleSpeechCode, equals('tr-TR'));
        expect(TranscriptionLanguage.auto.googleSpeechCode, isNull);
      });
    });

    group('Error handling', () {
      test('should handle network errors gracefully', () async {
        // This test would require mocking HTTP client
        // For now, just verify the service can handle initialization errors
        expect(
          () async => await service.initializeWithCredentials(apiKey: ''),
          throwsA(isA<TranscriptionError>()),
        );
      });
    });
  });
}
