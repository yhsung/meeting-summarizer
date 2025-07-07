import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/services/permission_service_interface.dart';

void main() {
  group('Permission Models Tests', () {
    group('PermissionConfig', () {
      test('should create config with default values', () {
        const config = PermissionConfig();

        expect(config.showRationale, isTrue);
        expect(config.autoRedirectToSettings, isTrue);
        expect(config.enableRetry, isTrue);
        expect(config.maxRetryAttempts, equals(3));
        expect(config.retryDelay, equals(Duration(seconds: 1)));
        expect(config.rationaleMessage, isNull);
        expect(config.rationaleTitle, isNull);
        expect(config.settingsRedirectMessage, isNull);
      });

      test('should create config with custom values', () {
        const config = PermissionConfig(
          showRationale: false,
          rationaleMessage: 'Custom message',
          rationaleTitle: 'Custom Title',
          autoRedirectToSettings: false,
          settingsRedirectMessage: 'Custom settings message',
          enableRetry: false,
          maxRetryAttempts: 5,
          retryDelay: Duration(seconds: 2),
        );

        expect(config.showRationale, isFalse);
        expect(config.rationaleMessage, equals('Custom message'));
        expect(config.rationaleTitle, equals('Custom Title'));
        expect(config.autoRedirectToSettings, isFalse);
        expect(
          config.settingsRedirectMessage,
          equals('Custom settings message'),
        );
        expect(config.enableRetry, isFalse);
        expect(config.maxRetryAttempts, equals(5));
        expect(config.retryDelay, equals(Duration(seconds: 2)));
      });

      test('should support copyWith functionality', () {
        const originalConfig = PermissionConfig(
          maxRetryAttempts: 3,
          rationaleMessage: 'Original message',
        );

        final updatedConfig = originalConfig.copyWith(
          maxRetryAttempts: 5,
          enableRetry: false,
          rationaleTitle: 'New Title',
        );

        expect(updatedConfig.maxRetryAttempts, equals(5));
        expect(updatedConfig.enableRetry, isFalse);
        expect(updatedConfig.rationaleTitle, equals('New Title'));
        // Should preserve original values not updated
        expect(
          updatedConfig.showRationale,
          equals(originalConfig.showRationale),
        );
        expect(
          updatedConfig.rationaleMessage,
          equals(originalConfig.rationaleMessage),
        );
        expect(
          updatedConfig.autoRedirectToSettings,
          equals(originalConfig.autoRedirectToSettings),
        );
      });

      test('should handle edge cases in copyWith', () {
        const originalConfig = PermissionConfig();

        // Copy with null values should preserve originals
        final updatedConfig = originalConfig.copyWith();

        expect(
          updatedConfig.showRationale,
          equals(originalConfig.showRationale),
        );
        expect(
          updatedConfig.maxRetryAttempts,
          equals(originalConfig.maxRetryAttempts),
        );
        expect(updatedConfig.retryDelay, equals(originalConfig.retryDelay));
      });
    });

    group('PermissionResult', () {
      test('should create granted result correctly', () {
        final result = PermissionResult.granted(
          metadata: {'attempts': 1, 'source': 'test'},
        );

        expect(result.isGranted, isTrue);
        expect(result.isPermanentlyDenied, isFalse);
        expect(result.wasRedirectedToSettings, isFalse);
        expect(result.state, equals(PermissionState.granted));
        expect(result.errorMessage, isNull);
        expect(result.metadata, equals({'attempts': 1, 'source': 'test'}));
      });

      test('should create denied result correctly', () {
        final result = PermissionResult.denied(
          errorMessage: 'User denied permission',
          metadata: {'attempts': 2, 'reason': 'user_choice'},
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isFalse);
        expect(result.wasRedirectedToSettings, isFalse);
        expect(result.state, equals(PermissionState.denied));
        expect(result.errorMessage, equals('User denied permission'));
        expect(
          result.metadata,
          equals({'attempts': 2, 'reason': 'user_choice'}),
        );
      });

      test('should create permanently denied result correctly', () {
        final result = PermissionResult.permanentlyDenied(
          wasRedirectedToSettings: true,
          errorMessage: 'Permission permanently denied',
          metadata: {'redirect_success': true},
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isTrue);
        expect(result.wasRedirectedToSettings, isTrue);
        expect(result.state, equals(PermissionState.permanentlyDenied));
        expect(result.errorMessage, equals('Permission permanently denied'));
        expect(result.metadata, equals({'redirect_success': true}));
      });

      test('should create error result correctly', () {
        final result = PermissionResult.error(
          'Internal permission service error',
          metadata: {'error_code': 500, 'service': 'permission_handler'},
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isFalse);
        expect(result.wasRedirectedToSettings, isFalse);
        expect(result.state, equals(PermissionState.unknown));
        expect(
          result.errorMessage,
          equals('Internal permission service error'),
        );
        expect(
          result.metadata,
          equals({'error_code': 500, 'service': 'permission_handler'}),
        );
      });

      test('should handle null metadata in factory constructors', () {
        final grantedResult = PermissionResult.granted();
        final deniedResult = PermissionResult.denied();
        final permanentlyDeniedResult = PermissionResult.permanentlyDenied();
        final errorResult = PermissionResult.error('Error message');

        expect(grantedResult.metadata, isNull);
        expect(deniedResult.metadata, isNull);
        expect(permanentlyDeniedResult.metadata, isNull);
        expect(errorResult.metadata, isNull);
      });

      test('should handle default values in permanently denied factory', () {
        final result = PermissionResult.permanentlyDenied();

        expect(result.wasRedirectedToSettings, isFalse);
        expect(result.errorMessage, isNull);
        expect(result.metadata, isNull);
      });
    });

    group('Permission Enums', () {
      test('should have all expected PermissionState values', () {
        const expectedStates = [
          PermissionState.unknown,
          PermissionState.granted,
          PermissionState.denied,
          PermissionState.permanentlyDenied,
          PermissionState.restricted,
          PermissionState.limited,
          PermissionState.requesting,
        ];

        expect(PermissionState.values, containsAll(expectedStates));
        expect(PermissionState.values.length, equals(expectedStates.length));
      });

      test('should have all expected PermissionType values', () {
        const expectedTypes = [
          PermissionType.microphone,
          PermissionType.storage,
          PermissionType.notification,
          PermissionType.backgroundRefresh,
          PermissionType.phone,
        ];

        expect(PermissionType.values, containsAll(expectedTypes));
        expect(PermissionType.values.length, equals(expectedTypes.length));
      });

      test('should convert enum values to strings correctly', () {
        expect(
          PermissionState.granted.toString(),
          equals('PermissionState.granted'),
        );
        expect(
          PermissionType.microphone.toString(),
          equals('PermissionType.microphone'),
        );
      });
    });

    group('Permission Model Integration', () {
      test('should work together in realistic permission flow scenarios', () {
        // Create a realistic permission request configuration
        const config = PermissionConfig(
          showRationale: true,
          rationaleTitle: 'Microphone Permission Required',
          rationaleMessage: 'This app needs microphone access to record audio.',
          autoRedirectToSettings: true,
          enableRetry: true,
          maxRetryAttempts: 2,
          retryDelay: Duration(milliseconds: 500),
        );

        // Simulate successful permission grant after retry
        final result = PermissionResult.granted(
          metadata: {
            'attempts': 2,
            'retry_delay_ms': config.retryDelay.inMilliseconds,
            'showed_rationale': config.showRationale,
          },
        );

        expect(result.isGranted, isTrue);
        expect(result.metadata!['attempts'], equals(2));
        expect(result.metadata!['showed_rationale'], isTrue);
      });

      test('should handle permission escalation scenario', () {
        // Simulate escalation from denied to permanently denied
        var config = const PermissionConfig(
          enableRetry: true,
          maxRetryAttempts: 3,
        );

        // First denial
        var result = PermissionResult.denied(
          errorMessage: 'User denied permission',
          metadata: {'attempt': 1},
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isFalse);

        // After max retries, becomes permanently denied
        result = PermissionResult.permanentlyDenied(
          wasRedirectedToSettings: true,
          errorMessage: 'Max retries exceeded, permission permanently denied',
          metadata: {'final_attempt': config.maxRetryAttempts},
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isTrue);
        expect(result.wasRedirectedToSettings, isTrue);
      });
    });
  });
}
