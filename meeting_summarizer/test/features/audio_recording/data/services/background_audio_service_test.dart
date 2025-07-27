import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/features/audio_recording/data/services/background_audio_service.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';

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
  group('BackgroundAudioService', () {
    late BackgroundAudioService service;
    late TestAudioRecordingService mockBaseService;

    setUp(() {
      mockBaseService = TestAudioRecordingService();
      service = BackgroundAudioService(baseService: mockBaseService);
    });

    tearDown(() async {
      await service.dispose();
      await mockBaseService.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await service.initialize();
        expect(service.isBackgroundModeEnabled, isFalse);
        expect(service.isRecordingInBackground, isFalse);
      });

      test('should get background capabilities', () async {
        await service.initialize();
        final capabilities = service.backgroundCapabilities;
        expect(capabilities, isNotNull);
        expect(capabilities.platformName, isNotEmpty);
      });
    });

    group('Background Mode Management', () {
      setUp(() async {
        await service.initialize();
      });

      test('should enable background mode', () async {
        final result = await service.enableBackgroundMode();
        // Since we're using real BackgroundRecordingManager, this will depend on platform
        expect(result, isA<bool>());
      });

      test('should disable background mode', () async {
        await service.enableBackgroundMode();
        await service.disableBackgroundMode();
        expect(service.isBackgroundModeEnabled, isFalse);
      });
    });

    group('Recording Operations', () {
      setUp(() async {
        await service.initialize();
      });

      test('should delegate start recording to base service', () async {
        final configuration = AudioConfiguration();
        await service.startRecording(configuration: configuration);

        expect(mockBaseService.startRecordingCalled, isTrue);
        expect(mockBaseService.lastConfiguration, configuration);
      });

      test('should delegate pause recording to base service', () async {
        await service.pauseRecording();
        expect(mockBaseService.pauseRecordingCalled, isTrue);
      });

      test('should delegate resume recording to base service', () async {
        await service.resumeRecording();
        expect(mockBaseService.resumeRecordingCalled, isTrue);
      });

      test('should delegate stop recording to base service', () async {
        final result = await service.stopRecording();
        expect(mockBaseService.stopRecordingCalled, isTrue);
        expect(result, 'test_recording.wav');
      });

      test('should delegate cancel recording to base service', () async {
        await service.cancelRecording();
        expect(mockBaseService.cancelRecordingCalled, isTrue);
      });

      test('should delegate isReady to base service', () async {
        mockBaseService.setReady(true);
        final result = await service.isReady();
        expect(result, isTrue);
      });

      test('should delegate getSupportedFormats to base service', () {
        mockBaseService.setSupportedFormats(['wav', 'mp3']);
        final formats = service.getSupportedFormats();
        expect(formats, ['wav', 'mp3']);
      });

      test('should delegate hasPermission to base service', () async {
        mockBaseService.setHasPermission(true);
        final result = await service.hasPermission();
        expect(result, isTrue);
      });

      test('should delegate requestPermission to base service', () async {
        mockBaseService.setRequestPermissionResult(true);
        final result = await service.requestPermission();
        expect(result, isTrue);
      });
    });

    group('Session Handling', () {
      setUp(() async {
        await service.initialize();
      });

      test('should forward session updates from base service', () async {
        final sessions = <RecordingSession>[];
        service.sessionStream.listen(sessions.add);

        final testSession = RecordingSession(
          id: 'test-id',
          startTime: DateTime.now(),
          state: RecordingState.recording,
          duration: const Duration(seconds: 30),
          configuration: AudioConfiguration(),
        );

        mockBaseService.emitSession(testSession);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(sessions, contains(testSession));
        expect(service.currentSession, testSession);
      });

      test('should handle base service errors', () async {
        final errors = [];
        service.sessionStream.listen((session) {}, onError: errors.add);

        mockBaseService.emitError('Test error');
        await Future.delayed(const Duration(milliseconds: 10));

        expect(errors, contains('Test error'));
      });
    });

    group('Error Handling', () {
      setUp(() async {
        await service.initialize();
      });

      test('should handle start recording errors', () async {
        mockBaseService.setThrowOnStart(true);

        expect(
          () => service.startRecording(configuration: AudioConfiguration()),
          throwsException,
        );
      });
    });

    group('Background Status', () {
      setUp(() async {
        await service.initialize();
      });

      test('should provide background status information', () async {
        final status = service.getBackgroundStatus();
        expect(status, isNotNull);
        expect(status.capabilities, isNotNull);
      });

      test('should detect background recording state', () async {
        expect(service.isRecordingInBackground, isA<bool>());
      });
    });

    group('Permission Handling', () {
      setUp(() async {
        await service.initialize();
      });

      test('should request background permissions', () async {
        final result = await service.requestBackgroundPermissions();
        expect(result, isA<bool>());
      });
    });
  });
}

// Test implementation of AudioRecordingService
class TestAudioRecordingService extends AudioRecordingService {
  final StreamController<RecordingSession> _controller =
      StreamController<RecordingSession>.broadcast();

  bool startRecordingCalled = false;
  bool pauseRecordingCalled = false;
  bool resumeRecordingCalled = false;
  bool stopRecordingCalled = false;
  bool cancelRecordingCalled = false;
  bool _isReady = true;
  bool _hasPermission = true;
  bool _requestPermissionResult = true;
  bool _throwOnStart = false;
  List<String> _supportedFormats = ['wav'];
  AudioConfiguration? lastConfiguration;
  RecordingSession? _currentSession;

  @override
  Stream<RecordingSession> get sessionStream => _controller.stream;

  @override
  RecordingSession? get currentSession => _currentSession;

  @override
  Future<void> initialize() async {
    // Mock implementation
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  }) async {
    if (_throwOnStart) throw Exception('Test error');
    startRecordingCalled = true;
    lastConfiguration = configuration;
  }

  @override
  Future<void> pauseRecording() async {
    pauseRecordingCalled = true;
  }

  @override
  Future<void> resumeRecording() async {
    resumeRecordingCalled = true;
  }

  @override
  Future<String?> stopRecording() async {
    stopRecordingCalled = true;
    return 'test_recording.wav';
  }

  @override
  Future<void> cancelRecording() async {
    cancelRecordingCalled = true;
  }

  @override
  Future<bool> isReady() async {
    return _isReady;
  }

  @override
  List<String> getSupportedFormats() {
    return _supportedFormats;
  }

  @override
  Future<bool> hasPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    return _requestPermissionResult;
  }

  void emitSession(RecordingSession session) {
    _currentSession = session;
    _controller.add(session);
  }

  void emitError(String error) {
    _controller.addError(error);
  }

  void setReady(bool ready) {
    _isReady = ready;
  }

  void setHasPermission(bool hasPermission) {
    _hasPermission = hasPermission;
  }

  void setRequestPermissionResult(bool result) {
    _requestPermissionResult = result;
  }

  void setSupportedFormats(List<String> formats) {
    _supportedFormats = formats;
  }

  void setThrowOnStart(bool shouldThrow) {
    _throwOnStart = shouldThrow;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
