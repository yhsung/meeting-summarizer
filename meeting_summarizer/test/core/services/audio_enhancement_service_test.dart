import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/audio_enhancement_service.dart';
import 'package:meeting_summarizer/core/services/audio_enhancement_service_interface.dart';

void main() {
  late AudioEnhancementService service;
  late Float32List testAudioData;
  const int sampleRate = 44100;
  const int testDuration = 1; // 1 second of test audio

  setUp(() {
    service = AudioEnhancementService();

    // Generate test audio data (sine wave with noise)
    testAudioData = Float32List(sampleRate * testDuration);
    final random = math.Random(42); // Use seed for reproducible tests

    for (int i = 0; i < testAudioData.length; i++) {
      // Generate sine wave at 440 Hz
      final signal = math.sin(2 * math.pi * 440 * i / sampleRate) * 0.5;
      // Add some noise
      final noise = (random.nextDouble() - 0.5) * 0.1;
      testAudioData[i] = signal + noise;
    }
  });

  tearDown(() async {
    await service.dispose();
  });

  group('AudioEnhancementService Initialization', () {
    test('should initialize successfully', () async {
      expect(service.isReady(), completion(false));

      await service.initialize();

      expect(service.isReady(), completion(true));
      expect(service.currentConfig, isA<AudioEnhancementConfig>());
    });

    test('should dispose successfully', () async {
      await service.initialize();
      expect(service.isReady(), completion(true));

      await service.dispose();

      expect(service.isReady(), completion(false));
    });

    test('should configure with custom settings', () async {
      await service.initialize();

      const customConfig = AudioEnhancementConfig(
        enableNoiseReduction: true,
        enableEchoCanellation: true,
        enableAutoGainControl: false,
        noiseReductionStrength: 0.8,
        windowSize: 2048,
      );

      await service.configure(customConfig);

      expect(service.currentConfig, equals(customConfig));
    });
  });

  group('AudioEnhancementService Configuration', () {
    test('should return default configuration', () async {
      await service.initialize();

      final config = service.currentConfig;

      expect(config.enableNoiseReduction, isTrue);
      expect(config.enableEchoCanellation, isFalse);
      expect(config.enableAutoGainControl, isTrue);
      expect(config.processingMode, ProcessingMode.realTime);
      expect(config.windowSize, 1024);
    });

    test('should update configuration', () async {
      await service.initialize();

      final newConfig = service.currentConfig.copyWith(
        enableEchoCanellation: true,
        noiseReductionStrength: 0.9,
      );

      await service.configure(newConfig);

      expect(service.currentConfig.enableEchoCanellation, isTrue);
      expect(service.currentConfig.noiseReductionStrength, 0.9);
    });

    test('should reset to defaults', () async {
      await service.initialize();

      // Configure with custom settings
      await service.configure(
        const AudioEnhancementConfig(
          enableNoiseReduction: false,
          noiseReductionStrength: 0.9,
        ),
      );

      // Reset to defaults
      await service.resetToDefaults();

      final config = service.currentConfig;
      expect(config.enableNoiseReduction, isTrue);
      expect(config.noiseReductionStrength, 0.5);
    });
  });

  group('AudioEnhancementService Processing', () {
    test('should process audio data successfully', () async {
      await service.initialize();

      final result = await service.processAudio(testAudioData, sampleRate);

      expect(result.enhancedAudioData, isNotNull);
      expect(result.enhancedAudioData.length, testAudioData.length);
      expect(result.processingTime, isA<Duration>());
      expect(result.processingMetrics, isNotEmpty);
    });

    test('should throw error when not initialized', () async {
      expect(
        () => service.processAudio(testAudioData, sampleRate),
        throwsA(isA<StateError>()),
      );
    });

    test('should process audio stream', () async {
      await service.initialize();

      final inputStream = Stream.fromIterable([
        testAudioData.sublist(0, testAudioData.length ~/ 2),
        testAudioData.sublist(testAudioData.length ~/ 2),
      ]);

      final outputStream = service.processAudioStream(inputStream, sampleRate);
      final results = await outputStream.toList();

      expect(results.length, 2);
      expect(results[0], isA<Float32List>());
      expect(results[1], isA<Float32List>());
    });
  });

  group('AudioEnhancementService Noise Reduction', () {
    test('should apply noise reduction', () async {
      await service.initialize();

      final result = await service.applyNoiseReduction(
        testAudioData,
        sampleRate,
        0.9, // Higher strength to ensure change
      );

      expect(result.length, testAudioData.length);
      // Check that processing completed without error
      expect(result, isA<Float32List>());
    });

    test('should estimate noise profile', () async {
      await service.initialize();

      expect(
        () => service.estimateNoiseProfile(testAudioData, sampleRate),
        returnsNormally,
      );
    });

    test('should apply spectral subtraction', () async {
      await service.initialize();

      final result = await service.applySpectralSubtraction(
        testAudioData,
        sampleRate,
        2.0,
        0.01,
      );

      expect(result.length, testAudioData.length);
      expect(result, isA<Float32List>());
    });
  });

  group('AudioEnhancementService Echo Cancellation', () {
    test('should apply echo cancellation', () async {
      await service.initialize();

      final result = await service.applyEchoCancellation(
        testAudioData,
        sampleRate,
        0.5,
      );

      expect(result.length, testAudioData.length);
      expect(result, isA<Float32List>());
    });
  });

  group('AudioEnhancementService Auto Gain Control', () {
    test('should apply auto gain control', () async {
      await service.initialize();

      final result = await service.applyAutoGainControl(
        testAudioData,
        sampleRate,
        0.8,
      );

      expect(result.length, testAudioData.length);
      expect(result, isA<Float32List>());
    });

    test('should boost quiet signals', () async {
      await service.initialize();

      // Create quiet test signal
      final quietSignal = Float32List.fromList(
        testAudioData.map((sample) => sample * 0.01).toList(),
      );

      final result = await service.applyAutoGainControl(
        quietSignal,
        sampleRate,
        0.8,
      );

      // Check that signal was boosted
      final originalRMS = _calculateRMS(quietSignal);
      final processedRMS = _calculateRMS(result);

      expect(processedRMS, greaterThan(originalRMS));
    });
  });

  group('AudioEnhancementService Frequency Filtering', () {
    test('should apply frequency filtering', () async {
      await service.initialize();

      final result = await service.applyFrequencyFiltering(
        testAudioData,
        sampleRate,
        80.0, // High-pass cutoff
        8000.0, // Low-pass cutoff
      );

      expect(result.length, testAudioData.length);
      expect(result, isA<Float32List>());
    });
  });

  group('AudioEnhancementService Capabilities', () {
    test('should return supported enhancements', () async {
      await service.initialize();

      final supported = service.getSupportedEnhancements();

      expect(supported, contains(AudioEnhancementType.noiseReduction));
      expect(supported, contains(AudioEnhancementType.echocancellation));
      expect(supported, contains(AudioEnhancementType.autoGainControl));
      expect(supported, contains(AudioEnhancementType.spectralSubtraction));
      expect(supported, contains(AudioEnhancementType.frequencyFiltering));
    });

    test('should return processing mode', () async {
      await service.initialize();

      expect(service.processingMode, ProcessingMode.realTime);
    });

    test('should set processing mode', () async {
      await service.initialize();

      await service.setProcessingMode(ProcessingMode.postProcessing);

      expect(service.processingMode, ProcessingMode.postProcessing);
    });
  });

  group('AudioEnhancementService Performance Metrics', () {
    test('should track performance metrics', () async {
      await service.initialize();

      await service.processAudio(testAudioData, sampleRate);

      final metrics = service.getPerformanceMetrics();

      expect(metrics['processedSamples'], greaterThan(0));
      expect(metrics['totalProcessingTime'], greaterThan(0));
      expect(metrics['averageProcessingTime'], greaterThan(0));
    });

    test('should reset performance metrics', () async {
      await service.initialize();

      await service.processAudio(testAudioData, sampleRate);
      expect(
        service.getPerformanceMetrics()['processedSamples'],
        greaterThan(0),
      );

      await service.resetToDefaults();

      final metrics = service.getPerformanceMetrics();
      expect(metrics['processedSamples'] ?? 0, 0);
    });
  });

  group('AudioEnhancementService Error Handling', () {
    test('should handle empty audio data', () async {
      await service.initialize();

      final emptyData = Float32List(0);
      final result = await service.processAudio(emptyData, sampleRate);

      expect(result.enhancedAudioData.length, 0);
      expect(result.processingTime, Duration.zero);
    });

    test('should handle invalid sample rate', () async {
      await service.initialize();

      // Should not throw but will process normally
      final result = await service.processAudio(testAudioData, 0);
      expect(result.enhancedAudioData.length, testAudioData.length);
    });
  });

  group('AudioEnhancementConfig', () {
    test('should create default configuration', () {
      const config = AudioEnhancementConfig();

      expect(config.enableNoiseReduction, isTrue);
      expect(config.enableEchoCanellation, isFalse);
      expect(config.enableAutoGainControl, isTrue);
      expect(config.processingMode, ProcessingMode.realTime);
      expect(config.windowSize, 1024);
    });

    test('should create custom configuration', () {
      const config = AudioEnhancementConfig(
        enableNoiseReduction: false,
        enableEchoCanellation: true,
        processingMode: ProcessingMode.postProcessing,
        windowSize: 2048,
      );

      expect(config.enableNoiseReduction, isFalse);
      expect(config.enableEchoCanellation, isTrue);
      expect(config.processingMode, ProcessingMode.postProcessing);
      expect(config.windowSize, 2048);
    });

    test('should copy configuration with changes', () {
      const original = AudioEnhancementConfig();

      final modified = original.copyWith(
        enableEchoCanellation: true,
        noiseReductionStrength: 0.9,
      );

      expect(modified.enableEchoCanellation, isTrue);
      expect(modified.noiseReductionStrength, 0.9);
      expect(modified.enableNoiseReduction, original.enableNoiseReduction);
    });
  });
}

double _calculateRMS(Float32List data) {
  double sum = 0.0;
  for (final sample in data) {
    sum += sample * sample;
  }
  return math.sqrt(sum / data.length);
}
