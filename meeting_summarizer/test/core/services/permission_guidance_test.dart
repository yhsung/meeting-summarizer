import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/models/permission_guidance.dart';
import 'package:meeting_summarizer/core/services/permission_service_interface.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';

import 'mock_permission_service.dart';
import 'mock_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permission Guidance and Re-request Flow Tests', () {
    late AudioRecordingService audioService;
    late MockPermissionService mockPermissionService;
    late MockAudioRecordingPlatform mockPlatform;

    setUp(() {
      mockPermissionService = MockPermissionService();
      mockPlatform = MockAudioRecordingPlatform();
      audioService = AudioRecordingService(
        permissionService: mockPermissionService,
        platform: mockPlatform,
      );
    });

    tearDown(() async {
      await audioService.dispose();
    });

    group('Permission Guidance', () {
      test(
        'should provide guided permission request for denied permission',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to denied
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.denied,
          );

          final result = await audioService.requestPermissionWithGuidance();

          expect(result.isGranted, isTrue); // Mock grants permission on request
        },
      );

      test(
        'should handle permanently denied permission with settings guidance',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to permanently denied
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.permanentlyDenied,
          );

          final result = await audioService.requestPermissionWithGuidance();

          expect(result.isPermanentlyDenied, isTrue);
          expect(result.wasRedirectedToSettings, isTrue);
        },
      );

      test('should handle restricted permission appropriately', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to restricted
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.restricted,
        );

        final result = await audioService.requestPermissionWithGuidance();

        expect(result.isGranted, isFalse);
        expect(result.errorMessage, contains('restricted'));
      });

      test(
        'should return granted immediately if permission already granted',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to granted
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.granted,
          );

          final result = await audioService.requestPermissionWithGuidance();

          expect(result.isGranted, isTrue);
        },
      );

      test('should support custom rationale message', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to denied
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        const customMessage = 'Custom permission rationale for testing';
        final result = await audioService.requestPermissionWithGuidance(
          customRationale: customMessage,
        );

        expect(result.isGranted, isTrue); // Mock grants permission
      });

      test('should force request even when permission is granted', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to granted
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );

        final result = await audioService.requestPermissionWithGuidance(
          forceRequest: true,
        );

        expect(result.isGranted, isTrue);
      });
    });

    group('Permission Recovery', () {
      test(
        'should recover successfully when permission can be granted',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to denied initially
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.denied,
          );

          final result = await audioService.attemptPermissionRecovery();

          expect(result.success, isTrue);
          expect(result.requiresUserAction, isFalse);
          expect(result.message, contains('successfully granted'));
        },
      );

      test(
        'should indicate manual action needed for permanently denied',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to permanently denied
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.permanentlyDenied,
          );

          final result = await audioService.attemptPermissionRecovery();

          expect(result.success, isFalse);
          expect(result.requiresUserAction, isTrue);
          expect(result.message, contains('permanently denied'));
          expect(result.recommendedAction, contains('Settings'));
        },
      );

      test(
        'should return success immediately if permission already granted',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to granted
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.granted,
          );

          final result = await audioService.attemptPermissionRecovery();

          expect(result.success, isTrue);
          expect(result.message, contains('already granted'));
        },
      );

      test('should handle recovery errors gracefully', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Dispose the mock service to cause errors
        await mockPermissionService.dispose();

        final result = await audioService.attemptPermissionRecovery();

        expect(result.success, isFalse);
        expect(result.requiresUserAction, isTrue);
        expect(result.message, contains('failed'));
      });
    });

    group('Recording Readiness Check', () {
      test('should indicate ready when all permissions granted', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to granted
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );

        // Configure mock platform to be ready
        mockPlatform.setMockPermission(true);
        mockPlatform.setMockRecordingState(false); // Not currently recording

        // Simulate permission change to notify the service
        mockPermissionService.simulatePermissionChange(
          PermissionType.microphone,
          PermissionState.granted,
        );

        final result = await audioService.checkRecordingReadiness();

        expect(result.isReady, isTrue);
        expect(result.reason, contains('Ready'));
      });

      test('should indicate not ready when permission missing', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to denied
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        final result = await audioService.checkRecordingReadiness();

        expect(result.isReady, isFalse);
        expect(result.reason, contains('permission required'));
        expect(result.canRecover, isTrue);
      });

      test(
        'should provide guidance for permanently denied permission',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set permission to permanently denied
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.permanentlyDenied,
          );

          final result = await audioService.checkRecordingReadiness();

          expect(result.isReady, isFalse);
          expect(result.canRecover, isTrue); // Can recover via settings
          expect(result.recommendedAction, contains('settings'));
        },
      );

      test('should handle readiness check errors', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Dispose the mock service to cause errors
        await mockPermissionService.dispose();

        final result = await audioService.checkRecordingReadiness();

        expect(result.isReady, isFalse);
        expect(result.reason, contains('check failed'));
        expect(result.canRecover, isTrue);
      });
    });

    group('Permission Guidance Models', () {
      test('should create PermissionGuidance correctly', () {
        const guidance = PermissionGuidance(
          message: 'Test message',
          shouldShowRationale: true,
          rationaleTitle: 'Test Title',
          rationaleMessage: 'Test rationale',
          shouldRedirectToSettings: false,
          enableRetry: true,
          maxRetryAttempts: 3,
        );

        expect(guidance.message, equals('Test message'));
        expect(guidance.shouldShowRationale, isTrue);
        expect(guidance.rationaleTitle, equals('Test Title'));
        expect(guidance.shouldRedirectToSettings, isFalse);
        expect(guidance.enableRetry, isTrue);
        expect(guidance.maxRetryAttempts, equals(3));
      });

      test('should create PermissionRecoveryResult correctly', () {
        const result = PermissionRecoveryResult(
          success: true,
          message: 'Recovery successful',
          requiresUserAction: false,
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Recovery successful'));
        expect(result.requiresUserAction, isFalse);
        expect(result.recommendedAction, isNull);
      });

      test('should create RecordingReadinessResult correctly', () {
        const result = RecordingReadinessResult(
          isReady: false,
          reason: 'Permission missing',
          guidance: 'Grant permission to continue',
          canRecover: true,
          recommendedAction: 'Open settings',
        );

        expect(result.isReady, isFalse);
        expect(result.reason, equals('Permission missing'));
        expect(result.guidance, equals('Grant permission to continue'));
        expect(result.canRecover, isTrue);
        expect(result.recommendedAction, equals('Open settings'));
      });
    });
  });
}
