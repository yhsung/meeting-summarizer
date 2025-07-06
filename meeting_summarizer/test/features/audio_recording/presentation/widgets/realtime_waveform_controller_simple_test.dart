import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';
import 'package:meeting_summarizer/features/audio_recording/presentation/widgets/realtime_waveform_controller.dart';

// Simple mock class without external dependencies
class TestAudioRecordingService extends AudioRecordingService {
  final StreamController<RecordingSession> _sessionController =
      StreamController<RecordingSession>.broadcast();

  RecordingSession? _currentSession;

  @override
  Stream<RecordingSession> get sessionStream => _sessionController.stream;

  @override
  RecordingSession? get currentSession => _currentSession;

  void addSession(RecordingSession session) {
    _currentSession = session;
    _sessionController.add(session);
  }

  void close() {
    _sessionController.close();
  }

  // Required interface methods (stubbed for testing)
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  }) async {}

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  @override
  Future<String?> stopRecording() async => null;

  @override
  Future<void> cancelRecording() async {}

  @override
  Future<bool> isReady() async => true;

  @override
  List<String> getSupportedFormats() => ['mp3', 'wav'];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  group('RealtimeWaveformController', () {
    late TestAudioRecordingService testRecordingService;

    setUp(() {
      testRecordingService = TestAudioRecordingService();
    });

    tearDown(() {
      testRecordingService.close();
    });

    testWidgets('should build with linear waveform type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
            waveformType: WaveformType.linear,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.stopped,
        duration: const Duration(seconds: 30),
        configuration: AudioConfiguration(),
        waveformData: const [0.1, 0.5, 0.8],
        currentAmplitude: 0.7,
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.byType(RealtimeWaveformController), findsOneWidget);
      expect(find.text('Not recording'), findsOneWidget);
    });

    testWidgets('should build with circular waveform type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
            waveformType: WaveformType.circular,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.stopped,
        duration: const Duration(seconds: 30),
        configuration: AudioConfiguration(),
        waveformData: const [0.1, 0.5, 0.8],
        currentAmplitude: 0.7,
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.byType(RealtimeWaveformController), findsOneWidget);
      expect(find.text('Not recording'), findsOneWidget);
    });

    testWidgets('should display recording state when active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.recording,
        duration: const Duration(seconds: 30),
        configuration: AudioConfiguration(),
        waveformData: const [0.1, 0.5, 0.8],
        currentAmplitude: 0.7,
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.text('Recording...'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should update waveform data from stream', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
          ),
        ),
      );

      final session1 = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.recording,
        duration: const Duration(seconds: 15),
        configuration: AudioConfiguration(),
        waveformData: const [0.1, 0.5],
        currentAmplitude: 0.3,
      );

      testRecordingService.addSession(session1);
      await tester.pump();

      expect(find.text('Recording...'), findsOneWidget);
      expect(find.text('00:15'), findsOneWidget);

      // Update with new session data
      final session2 = session1.copyWith(
        duration: const Duration(seconds: 45),
        waveformData: const [0.1, 0.5, 0.8, 0.6],
        currentAmplitude: 0.8,
      );

      testRecordingService.addSession(session2);
      await tester.pump();

      expect(find.text('00:45'), findsOneWidget);
    });

    testWidgets('should handle paused recording state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.paused,
        duration: const Duration(minutes: 1, seconds: 30),
        configuration: AudioConfiguration(),
        waveformData: const [0.1, 0.5, 0.8],
        currentAmplitude: 0.0,
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.text('Not recording'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('should format duration correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.recording,
        duration: const Duration(minutes: 10, seconds: 5),
        configuration: AudioConfiguration(),
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.text('10:05'), findsOneWidget);
    });

    testWidgets('should handle zero duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeWaveformController(
            recordingService: testRecordingService,
          ),
        ),
      );

      final session = RecordingSession(
        id: 'test-id',
        startTime: DateTime.now(),
        state: RecordingState.initializing,
        duration: Duration.zero,
        configuration: AudioConfiguration(),
      );

      testRecordingService.addSession(session);
      await tester.pump();

      expect(find.text('00:00'), findsOneWidget);
    });
  });

  group('WaveformVisualizerDemo', () {
    late TestAudioRecordingService testRecordingService;

    setUp(() {
      testRecordingService = TestAudioRecordingService();
    });

    tearDown(() {
      testRecordingService.close();
    });

    testWidgets('should build demo interface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WaveformVisualizerDemo(recordingService: testRecordingService),
        ),
      );

      expect(find.byType(WaveformVisualizerDemo), findsOneWidget);
      expect(find.text('Waveform Visualizer Demo'), findsOneWidget);
      expect(find.byType(RealtimeWaveformController), findsOneWidget);
    });

    testWidgets('should change waveform type via popup menu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WaveformVisualizerDemo(recordingService: testRecordingService),
        ),
      );

      // Tap the popup menu button
      await tester.tap(find.byType(PopupMenuButton<WaveformType>));
      await tester.pumpAndSettle();

      expect(find.text('Linear Waveform'), findsOneWidget);
      expect(find.text('Circular Waveform'), findsOneWidget);

      // Select circular waveform
      await tester.tap(find.text('Circular Waveform'));
      await tester.pumpAndSettle();

      expect(find.byType(RealtimeWaveformController), findsOneWidget);
    });
  });
}
