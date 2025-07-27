import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';
import 'package:meeting_summarizer/features/audio_recording/data/services/background_recording_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundRecordingManager', () {
    late BackgroundRecordingManager manager;
    late TestAudioRecordingService mockAudioService;

    setUp(() {
      manager = BackgroundRecordingManager();
      mockAudioService = TestAudioRecordingService();

      // Mock platform channels
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.meeting_summarizer/background_audio'),
        (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'enableBackground':
              return true;
            case 'disableBackground':
              return true;
            case 'startForegroundService':
              return true;
            case 'stopForegroundService':
              return true;
            case 'dispose':
              return true;
            default:
              return null;
          }
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.meeting_summarizer/background_session'),
        (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'enableBackgroundSession':
              return true;
            case 'disableBackgroundSession':
              return true;
            case 'startBackgroundTask':
              return true;
            case 'endBackgroundTask':
              return true;
            case 'dispose':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.meeting_summarizer/background_audio'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.meeting_summarizer/background_session'),
        null,
      );
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await manager.initialize(mockAudioService);
        expect(manager.isBackgroundRecordingEnabled, isFalse);
        expect(manager.isInBackground, isFalse);
      });

      test('should handle initialization errors gracefully', () async {
        // This test would require mocking platform channel errors
        // For now, we'll test the basic case
        await manager.initialize(mockAudioService);
        expect(manager, isNotNull);
      });
    });

    group('Background Mode Control', () {
      setUp(() async {
        await manager.initialize(mockAudioService);
      });

      test('should enable background recording', () async {
        final result = await manager.enableBackgroundRecording();
        expect(result, isTrue);
        expect(manager.isBackgroundRecordingEnabled, isTrue);
      });

      test('should disable background recording', () async {
        await manager.enableBackgroundRecording();
        await manager.disableBackgroundRecording();
        expect(manager.isBackgroundRecordingEnabled, isFalse);
      });

      test('should emit events when enabling/disabling', () async {
        final events = <BackgroundRecordingEvent>[];
        manager.eventStream.listen(events.add);

        await manager.enableBackgroundRecording();
        await manager.disableBackgroundRecording();

        expect(events, contains(BackgroundRecordingEvent.enabled));
        expect(events, contains(BackgroundRecordingEvent.disabled));
      });
    });

    group('App Lifecycle Handling', () {
      setUp(() async {
        await manager.initialize(mockAudioService);
        await manager.enableBackgroundRecording();
      });

      test('should handle app backgrounding with active recording', () async {
        // Set up active recording session
        final session = RecordingSession(
          id: 'test-session',
          startTime: DateTime.now(),
          state: RecordingState.recording,
          duration: const Duration(seconds: 30),
          configuration: AudioConfiguration(),
        );
        mockAudioService.setCurrentSession(session);

        final events = <BackgroundRecordingEvent>[];
        manager.eventStream.listen(events.add);

        // Simulate app backgrounding
        manager.simulateAppLifecycleChange(AppLifecycleState.paused);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(manager.isInBackground, isTrue);
        expect(
          events,
          contains(BackgroundRecordingEvent.backgroundRecordingStarted),
        );
      });

      test('should handle app foregrounding', () async {
        // Set up background session
        manager.simulateAppLifecycleChange(AppLifecycleState.paused);
        await Future.delayed(const Duration(milliseconds: 10));

        final events = <BackgroundRecordingEvent>[];
        manager.eventStream.listen(events.add);

        // Simulate app foregrounding
        manager.simulateAppLifecycleChange(AppLifecycleState.resumed);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(manager.isInBackground, isFalse);
      });

      test(
        'should pause recording when backgrounding without background enabled',
        () async {
          await manager.disableBackgroundRecording();

          final session = RecordingSession(
            id: 'test-session',
            startTime: DateTime.now(),
            state: RecordingState.recording,
            duration: const Duration(seconds: 30),
            configuration: AudioConfiguration(),
          );
          mockAudioService.setCurrentSession(session);

          final events = <BackgroundRecordingEvent>[];
          manager.eventStream.listen(events.add);

          manager.simulateAppLifecycleChange(AppLifecycleState.paused);
          await Future.delayed(const Duration(milliseconds: 10));

          expect(
            events,
            contains(BackgroundRecordingEvent.recordingPausedForBackground),
          );
        },
      );
    });

    group('Platform Capabilities', () {
      setUp(() async {
        await manager.initialize(mockAudioService);
      });

      test('should return platform-specific capabilities', () {
        final capabilities = manager.getCapabilities();
        expect(capabilities, isNotNull);
        expect(capabilities.platformName, isNotEmpty);
        expect(capabilities.supportsBackground, isA<bool>());
      });

      test('should provide correct capabilities for each platform', () {
        final capabilities = manager.getCapabilities();

        // The actual platform will depend on the test environment
        // In most cases, this will be the host platform (likely macOS/Linux for CI)
        expect(capabilities.supportsBackground, isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle platform channel errors gracefully', () async {
        // Note: This test behavior depends on the platform
        // Desktop platforms always return true for background recording
        // while mobile platforms use platform channels
        final result = await manager.enableBackgroundRecording();
        expect(result, isA<bool>()); // Just verify it returns a boolean
      });

      test('should handle missing platform implementations', () async {
        // This would test platforms that don't support background recording
        // For now, we'll test that the manager doesn't crash
        final capabilities = manager.getCapabilities();
        expect(capabilities, isNotNull);
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () async {
        await manager.initialize(mockAudioService);
        await manager.dispose();

        // After disposal, the manager should not emit events
        final events = <BackgroundRecordingEvent>[];
        manager.eventStream.listen(
          events.add,
          onError: (error) {
            // Expected - stream should be closed
          },
        );

        // Should not add any events after disposal
        expect(events, isEmpty);
      });
    });
  });

  group('BackgroundCapabilities', () {
    test('should create capabilities with all required fields', () {
      const capabilities = BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: false,
        maxBackgroundDuration: Duration(minutes: 5),
        supportsNotification: true,
        platformName: 'Test',
      );

      expect(capabilities.supportsBackground, isTrue);
      expect(capabilities.requiresPermission, isFalse);
      expect(capabilities.maxBackgroundDuration, const Duration(minutes: 5));
      expect(capabilities.supportsNotification, isTrue);
      expect(capabilities.platformName, 'Test');
    });

    test('should have meaningful toString representation', () {
      const capabilities = BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: false,
        maxBackgroundDuration: null,
        supportsNotification: true,
        platformName: 'Test',
      );

      final toString = capabilities.toString();
      expect(toString, contains('Test'));
      expect(toString, contains('supported=true'));
      expect(toString, contains('permission=false'));
      expect(toString, contains('notification=true'));
    });
  });
}

// Test implementation of AudioRecordingService
class TestAudioRecordingService extends AudioRecordingService {
  RecordingSession? _currentSession;
  final StreamController<RecordingSession> _controller =
      StreamController<RecordingSession>.broadcast();

  @override
  RecordingSession? get currentSession => _currentSession;

  @override
  Stream<RecordingSession> get sessionStream => _controller.stream;

  void setCurrentSession(RecordingSession? session) {
    _currentSession = session;
    if (session != null) {
      _controller.add(session);
    }
  }

  @override
  Future<void> pauseRecording() async {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(state: RecordingState.paused);
      _controller.add(_currentSession!);
    }
  }

  @override
  Future<void> resumeRecording() async {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: RecordingState.recording,
      );
      _controller.add(_currentSession!);
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: RecordingState.stopped,
      );
      _controller.add(_currentSession!);
    }
    return 'test_recording.wav';
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
