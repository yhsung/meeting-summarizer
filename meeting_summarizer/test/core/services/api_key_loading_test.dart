/// Test Google Speech service API key loading from settings vs environment
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/google_speech_service.dart';

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

  group('Google Speech API Key Loading Priority', () {
    test('should attempt to load API key from app settings first', () async {
      final service = GoogleSpeechService.getInstance();

      // Get initialization status which shows credential sources
      final status = await service.getInitializationStatus();
      final credentialsFound =
          status['credentialsFound'] as Map<String, dynamic>;

      // Verify that app settings is checked first
      expect(
        credentialsFound.containsKey('apiKeyFromSettings'),
        isTrue,
        reason: 'Should check for API key in app settings',
      );
      expect(
        credentialsFound.containsKey('apiKeyFromEnv'),
        isTrue,
        reason: 'Should also check environment variables',
      );

      // Verify check sources are documented
      expect(
        credentialsFound['checkSources'],
        contains('App Settings (google provider)'),
        reason: 'Should document app settings as a check source',
      );
      expect(
        credentialsFound['checkSources'],
        contains('Environment Variables'),
        reason: 'Should document environment variables as a check source',
      );

      // In test environment, both should be false due to missing plugins
      expect(
        credentialsFound['apiKeyFromSettings'],
        isFalse,
        reason: 'No API key in test environment settings',
      );
      expect(
        credentialsFound['apiKeyFromEnv'],
        isFalse,
        reason: 'No API key in test environment variables',
      );

      await service.dispose();
    });

    test('should include app settings in setup instructions', () async {
      final service = GoogleSpeechService.getInstance();

      final status = await service.getInitializationStatus();
      final setupSteps = status['setupSteps'] as List<String>;

      // Verify that app settings configuration is mentioned in setup steps
      final hasSettingsInstruction = setupSteps.any(
        (step) =>
            step.contains('Settings') && step.contains('API Configuration'),
      );

      expect(
        hasSettingsInstruction,
        isTrue,
        reason: 'Setup steps should mention app settings configuration',
      );

      // Verify the settings instruction comes before environment variables
      final settingsStepIndex = setupSteps.indexWhere(
        (step) =>
            step.contains('Settings') && step.contains('API Configuration'),
      );
      final envStepIndex = setupSteps.indexWhere(
        (step) => step.contains('environment variable'),
      );

      expect(
        settingsStepIndex,
        lessThan(envStepIndex),
        reason:
            'App settings instruction should come before environment variables',
      );

      await service.dispose();
    });

    test('should handle API key service errors gracefully', () async {
      final service = GoogleSpeechService.getInstance();

      // This should fail due to missing credentials, but not crash due to API key service errors
      try {
        await service.initialize();
        fail('Should have thrown an error due to missing credentials');
      } catch (e) {
        // Should get a TranscriptionError, not a platform exception
        expect(
          e.toString(),
          contains('API key'),
          reason:
              'Should get meaningful error about missing API key, not platform errors',
        );
      }

      await service.dispose();
    });

    test('should show credential sources in status', () async {
      final service = GoogleSpeechService.getInstance();

      final status = await service.getInitializationStatus();
      final credentialsFound =
          status['credentialsFound'] as Map<String, dynamic>;

      // Verify all expected credential sources are documented
      final checkSources = credentialsFound['checkSources'] as List<String>;
      expect(checkSources, contains('App Settings (google provider)'));
      expect(checkSources, contains('Environment Variables'));
      expect(checkSources, contains('Service Account File'));

      // Verify environment variables are still listed
      final envVars =
          credentialsFound['environmentVariablesChecked'] as List<String>;
      expect(envVars, contains('GOOGLE_CLOUD_API_KEY'));
      expect(envVars, contains('GOOGLE_API_KEY'));
      expect(envVars, contains('GOOGLE_APPLICATION_CREDENTIALS'));

      await service.dispose();
    });
  });
}
