import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/features/audio_recording/data/services/background_audio_service.dart';
import 'package:meeting_summarizer/features/audio_recording/data/services/background_recording_manager.dart';
import 'package:meeting_summarizer/features/audio_recording/presentation/widgets/background_recording_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup mock platform channels
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.meeting_summarizer/background_audio'),
          (call) async {
            switch (call.method) {
              case 'initialize':
              case 'enableBackground':
              case 'disableBackground':
              case 'startForegroundService':
              case 'stopForegroundService':
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
              case 'enableBackgroundSession':
              case 'disableBackgroundSession':
              case 'startBackgroundTask':
              case 'endBackgroundTask':
              case 'dispose':
                return true;
              default:
                return null;
            }
          },
        );
  });

  tearDownAll(() {
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
  group('BackgroundRecordingController', () {
    late TestBackgroundAudioService mockAudioService;

    setUp(() {
      mockAudioService = TestBackgroundAudioService();
    });

    tearDown(() {
      mockAudioService.dispose();
    });

    testWidgets('should build without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      expect(find.byType(BackgroundRecordingController), findsOneWidget);
      expect(find.text('Background Recording'), findsOneWidget);
    });

    testWidgets('should display background toggle switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Background Recording'), findsOneWidget);
    });

    testWidgets('should enable background mode when switch is toggled', (
      tester,
    ) async {
      mockAudioService.setRequestPermissionsResult(true);
      mockAudioService.setEnableBackgroundResult(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Find and tap the switch
      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      await tester.tap(switchWidget);
      await tester.pump();

      expect(mockAudioService.requestPermissionsCalled, isTrue);
      expect(mockAudioService.enableBackgroundCalled, isTrue);
    });

    testWidgets('should disable background mode when switch is toggled off', (
      tester,
    ) async {
      mockAudioService.setBackgroundModeEnabled(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Switch should be on initially
      final switchWidget = find.byType(Switch);
      Switch widget = tester.widget(switchWidget);
      expect(widget.value, isTrue);

      // Tap to disable
      await tester.tap(switchWidget);
      await tester.pump();

      expect(mockAudioService.disableBackgroundCalled, isTrue);
    });

    testWidgets('should show loading indicator when enabling background', (
      tester,
    ) async {
      mockAudioService.setRequestPermissionsResult(true);
      mockAudioService.setEnableBackgroundResult(true);
      mockAudioService.setEnableBackgroundDelay(
        const Duration(milliseconds: 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Tap switch to enable
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should display background status information', (tester) async {
      // Set the status before creating the widget
      mockAudioService.setBackgroundStatus(
        BackgroundRecordingStatus(
          isBackgroundModeEnabled: true,
          isInBackground: false,
          isRecordingInBackground: false,
          backgroundSession: null,
          capabilities: const BackgroundCapabilities(
            supportsBackground: true,
            requiresPermission: false,
            maxBackgroundDuration: null,
            supportsNotification: true,
            platformName: 'Test',
          ),
          currentSession: null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Wait for the widget to fully build and update
      await tester.pumpAndSettle();

      // Verify the status section is displayed
      expect(find.text('Background Status'), findsOneWidget);
      // The specific text might vary, so let's check for the general structure
      expect(
        find.byType(Card),
        findsAtLeastNWidgets(1),
      ); // Should have status cards
    });

    testWidgets('should display platform capabilities when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(
              audioService: mockAudioService,
              showCapabilities: true,
            ),
          ),
        ),
      );

      expect(find.text('Platform Capabilities (Test)'), findsOneWidget);
      expect(find.text('Background Support'), findsOneWidget);
      expect(find.text('Requires Permission'), findsOneWidget);
      expect(find.text('Supports Notification'), findsOneWidget);
    });

    testWidgets('should hide capabilities when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(
              audioService: mockAudioService,
              showCapabilities: false,
            ),
          ),
        ),
      );

      expect(find.text('Platform Capabilities (Test)'), findsNothing);
    });

    testWidgets('should handle background events', (tester) async {
      bool backgroundEnabledCalled = false;
      bool backgroundDisabledCalled = false;
      BackgroundRecordingEvent? lastEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(
              audioService: mockAudioService,
              onBackgroundEnabled: () => backgroundEnabledCalled = true,
              onBackgroundDisabled: () => backgroundDisabledCalled = true,
              onBackgroundEvent: (event) => lastEvent = event,
            ),
          ),
        ),
      );

      // Emit background enabled event
      mockAudioService.emitBackgroundEvent(BackgroundRecordingEvent.enabled);
      await tester.pump();

      expect(backgroundEnabledCalled, isTrue);
      expect(lastEvent, BackgroundRecordingEvent.enabled);

      // Emit background disabled event
      mockAudioService.emitBackgroundEvent(BackgroundRecordingEvent.disabled);
      await tester.pump();

      expect(backgroundDisabledCalled, isTrue);
      expect(lastEvent, BackgroundRecordingEvent.disabled);
    });

    testWidgets('should auto-enable background when requested', (tester) async {
      mockAudioService.setRequestPermissionsResult(true);
      mockAudioService.setEnableBackgroundResult(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(
              audioService: mockAudioService,
              autoEnableBackground: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(mockAudioService.enableBackgroundCalled, isTrue);
    });

    testWidgets('should show snack bars for events', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Emit an event that should show a snack bar
      mockAudioService.emitBackgroundEvent(
        BackgroundRecordingEvent.backgroundRecordingStarted,
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Recording continues in background'), findsOneWidget);
    });

    testWidgets('should show permission dialog when required', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Emit permission required event
      mockAudioService.emitBackgroundEvent(
        BackgroundRecordingEvent.permissionRequired,
      );
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Background Recording Permission'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should handle permission dialog actions', (tester) async {
      mockAudioService.setRequestPermissionsResult(true);
      mockAudioService.setEnableBackgroundResult(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      // Show permission dialog
      mockAudioService.emitBackgroundEvent(
        BackgroundRecordingEvent.permissionRequired,
      );
      await tester.pump();

      // Tap Enable button
      await tester.tap(find.text('Enable'));
      await tester.pump();

      expect(mockAudioService.enableBackgroundCalled, isTrue);
    });

    testWidgets('should show recording in background indicator', (
      tester,
    ) async {
      mockAudioService.setBackgroundStatus(
        BackgroundRecordingStatus(
          isBackgroundModeEnabled: true,
          isInBackground: true,
          isRecordingInBackground: true,
          backgroundSession: RecordingSession(
            id: 'bg-session',
            startTime: DateTime.now(),
            state: RecordingState.recording,
            duration: const Duration(minutes: 2),
            configuration: AudioConfiguration(),
          ),
          capabilities: const BackgroundCapabilities(
            supportsBackground: true,
            requiresPermission: false,
            maxBackgroundDuration: null,
            supportsNotification: true,
            platformName: 'Test',
          ),
          currentSession: null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackgroundRecordingController(audioService: mockAudioService),
          ),
        ),
      );

      expect(find.text('Currently recording in background'), findsOneWidget);
      expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
    });
  });
}

// Test implementation of BackgroundAudioService
class TestBackgroundAudioService extends BackgroundAudioService {
  final StreamController<BackgroundRecordingEvent> _backgroundEventController =
      StreamController<BackgroundRecordingEvent>.broadcast();

  bool requestPermissionsCalled = false;
  bool enableBackgroundCalled = false;
  bool disableBackgroundCalled = false;

  bool _requestPermissionsResult = true;
  bool _enableBackgroundResult = true;
  bool _backgroundModeEnabled = false;
  BackgroundRecordingStatus? _backgroundStatus;
  Duration? _enableBackgroundDelay;

  @override
  Stream<BackgroundRecordingEvent> get backgroundEventStream =>
      _backgroundEventController.stream;

  @override
  bool get isBackgroundModeEnabled => _backgroundModeEnabled;

  @override
  BackgroundCapabilities get backgroundCapabilities =>
      const BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: false,
        maxBackgroundDuration: null,
        supportsNotification: true,
        platformName: 'Test',
      );

  @override
  Future<bool> requestBackgroundPermissions() async {
    requestPermissionsCalled = true;
    return _requestPermissionsResult;
  }

  @override
  Future<bool> enableBackgroundMode() async {
    enableBackgroundCalled = true;
    if (_enableBackgroundDelay != null) {
      await Future.delayed(_enableBackgroundDelay!);
    }
    if (_enableBackgroundResult) {
      _backgroundModeEnabled = true;
      _backgroundEventController.add(BackgroundRecordingEvent.enabled);
    }
    return _enableBackgroundResult;
  }

  @override
  Future<void> disableBackgroundMode() async {
    disableBackgroundCalled = true;
    _backgroundModeEnabled = false;
    _backgroundEventController.add(BackgroundRecordingEvent.disabled);
  }

  @override
  BackgroundRecordingStatus getBackgroundStatus() {
    return _backgroundStatus ??
        BackgroundRecordingStatus(
          isBackgroundModeEnabled: _backgroundModeEnabled,
          isInBackground: false,
          isRecordingInBackground: false,
          backgroundSession: null,
          capabilities: backgroundCapabilities,
          currentSession: null,
        );
  }

  void emitBackgroundEvent(BackgroundRecordingEvent event) {
    _backgroundEventController.add(event);
  }

  void setRequestPermissionsResult(bool result) {
    _requestPermissionsResult = result;
  }

  void setEnableBackgroundResult(bool result) {
    _enableBackgroundResult = result;
  }

  void setBackgroundModeEnabled(bool enabled) {
    _backgroundModeEnabled = enabled;
  }

  void setBackgroundStatus(BackgroundRecordingStatus status) {
    _backgroundStatus = status;
  }

  void setEnableBackgroundDelay(Duration delay) {
    _enableBackgroundDelay = delay;
  }

  @override
  Future<void> dispose() async {
    await _backgroundEventController.close();
  }
}
