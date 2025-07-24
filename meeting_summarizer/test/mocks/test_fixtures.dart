import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/transcription_language.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/core/models/transcription_request.dart';

import 'mock_audio_recording_service.dart';
import 'mock_whisper_api_service.dart';
import 'mock_database_helper.dart';
import 'mock_data_generators.dart';

/// Test fixtures and predefined test scenarios
///
/// Provides commonly used test scenarios, configurations, and data sets
/// for comprehensive testing of the meeting summarizer application.
class TestFixtures {
  // Common audio configurations for testing
  static final AudioConfiguration highQualityAudio = AudioConfiguration(
    format: AudioFormat.wav,
    sampleRate: 48000,
    channels: 2,
    enableNoiseReduction: true,
    enableAutoGainControl: true,
    recordingLimit: Duration(hours: 2),
  );

  static final AudioConfiguration mediumQualityAudio = AudioConfiguration(
    format: AudioFormat.aac,
    sampleRate: 44100,
    channels: 1,
    enableNoiseReduction: true,
    enableAutoGainControl: false,
    recordingLimit: Duration(minutes: 60),
  );

  static final AudioConfiguration lowQualityAudio = AudioConfiguration(
    format: AudioFormat.mp3,
    sampleRate: 22050,
    channels: 1,
    enableNoiseReduction: false,
    enableAutoGainControl: false,
    recordingLimit: Duration(minutes: 30),
  );

  // Common transcription requests for testing
  static final TranscriptionRequest basicTranscriptionRequest =
      TranscriptionRequest(
        language: TranscriptionLanguage.english,
        enableTimestamps: true,
        enableSpeakerDiarization: false,
      );

  static final TranscriptionRequest advancedTranscriptionRequest =
      TranscriptionRequest(
        language: TranscriptionLanguage.english,
        enableTimestamps: true,
        enableWordTimestamps: true,
        enableSpeakerDiarization: true,
        maxSpeakers: 4,
        customVocabulary: ['API', 'deployment', 'sprint', 'stakeholder'],
        temperature: 0.1,
      );

  static final TranscriptionRequest multilingualTranscriptionRequest =
      TranscriptionRequest(
        language: TranscriptionLanguage.auto,
        enableTimestamps: true,
        enableSpeakerDiarization: true,
        maxSpeakers: 3,
      );

  // Test recording sessions
  static final RecordingSession activeRecordingSession = RecordingSession(
    id: 'test_session_active',
    startTime: DateTime.now().subtract(Duration(minutes: 15)),
    state: RecordingState.recording,
    duration: Duration(minutes: 15),
    configuration: mediumQualityAudio,
    filePath: '/test/recordings/active_session.aac',
    currentAmplitude: 0.7,
    waveformData: MockDataGenerators.generateWaveformData(points: 50),
  );

  static final RecordingSession completedRecordingSession = RecordingSession(
    id: 'test_session_completed',
    startTime: DateTime.now().subtract(Duration(hours: 1)),
    state: RecordingState.stopped,
    duration: Duration(minutes: 45),
    configuration: highQualityAudio,
    filePath: '/test/recordings/completed_session.wav',
    fileSize: 45 * 1024 * 1024 * 2, // ~2MB per minute for high quality
    endTime: DateTime.now().subtract(Duration(minutes: 15)),
    waveformData: MockDataGenerators.generateWaveformData(points: 100),
  );

  static final RecordingSession pausedRecordingSession = RecordingSession(
    id: 'test_session_paused',
    startTime: DateTime.now().subtract(Duration(minutes: 30)),
    state: RecordingState.paused,
    duration: Duration(minutes: 20),
    configuration: mediumQualityAudio,
    filePath: '/test/recordings/paused_session.aac',
    currentAmplitude: 0.0,
    waveformData: MockDataGenerators.generateWaveformData(points: 40),
  );

  static final RecordingSession errorRecordingSession = RecordingSession(
    id: 'test_session_error',
    startTime: DateTime.now().subtract(Duration(minutes: 5)),
    state: RecordingState.error,
    duration: Duration(minutes: 3),
    configuration: lowQualityAudio,
    errorMessage: 'Test error: Insufficient storage space',
    waveformData: MockDataGenerators.generateWaveformData(points: 15),
  );

  // Sample transcription texts for consistent testing
  static const String shortMeetingTranscription =
      "Good morning everyone. Let's start today's standup meeting. "
      "John, can you share your progress from yesterday? "
      "I completed the API integration and started working on the user interface. "
      "Great, any blockers? No blockers at the moment. "
      "Sarah, your turn. I finished the database migration and updated the documentation. "
      "Excellent work team. Let's wrap up here.";

  static const String longMeetingTranscription =
      "Welcome to our quarterly business review meeting. "
      "Today we'll be discussing our performance metrics, upcoming initiatives, and strategic planning for Q4. "
      "Let's start with the financial overview. Revenue this quarter exceeded our projections by 15%, "
      "primarily driven by increased customer acquisition and improved retention rates. "
      "Our customer satisfaction scores have improved significantly, with an average rating of 4.6 out of 5. "
      "The product development team has delivered three major features ahead of schedule. "
      "Marketing campaigns have generated a 40% increase in qualified leads compared to last quarter. "
      "For Q4, we're planning to expand into two new markets and launch our mobile application. "
      "We'll need to hire five additional team members to support this growth. "
      "Budget allocation for the expansion has been approved by the board. "
      "Any questions or concerns about these initiatives? "
      "I think we should also consider investing in additional customer support resources. "
      "Agreed, let's include that in our Q4 planning. "
      "Thank you everyone for your hard work this quarter.";

  static const String technicalMeetingTranscription =
      "Let's review the system architecture for our new microservices platform. "
      "We'll be implementing a containerized solution using Docker and Kubernetes. "
      "The API gateway will handle request routing and authentication. "
      "Each microservice will have its own database to ensure data isolation. "
      "We'll use Redis for caching and message queuing. "
      "Monitoring will be handled by Prometheus and Grafana. "
      "CI/CD pipeline will be implemented using Jenkins and automated testing. "
      "Security scanning will be integrated into the deployment process. "
      "Load balancing will be managed by the ingress controller. "
      "We expect a 30% improvement in response times with this new architecture.";

  // Predefined test scenarios
  static TestScenario get basicRecordingScenario => TestScenario(
    name: 'Basic Recording Workflow',
    description: 'Test basic recording, transcription, and summarization',
    audioConfiguration: mediumQualityAudio,
    transcriptionRequest: basicTranscriptionRequest,
    expectedDuration: Duration(minutes: 10),
    expectedTranscriptionText: shortMeetingTranscription,
  );

  static TestScenario get highQualityScenario => TestScenario(
    name: 'High Quality Full Workflow',
    description:
        'Test high-quality recording with advanced transcription features',
    audioConfiguration: highQualityAudio,
    transcriptionRequest: advancedTranscriptionRequest,
    expectedDuration: Duration(minutes: 45),
    expectedTranscriptionText: longMeetingTranscription,
  );

  static TestScenario get technicalMeetingScenario => TestScenario(
    name: 'Technical Meeting with Custom Vocabulary',
    description: 'Test transcription accuracy with technical terminology',
    audioConfiguration: mediumQualityAudio,
    transcriptionRequest: advancedTranscriptionRequest,
    expectedDuration: Duration(minutes: 20),
    expectedTranscriptionText: technicalMeetingTranscription,
  );

  static TestScenario get errorHandlingScenario => TestScenario(
    name: 'Error Handling and Recovery',
    description: 'Test error scenarios and graceful degradation',
    audioConfiguration: lowQualityAudio,
    transcriptionRequest: basicTranscriptionRequest,
    expectedDuration: Duration(minutes: 5),
    shouldSimulateErrors: true,
    expectedErrors: ['Storage error', 'Network timeout', 'Permission denied'],
  );

  // Performance test scenarios
  static TestScenario get performanceStressScenario => TestScenario(
    name: 'Performance Stress Test',
    description: 'Test system performance under load',
    audioConfiguration: mediumQualityAudio,
    transcriptionRequest: basicTranscriptionRequest,
    expectedDuration: Duration(hours: 2),
    concurrentOperations: 10,
    expectedTranscriptionText: longMeetingTranscription,
  );

  // Mock service configurations for common test scenarios
  static MockAudioRecordingService createConfiguredAudioService({
    bool shouldFail = false,
    Duration delay = const Duration(milliseconds: 100),
    double amplitude = 0.5,
  }) {
    final service = MockAudioRecordingService();
    service.setMockRecordingFailure(shouldFail);
    service.setMockDelays(recordingDelay: delay);
    service.setMockAmplitude(amplitude);
    return service;
  }

  static MockWhisperApiService createConfiguredTranscriptionService({
    bool shouldFail = false,
    Duration delay = const Duration(milliseconds: 500),
    double confidence = 0.95,
  }) {
    final service = MockWhisperApiService();
    service.setMockTranscriptionFailure(shouldFail);
    service.setMockTranscriptionDelay(delay);
    service.setMockConfidenceScore(confidence);
    return service;
  }

  static MockDatabaseHelper createConfiguredDatabaseHelper({
    bool shouldFail = false,
    Duration delay = const Duration(milliseconds: 10),
    bool populateTestData = true,
  }) {
    final helper = MockDatabaseHelper();
    helper.setMockOperationFailure(shouldFail);
    helper.setMockOperationDelay(delay);

    if (populateTestData) {
      // Will populate with test data after initialization
    }

    return helper;
  }

  // Test data collections
  static List<RecordingSession> getAllTestRecordingSessions() {
    return [
      activeRecordingSession,
      completedRecordingSession,
      pausedRecordingSession,
      errorRecordingSession,
    ];
  }

  static List<TranscriptionRequest> getAllTestTranscriptionRequests() {
    return [
      basicTranscriptionRequest,
      advancedTranscriptionRequest,
      multilingualTranscriptionRequest,
    ];
  }

  static List<String> getAllTestTranscriptionTexts() {
    return [
      shortMeetingTranscription,
      longMeetingTranscription,
      technicalMeetingTranscription,
    ];
  }

  static List<TestScenario> getAllTestScenarios() {
    return [
      basicRecordingScenario,
      highQualityScenario,
      technicalMeetingScenario,
      errorHandlingScenario,
      performanceStressScenario,
    ];
  }

  // Utility methods for test setup
  static Future<void> setupBasicTestEnvironment() async {
    // Initialize all mock services with default configurations
    final audioService = createConfiguredAudioService();
    final transcriptionService = createConfiguredTranscriptionService();
    final databaseHelper = createConfiguredDatabaseHelper();

    await audioService.initialize();
    await transcriptionService.initialize();
    await databaseHelper.initialize();
  }

  static void resetAllMockServices() {
    // Reset method would go here if services were globally accessible
    // For now, this serves as a documentation of the reset pattern
  }

  static Map<String, dynamic> getDefaultTestMetadata() {
    return {
      'test_run_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'test_framework': 'flutter_test',
      'generated_by': 'TestFixtures',
      'environment': 'test',
      'version': '1.0.0',
    };
  }
}

/// Test scenario configuration for comprehensive testing
class TestScenario {
  final String name;
  final String description;
  final AudioConfiguration audioConfiguration;
  final TranscriptionRequest transcriptionRequest;
  final Duration expectedDuration;
  final String? expectedTranscriptionText;
  final bool shouldSimulateErrors;
  final List<String>? expectedErrors;
  final int concurrentOperations;
  final Map<String, dynamic>? metadata;

  const TestScenario({
    required this.name,
    required this.description,
    required this.audioConfiguration,
    required this.transcriptionRequest,
    required this.expectedDuration,
    this.expectedTranscriptionText,
    this.shouldSimulateErrors = false,
    this.expectedErrors,
    this.concurrentOperations = 1,
    this.metadata,
  });

  @override
  String toString() {
    return 'TestScenario($name: $description)';
  }

  /// Create a copy of this scenario with modified parameters
  TestScenario copyWith({
    String? name,
    String? description,
    AudioConfiguration? audioConfiguration,
    TranscriptionRequest? transcriptionRequest,
    Duration? expectedDuration,
    String? expectedTranscriptionText,
    bool? shouldSimulateErrors,
    List<String>? expectedErrors,
    int? concurrentOperations,
    Map<String, dynamic>? metadata,
  }) {
    return TestScenario(
      name: name ?? this.name,
      description: description ?? this.description,
      audioConfiguration: audioConfiguration ?? this.audioConfiguration,
      transcriptionRequest: transcriptionRequest ?? this.transcriptionRequest,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      expectedTranscriptionText:
          expectedTranscriptionText ?? this.expectedTranscriptionText,
      shouldSimulateErrors: shouldSimulateErrors ?? this.shouldSimulateErrors,
      expectedErrors: expectedErrors ?? this.expectedErrors,
      concurrentOperations: concurrentOperations ?? this.concurrentOperations,
      metadata: metadata ?? this.metadata,
    );
  }
}
