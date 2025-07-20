import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meeting_summarizer/core/services/biometric_auth_service.dart';

import 'biometric_auth_service_test.mocks.dart';

@GenerateMocks([LocalAuthentication])
void main() {
  group('BiometricAuthService', () {
    late MockLocalAuthentication mockLocalAuth;
    late BiometricAuthService service;

    setUp(() {
      mockLocalAuth = MockLocalAuthentication();
      SharedPreferences.setMockInitialValues({});
      service = BiometricAuthService(localAuth: mockLocalAuth);
    });

    tearDown(() {
      service.dispose();
    });

    group('Availability checks', () {
      test('should return true when biometrics are available', () async {
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);

        final result = await service.isAvailable();

        expect(result, isTrue);
        verify(mockLocalAuth.isDeviceSupported()).called(1);
        verify(mockLocalAuth.canCheckBiometrics).called(1);
      });

      test('should return false when device is not supported', () async {
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);

        final result = await service.isAvailable();

        expect(result, isFalse);
      });

      test('should return false when cannot check biometrics', () async {
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);

        final result = await service.isAvailable();

        expect(result, isFalse);
      });

      test('should handle exceptions and return false', () async {
        when(
          mockLocalAuth.isDeviceSupported(),
        ).thenThrow(Exception('Device error'));

        final result = await service.isAvailable();

        expect(result, isFalse);
      });
    });

    group('Available biometrics', () {
      test('should return correct biometric methods', () async {
        when(mockLocalAuth.getAvailableBiometrics()).thenAnswer(
          (_) async => [
            BiometricType.fingerprint,
            BiometricType.face,
            BiometricType.strong,
          ],
        );

        final result = await service.getAvailableBiometrics();

        expect(result, contains(BiometricAuthMethod.fingerprint));
        expect(result, contains(BiometricAuthMethod.face));
        expect(result, contains(BiometricAuthMethod.strong));
        expect(result.length, equals(3));
      });

      test('should return empty list on error', () async {
        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenThrow(Exception('Error'));

        final result = await service.getAvailableBiometrics();

        expect(result, isEmpty);
      });
    });

    group('Enable/Disable biometric auth', () {
      test('should enable biometric authentication', () async {
        await service.setEnabled(true);

        final isEnabled = await service.isEnabled();
        expect(isEnabled, isTrue);
      });

      test('should disable biometric authentication', () async {
        await service.setEnabled(true);
        await service.setEnabled(false);

        final isEnabled = await service.isEnabled();
        expect(isEnabled, isFalse);
      });

      test('should return false by default when not set', () async {
        final isEnabled = await service.isEnabled();
        expect(isEnabled, isFalse);
      });

      test('should invalidate session when disabled', () async {
        // First enable and create a session
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);

        await service.authenticate();
        expect(service.hasValidSession, isTrue);

        // Disable and check session is invalidated
        await service.setEnabled(false);
        expect(service.hasValidSession, isFalse);
      });
    });

    group('Authentication', () {
      setUp(() async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      });

      test('should authenticate successfully', () async {
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);

        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => [BiometricType.fingerprint]);

        final result = await service.authenticate();

        expect(result.isSuccess, isTrue);
        expect(result.method, equals(BiometricAuthMethod.fingerprint));
        expect(result.errorMessage, isNull);
        expect(service.hasValidSession, isTrue);
      });

      test('should fail when biometrics not available', () async {
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('not available'));
        expect(service.hasValidSession, isFalse);
      });

      test('should fail when biometrics not enabled', () async {
        await service.setEnabled(false);

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('not enabled'));
        expect(service.hasValidSession, isFalse);
      });

      test('should fail when user cancels authentication', () async {
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => false);

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('cancelled or failed'));
        expect(service.hasValidSession, isFalse);
      });

      test('should handle platform exceptions correctly', () async {
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenThrow(
          PlatformException(
            code: 'NotEnrolled',
            message: 'No biometrics enrolled',
          ),
        );

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(
          result.errorMessage,
          contains('No biometric credentials enrolled'),
        );
      });

      test('should use custom configuration', () async {
        const config = BiometricAuthConfig(
          signInTitle: 'Custom Title',
          description: 'Custom Description',
          stickyAuth: true,
        );

        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);

        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => [BiometricType.face]);

        final result = await service.authenticate(config: config);

        expect(result.isSuccess, isTrue);
        verify(
          mockLocalAuth.authenticate(
            localizedReason: 'Custom Description',
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).called(1);
      });
    });

    group('Session management', () {
      setUp(() async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => [BiometricType.fingerprint]);
      });

      test('should create valid session after authentication', () async {
        await service.authenticate();

        expect(service.hasValidSession, isTrue);
        expect(service.currentSession, isNotNull);
        expect(service.sessionTimeRemaining.inMinutes, greaterThan(25));
      });

      test('should invalidate session manually', () async {
        await service.authenticate();
        expect(service.hasValidSession, isTrue);

        await service.invalidateSession();
        expect(service.hasValidSession, isFalse);
        expect(service.currentSession, isNull);
      });

      test('should have no session before authentication', () async {
        expect(service.hasValidSession, isFalse);
        expect(service.currentSession, isNull);
        expect(service.sessionTimeRemaining, equals(Duration.zero));
      });
    });

    group('Platform exception handling', () {
      test('should handle NotAvailable error', () async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenThrow(PlatformException(code: 'NotAvailable'));

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('not available on this device'));
      });

      test('should handle LockedOut error', () async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenThrow(PlatformException(code: 'LockedOut'));

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('temporarily locked'));
      });

      test('should handle UserCancel error', () async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenThrow(PlatformException(code: 'UserCancel'));

        final result = await service.authenticate();

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('cancelled by user'));
      });
    });

    group('Authentication history', () {
      test('should record successful authentication time', () async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => [BiometricType.fingerprint]);

        final beforeAuth = DateTime.now();
        await service.authenticate();
        final afterAuth = DateTime.now();

        final lastAuthTime = await service.getLastAuthTime();
        expect(lastAuthTime, isNotNull);
        expect(
          lastAuthTime!.isAfter(
            beforeAuth.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          lastAuthTime.isBefore(afterAuth.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('should require reauth when no previous authentication', () async {
        final requiresReauth = await service.requiresReauth();
        expect(requiresReauth, isTrue);
      });

      test('should require reauth when threshold exceeded', () async {
        await service.setEnabled(true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          mockLocalAuth.authenticate(
            localizedReason: anyNamed('localizedReason'),
            authMessages: anyNamed('authMessages'),
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => [BiometricType.fingerprint]);

        await service.authenticate();

        // Should not require reauth immediately
        final immediateReauth = await service.requiresReauth(
          threshold: const Duration(hours: 1),
        );
        expect(immediateReauth, isFalse);

        // Should require reauth with very short threshold
        final shortThresholdReauth = await service.requiresReauth(
          threshold: const Duration(microseconds: 1),
        );
        expect(shortThresholdReauth, isTrue);
      });
    });

    group('BiometricAuthResult', () {
      test('should create success result correctly', () {
        const result = BiometricAuthResult.success(
          BiometricAuthMethod.fingerprint,
        );

        expect(result.isSuccess, isTrue);
        expect(result.method, equals(BiometricAuthMethod.fingerprint));
        expect(result.errorMessage, isNull);
      });

      test('should create failure result correctly', () {
        const result = BiometricAuthResult.failure('Test error');

        expect(result.isSuccess, isFalse);
        expect(result.method, isNull);
        expect(result.errorMessage, equals('Test error'));
      });
    });

    group('BiometricAuthMethod', () {
      test('should have correct display names', () {
        expect(
          BiometricAuthMethod.fingerprint.displayName,
          equals('Fingerprint'),
        );
        expect(BiometricAuthMethod.face.displayName, equals('Face ID'));
        expect(BiometricAuthMethod.iris.displayName, equals('Iris'));
        expect(
          BiometricAuthMethod.weak.displayName,
          equals('Device PIN/Pattern'),
        );
        expect(
          BiometricAuthMethod.strong.displayName,
          equals('Strong Biometric'),
        );
      });
    });

    group('BiometricSession', () {
      test('should be valid within duration', () {
        final session = BiometricSession(
          sessionId: 'test-session',
          validDuration: const Duration(minutes: 30),
        );

        expect(session.isValid, isTrue);
        expect(session.timeRemaining.inMinutes, greaterThan(25));
      });

      test('should be invalid after duration', () {
        final session = BiometricSession(
          sessionId: 'test-session',
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          validDuration: const Duration(minutes: 30),
        );

        expect(session.isValid, isFalse);
        expect(session.timeRemaining, equals(Duration.zero));
      });
    });
  });
}
