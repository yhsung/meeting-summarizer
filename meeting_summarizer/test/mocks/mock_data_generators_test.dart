import 'package:flutter_test/flutter_test.dart';

import 'mock_data_generators.dart';

void main() {
  group('MockDataGenerators', () {
    test('should generate valid audio configuration', () {
      final config = MockDataGenerators.generateAudioConfiguration();
      
      expect(config, isNotNull);
      expect(config.sampleRate, isPositive);
      expect(config.channels, inInclusiveRange(1, 2));
    });

    test('should generate valid recording session', () {
      final session = MockDataGenerators.generateRecordingSession();
      
      expect(session, isNotNull);
      expect(session.id, isNotEmpty);
      expect(session.startTime, isNotNull);
      expect(session.configuration, isNotNull);
    });

    test('should generate valid transcription request', () {
      final request = MockDataGenerators.generateTranscriptionRequest();
      
      expect(request, isNotNull);
      expect(request.language, isNotNull);
      expect(request.temperature, inInclusiveRange(0.0, 0.5));
    });

    test('should generate valid transcription result', () {
      final result = MockDataGenerators.generateTranscriptionResult();
      
      expect(result, isNotNull);
      expect(result.text, isNotEmpty);
      expect(result.confidence, inInclusiveRange(0.8, 1.0));
      expect(result.segments, isNotEmpty);
      expect(result.words, isNotEmpty);
    });

    test('should generate valid sync operation', () {
      final operation = MockDataGenerators.generateSyncOperation();
      
      expect(operation, isNotNull);
      expect(operation.id, isNotEmpty);
      expect(operation.localFilePath, isNotEmpty);
      expect(operation.remoteFilePath, isNotEmpty);
      expect(operation.createdAt, isNotNull);
    });

    test('should generate valid sync conflict', () {
      final conflict = MockDataGenerators.generateSyncConflict();
      
      expect(conflict, isNotNull);
      expect(conflict.id, isNotEmpty);
      expect(conflict.filePath, isNotEmpty);
      expect(conflict.localVersion, isNotNull);
      expect(conflict.remoteVersion, isNotNull);
      expect(conflict.detectedAt, isNotNull);
    });

    test('should generate valid waveform data', () {
      final waveform = MockDataGenerators.generateWaveformData(points: 10);
      
      expect(waveform, hasLength(10));
      for (final point in waveform) {
        expect(point, inInclusiveRange(0.0, 1.0));
      }
    });

    test('should generate valid audio data', () {
      final audioData = MockDataGenerators.generateAudioData(samples: 100);
      
      expect(audioData, hasLength(100));
      expect(audioData, isNotNull);
    });

    test('should generate batch data correctly', () {
      final batch = MockDataGenerators.generateBatch(
        () => MockDataGenerators.generateMeetingTitle(), 
        count: 5
      );
      
      expect(batch, hasLength(5));
      for (final title in batch) {
        expect(title, isNotEmpty);
      }
    });

    test('should reset random seed for deterministic testing', () {
      MockDataGenerators.resetSeed(42);
      final result1 = MockDataGenerators.generateMeetingTitle();
      
      MockDataGenerators.resetSeed(42);
      final result2 = MockDataGenerators.generateMeetingTitle();
      
      expect(result1, equals(result2));
    });
  });
}