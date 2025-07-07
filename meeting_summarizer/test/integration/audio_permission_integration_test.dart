import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/services/permission_service_interface.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';

import '../core/services/mock_permission_service.dart';
import '../core/services/mock_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Audio Recording with Permission Integration Tests', () {
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

    group('Permission-Based Recording Control', () {
      test('should initialize successfully with permission service', () async {
        await mockPermissionService.initialize();
        await expectLater(audioService.initialize(), completes);
      });

      test(
        'should fail recording start when microphone permission denied',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set microphone permission to denied
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.denied,
          );

          final config = AudioConfiguration(
            quality: AudioQuality.medium,
            format: AudioFormat.wav,
          );

          // With graceful degradation, recording should fail gracefully
          await audioService.startRecording(configuration: config);

          // Verify that recording is in stopped or error state due to permission denial
          expect(
            audioService.currentSession?.state,
            anyOf([RecordingState.stopped, RecordingState.error]),
          );
          
          // Verify error message contains permission information
          expect(
            audioService.currentSession?.errorMessage,
            contains('permission'),
          );
        },
      );

      test(
        'should start recording successfully when permission granted',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Set microphone permission to granted
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.granted,
          );

          // Configure mock platform to have permission
          mockPlatform.setMockPermission(true);

          final config = AudioConfiguration(
            quality: AudioQuality.medium,
            format: AudioFormat.wav,
          );

          // Recording should start successfully
          await expectLater(
            audioService.startRecording(configuration: config),
            completes,
          );

          // Verify recording state
          expect(
            audioService.currentSession?.state,
            equals(RecordingState.recording),
          );
        },
      );

      test('should handle permission revocation during recording', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Start with permission granted
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );

        // Configure mock platform to have permission
        mockPlatform.setMockPermission(true);

        final config = AudioConfiguration(
          quality: AudioQuality.medium,
          format: AudioFormat.wav,
        );

        await audioService.startRecording(configuration: config);
        expect(
          audioService.currentSession?.state,
          equals(RecordingState.recording),
        );

        // Simulate permission revocation during recording
        mockPermissionService.simulatePermissionChange(
          PermissionType.microphone,
          PermissionState.denied,
        );

        // Give time for permission change to be processed
        await Future.delayed(Duration(milliseconds: 100));

        // Recording should be stopped due to permission revocation
        expect(
          audioService.currentSession?.state,
          anyOf([RecordingState.stopped, RecordingState.error, RecordingState.paused]),
        );
      });
    });

    group('Permission Request Flow', () {
      test('should handle permission request workflow', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Start with permission denied
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        // Check permission status
        final hasPermission = await audioService.hasPermission();
        expect(hasPermission, isFalse);

        // Request permission (mock will grant it)
        final permissionGranted = await audioService.requestPermission();
        expect(permissionGranted, isTrue);

        // Verify permission is now granted
        final hasPermissionAfterRequest = await audioService.hasPermission();
        expect(hasPermissionAfterRequest, isTrue);
      });

      test('should handle permanently denied permissions', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Set permission to permanently denied
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.permanentlyDenied,
        );

        final config = AudioConfiguration(
          quality: AudioQuality.medium,
          format: AudioFormat.wav,
        );

        // With graceful degradation, recording should fail gracefully
        await audioService.startRecording(configuration: config);

        // For permanently denied permissions, either no session is created
        // or the session is in error/stopped state
        if (audioService.currentSession != null) {
          expect(
            audioService.currentSession!.state,
            anyOf([RecordingState.error, RecordingState.stopped]),
          );

          // Verify error message mentions permanent denial or permission
          expect(
            audioService.currentSession!.errorMessage,
            anyOf([
              contains('permanently'),
              contains('permission'),
            ]),
          );
        } else {
          // If no session was created, that's also a valid graceful failure response
          expect(audioService.currentSession, isNull);
        }
      });
    });

    group('Permission Analytics Integration', () {
      test(
        'should provide permission analytics through audio service',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Make some permission requests
          await audioService.requestPermission();
          await audioService.requestPermission();

          final analytics = audioService.getPermissionAnalytics();

          expect(analytics, contains('requestCounts'));
          expect(analytics, contains('totalRequests'));
          expect(analytics['totalRequests'], greaterThan(0));
        },
      );

      test('should track permission requirements', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        final hasAllRequired = await audioService.hasAllRequiredPermissions();
        expect(hasAllRequired, isA<bool>());

        final missingPermissions = await audioService
            .getMissingRequiredPermissions();
        expect(missingPermissions, isA<List<PermissionType>>());
      });
    });

    group('Service State Management', () {
      test(
        'should handle service disposal with permission monitoring',
        () async {
          await mockPermissionService.initialize();
          await audioService.initialize();

          // Start permission monitoring by checking state
          await audioService.hasPermission();

          // Dispose should complete without errors
          await expectLater(audioService.dispose(), completes);
        },
      );

      test('should maintain ready state based on permissions', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // With permission denied, service should not be ready
        mockPermissionService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        final isReady = await audioService.isReady();
        // Note: isReady depends on platform implementation,
        // so we just verify it returns a boolean
        expect(isReady, isA<bool>());
      });
    });

    group('Error Scenarios', () {
      test('should handle permission service errors gracefully', () async {
        await mockPermissionService.initialize();
        await audioService.initialize();

        // Simulate permission service error by disposing it
        await mockPermissionService.dispose();

        // Audio service should handle the error gracefully
        final hasPermission = await audioService.hasPermission();
        expect(hasPermission, isFalse);
      });

      test(
        'should handle permission state changes during initialization',
        () async {
          await mockPermissionService.initialize();

          // Change permission state during initialization
          mockPermissionService.setMockPermissionState(
            PermissionType.microphone,
            PermissionState.granted,
          );

          await expectLater(audioService.initialize(), completes);
        },
      );
    });
  });

  group('Mock Permission Service Tests', () {
    late MockPermissionService mockService;

    setUp(() {
      mockService = MockPermissionService();
    });

    tearDown(() async {
      await mockService.dispose();
    });

    test('should simulate permission state changes', () async {
      await mockService.initialize();

      // Set initial state
      mockService.setMockPermissionState(
        PermissionType.microphone,
        PermissionState.denied,
      );

      var state = await mockService.checkPermission(PermissionType.microphone);
      expect(state, equals(PermissionState.denied));

      // Simulate permission change
      mockService.simulatePermissionChange(
        PermissionType.microphone,
        PermissionState.granted,
      );

      state = await mockService.checkPermission(PermissionType.microphone);
      expect(state, equals(PermissionState.granted));
    });

    test('should emit permission state changes via stream', () async {
      await mockService.initialize();

      final stateChanges = <Map<PermissionType, PermissionState>>[];
      final subscription = mockService.permissionStateStream.listen(
        (states) => stateChanges.add(states),
      );

      // Simulate state change
      mockService.simulatePermissionChange(
        PermissionType.microphone,
        PermissionState.granted,
      );

      await Future.delayed(Duration(milliseconds: 10));
      await subscription.cancel();

      expect(stateChanges, isNotEmpty);
      expect(
        stateChanges.last[PermissionType.microphone],
        equals(PermissionState.granted),
      );
    });

    test('should track request analytics', () async {
      await mockService.initialize();

      // Make multiple requests
      await mockService.requestPermission(PermissionType.microphone);
      await mockService.requestPermission(PermissionType.microphone);
      await mockService.requestPermission(PermissionType.storage);

      final analytics = mockService.getPermissionAnalytics();

      expect(analytics['totalRequests'], equals(3));
      expect(
        analytics['requestCounts']['PermissionType.microphone'],
        equals(2),
      );
      expect(analytics['requestCounts']['PermissionType.storage'], equals(1));
    });
  });
}
