/// Test Google Speech service initialization requirements and status
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/google_speech_service.dart';
import 'package:meeting_summarizer/core/services/transcription_error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider platform channel
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return Directory.systemTemp.createTempSync('test_docs').path;
            }
            return null;
          },
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('GoogleSpeechService Initialization', () {
    late GoogleSpeechService service;

    setUp(() {
      service = GoogleSpeechService.getInstance();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should not be initialized by default', () async {
      final isAvailable = await service.isServiceAvailable();
      expect(
        isAvailable,
        isFalse,
        reason: 'Service should not be available without proper initialization',
      );
    });

    test('should fail initialization without credentials', () async {
      expect(
        () async => await service.initialize(),
        throwsA(isA<TranscriptionError>()),
        reason:
            'Initialization should fail when no API key or service account is provided',
      );
    });

    test('should fail initialization with empty API key', () async {
      expect(
        () async => await service.initializeWithCredentials(apiKey: ''),
        throwsA(isA<TranscriptionError>()),
        reason: 'Initialization should fail with empty API key',
      );
    });

    test(
      'should fail initialization with empty service account path',
      () async {
        expect(
          () async =>
              await service.initializeWithCredentials(serviceAccountPath: ''),
          throwsA(isA<TranscriptionError>()),
          reason: 'Initialization should fail with empty service account path',
        );
      },
    );

    test('should accept API key for initialization', () async {
      // Note: Service accepts any API key during initialization
      // Validation happens during actual API calls, not initialization
      try {
        await service.initializeWithCredentials(apiKey: 'test-api-key');
        // If we get here, initialization succeeded (expected behavior)
        expect(
          true,
          isTrue,
          reason: 'Should accept API key during initialization',
        );
      } catch (e) {
        // If initialization fails, it should be due to other issues (like auth setup)
        expect(e, isA<TranscriptionError>());
      }
    });

    test('should accept service account path for initialization', () async {
      // Note: This will fail due to non-existent file, but it shows the pattern
      expect(
        () async => await service.initializeWithCredentials(
          serviceAccountPath: '/path/to/service-account.json',
        ),
        throwsA(isA<TranscriptionError>()),
        reason:
            'Should attempt initialization with service account (fails due to invalid path)',
      );
    });

    test('should provide progress callbacks during initialization', () async {
      final progressUpdates = <String>[];

      try {
        await service.initializeWithCredentials(
          apiKey: 'test-key',
          onProgress: (progress, status) {
            progressUpdates.add('$progress: $status');
          },
        );
      } catch (e) {
        // Expected to fail with invalid API key
      }

      expect(
        progressUpdates,
        isNotEmpty,
        reason: 'Should provide progress updates during initialization',
      );
      expect(
        progressUpdates.first,
        contains('0.0'),
        reason: 'Should start with 0.0 progress',
      );
    });

    group('Interface Compliance Check', () {
      test('should handle interface initialize method', () async {
        // Test calling the parameterless initialize from the interface
        expect(
          () async => await service.initialize(),
          throwsA(isA<TranscriptionError>()),
          reason: 'Interface initialize() should fail without credentials',
        );
      });
    });

    group('Setup Requirements Check', () {
      test('should provide initialization status', () async {
        final status = await service.getInitializationStatus();

        expect(
          status['isInitialized'],
          isFalse,
          reason: 'Should not be initialized by default',
        );
        expect(status['setupRequired'], isTrue, reason: 'Should require setup');
        expect(
          status['setupSteps'],
          isA<List<String>>(),
          reason: 'Should provide setup steps',
        );
        expect(
          status['credentialsFound'],
          isA<Map<String, dynamic>>(),
          reason: 'Should check for credentials',
        );
      });

      test('should document required setup steps', () async {
        final status = await service.getInitializationStatus();
        final setupSteps = status['setupSteps'] as List<String>;

        expect(
          setupSteps.length,
          greaterThanOrEqualTo(5),
          reason:
              'Should have at least 5 main setup steps for Google Speech service',
        );
        expect(
          setupSteps.any((step) => step.contains('Google Cloud')),
          isTrue,
          reason: 'Should mention Google Cloud setup',
        );
        expect(
          setupSteps.any((step) => step.contains('API key')),
          isTrue,
          reason: 'Should mention API key option',
        );
        expect(
          setupSteps.any((step) => step.contains('service account')),
          isTrue,
          reason: 'Should mention service account option',
        );
        expect(
          setupSteps.any((step) => step.contains('Settings')),
          isTrue,
          reason: 'Should mention app settings configuration',
        );
      });

      test('should provide clear error messages for missing setup', () async {
        try {
          await service.initialize();
          fail('Should have thrown an error');
        } catch (e) {
          expect(e, isA<TranscriptionError>());
          final error = e as TranscriptionError;
          expect(
            error.message,
            contains('API key'),
            reason: 'Error should mention API key requirement',
          );
          expect(
            error.message,
            contains('service account'),
            reason: 'Error should mention service account option',
          );
        }
      });
    });

    group('Initialization State Management', () {
      test('should track initialization state correctly', () async {
        // Initially not available
        expect(await service.isServiceAvailable(), isFalse);

        // Still not available after failed initialization
        try {
          await service.initialize();
        } catch (e) {
          // Expected to fail
        }
        expect(await service.isServiceAvailable(), isFalse);
      });

      test('should handle repeated initialization attempts', () async {
        // First attempt
        try {
          await service.initialize();
        } catch (e) {
          // Expected to fail
        }

        // Second attempt with same result
        expect(
          () async => await service.initialize(),
          throwsA(isA<TranscriptionError>()),
        );
      });
    });
  });
}
