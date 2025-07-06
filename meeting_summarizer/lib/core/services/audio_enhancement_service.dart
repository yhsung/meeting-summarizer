import 'dart:typed_data';
import 'dart:math' as math;

import 'package:fftea/fftea.dart';

import 'audio_enhancement_service_interface.dart';

/// Default implementation of the audio enhancement service
class AudioEnhancementService implements AudioEnhancementServiceInterface {
  late AudioEnhancementConfig _config;
  late FFT _fft;
  Float32List? _noiseProfile;
  bool _isInitialized = false;

  final Map<String, dynamic> _performanceMetrics = {
    'processedSamples': 0,
    'totalProcessingTime': 0,
    'averageProcessingTime': 0,
    'noiseReductionCalls': 0,
    'echoCancellationCalls': 0,
    'gainControlCalls': 0,
  };

  @override
  Future<void> initialize() async {
    _config = const AudioEnhancementConfig();
    _fft = FFT(_config.windowSize);
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _noiseProfile = null;
    _performanceMetrics.clear();
  }

  @override
  Future<void> configure(AudioEnhancementConfig config) async {
    _config = config;
    _fft = FFT(config.windowSize);
  }

  @override
  AudioEnhancementConfig get currentConfig => _config;

  @override
  Future<AudioEnhancementResult> processAudio(
    Float32List audioData,
    int sampleRate,
  ) async {
    if (!_isInitialized) {
      throw StateError('AudioEnhancementService not initialized');
    }

    if (audioData.isEmpty) {
      return AudioEnhancementResult(
        enhancedAudioData: Float32List(0),
        processingMetrics: Map.from(_performanceMetrics),
        processingTime: Duration.zero,
        noiseReductionApplied: 0.0,
        gainAdjustmentApplied: 0.0,
      );
    }

    final stopwatch = Stopwatch()..start();
    Float32List processedData = Float32List.fromList(audioData);
    double noiseReductionApplied = 0.0;
    double gainAdjustmentApplied = 0.0;

    try {
      // Apply frequency filtering first if enabled
      if (_config.enableFrequencyFiltering) {
        processedData = await applyFrequencyFiltering(
          processedData,
          sampleRate,
          _config.highPassCutoff,
          _config.lowPassCutoff,
        );
      }

      // Apply noise reduction if enabled
      if (_config.enableNoiseReduction) {
        final before = _calculateRMS(processedData);
        processedData = await applyNoiseReduction(
          processedData,
          sampleRate,
          _config.noiseReductionStrength,
        );
        final after = _calculateRMS(processedData);
        noiseReductionApplied = (before - after) / before;
      }

      // Apply spectral subtraction if enabled
      if (_config.enableSpectralSubtraction) {
        processedData = await applySpectralSubtraction(
          processedData,
          sampleRate,
          _config.spectralSubtractionAlpha,
          _config.spectralSubtractionBeta,
        );
      }

      // Apply echo cancellation if enabled
      if (_config.enableEchoCanellation) {
        processedData = await applyEchoCancellation(
          processedData,
          sampleRate,
          _config.echoCancellationStrength,
        );
      }

      // Apply automatic gain control if enabled
      if (_config.enableAutoGainControl) {
        final before = _calculateRMS(processedData);
        processedData = await applyAutoGainControl(
          processedData,
          sampleRate,
          _config.gainControlThreshold,
        );
        final after = _calculateRMS(processedData);
        gainAdjustmentApplied = (after - before) / before;
      }

      stopwatch.stop();

      // Update performance metrics
      _performanceMetrics['processedSamples'] =
          (_performanceMetrics['processedSamples'] ?? 0) + audioData.length;
      _performanceMetrics['totalProcessingTime'] =
          (_performanceMetrics['totalProcessingTime'] ?? 0) +
          stopwatch.elapsedMilliseconds;
      _performanceMetrics['averageProcessingTime'] =
          _performanceMetrics['totalProcessingTime'] /
          (_performanceMetrics['processedSamples'] / audioData.length);

      return AudioEnhancementResult(
        enhancedAudioData: processedData,
        processingMetrics: Map.from(_performanceMetrics),
        processingTime: stopwatch.elapsed,
        noiseReductionApplied: noiseReductionApplied,
        gainAdjustmentApplied: gainAdjustmentApplied,
      );
    } catch (e) {
      stopwatch.stop();
      throw Exception('Audio processing failed: $e');
    }
  }

  @override
  Stream<Float32List> processAudioStream(
    Stream<Float32List> audioStream,
    int sampleRate,
  ) async* {
    await for (final audioData in audioStream) {
      try {
        final result = await processAudio(audioData, sampleRate);
        yield result.enhancedAudioData;
      } catch (e) {
        // Log error but continue processing
        // Note: In production, use proper logging framework instead of print
        // ignore: avoid_print
        print('Error processing audio stream: $e');
        yield audioData; // Return original data if processing fails
      }
    }
  }

  @override
  Future<void> estimateNoiseProfile(
    Float32List audioData,
    int sampleRate,
  ) async {
    if (!_isInitialized) {
      throw StateError('AudioEnhancementService not initialized');
    }

    // Use the first part of the audio data to estimate noise profile
    final noiseLength = math.min(audioData.length, sampleRate); // 1 second max
    final noiseData = audioData.sublist(0, noiseLength);

    // Pad data to match FFT size
    final paddedData = _padToWindowSize(noiseData);

    // Calculate power spectrum of noise
    final spectrum = _fft.realFft(paddedData.toList());
    final powerSpectrum = Float32List(spectrum.length);

    for (int i = 0; i < powerSpectrum.length; i++) {
      final complex = spectrum[i];
      final real = complex.x;
      final imag = complex.y;
      powerSpectrum[i] = real * real + imag * imag;
    }

    _noiseProfile = powerSpectrum;
  }

  @override
  Future<Float32List> applyNoiseReduction(
    Float32List audioData,
    int sampleRate,
    double strength,
  ) async {
    _performanceMetrics['noiseReductionCalls']++;

    if (_noiseProfile == null) {
      // Estimate noise profile from beginning of audio if not available
      await estimateNoiseProfile(audioData, sampleRate);
    }

    // Apply simple noise gate based on RMS levels
    final rmsThreshold = _calculateRMS(audioData) * (1.0 - strength);
    final windowSize = 256;
    final processedData = Float32List(audioData.length);

    for (int i = 0; i < audioData.length; i += windowSize) {
      final end = math.min(i + windowSize, audioData.length);
      final window = audioData.sublist(i, end);
      final rms = _calculateRMS(window);

      if (rms > rmsThreshold) {
        // Keep original signal
        for (int j = i; j < end; j++) {
          processedData[j] = audioData[j];
        }
      } else {
        // Attenuate noise
        for (int j = i; j < end; j++) {
          processedData[j] = audioData[j] * (1.0 - strength);
        }
      }
    }

    return processedData;
  }

  @override
  Future<Float32List> applyEchoCancellation(
    Float32List audioData,
    int sampleRate,
    double strength,
  ) async {
    _performanceMetrics['echoCancellationCalls']++;

    // Simple echo cancellation using delayed subtraction
    final delayLength = (sampleRate * 0.1).round(); // 100ms delay
    final processedData = Float32List.fromList(audioData);

    for (int i = delayLength; i < audioData.length; i++) {
      processedData[i] =
          audioData[i] - (audioData[i - delayLength] * strength * 0.5);
    }

    return processedData;
  }

  @override
  Future<Float32List> applyAutoGainControl(
    Float32List audioData,
    int sampleRate,
    double threshold,
  ) async {
    _performanceMetrics['gainControlCalls']++;

    final processedData = Float32List(audioData.length);
    final windowSize = 1024;

    for (int i = 0; i < audioData.length; i += windowSize) {
      final end = math.min(i + windowSize, audioData.length);
      final window = audioData.sublist(i, end);
      final rms = _calculateRMS(window);

      double gain = 1.0;
      if (rms > threshold) {
        gain = threshold / rms;
      } else if (rms < threshold * 0.1) {
        gain = math.min(2.0, (threshold * 0.1) / rms);
      }

      for (int j = i; j < end; j++) {
        processedData[j] = audioData[j] * gain;
      }
    }

    return processedData;
  }

  @override
  Future<Float32List> applySpectralSubtraction(
    Float32List audioData,
    int sampleRate,
    double alpha,
    double beta,
  ) async {
    if (_noiseProfile == null) {
      await estimateNoiseProfile(audioData, sampleRate);
    }

    return _processInChunks(audioData, sampleRate, (chunk, sr) async {
      // Pad data to match FFT size
      final paddedData = _padToWindowSize(chunk);

      // Apply spectral subtraction in frequency domain
      final spectrum = _fft.realFft(paddedData.toList());
      final processedSpectrum = Float64x2List(spectrum.length);

      for (int i = 0; i < spectrum.length; i++) {
        final complex = spectrum[i];
        final real = complex.x;
        final imag = complex.y;
        final magnitude = math.sqrt(real * real + imag * imag);
        final phase = math.atan2(imag, real);

        // Apply spectral subtraction
        final noiseIndex = i % _noiseProfile!.length;
        final noiseMagnitude = math.sqrt(_noiseProfile![noiseIndex]);
        final subtractedMagnitude = magnitude - alpha * noiseMagnitude;
        final finalMagnitude = math.max(beta * magnitude, subtractedMagnitude);

        processedSpectrum[i] = Float64x2(
          finalMagnitude * math.cos(phase),
          finalMagnitude * math.sin(phase),
        );
      }

      // Convert back to time domain
      final ifft = FFT(processedSpectrum.length);
      final result = ifft.realInverseFft(processedSpectrum);

      // Return original chunk size
      return Float32List.fromList(result.take(chunk.length).toList());
    });
  }

  @override
  Future<Float32List> applyFrequencyFiltering(
    Float32List audioData,
    int sampleRate,
    double highPassCutoff,
    double lowPassCutoff,
  ) async {
    return _processInChunks(audioData, sampleRate, (chunk, sr) async {
      // Pad data to match FFT size
      final paddedData = _padToWindowSize(chunk);

      // Simple frequency filtering using FFT
      final spectrum = _fft.realFft(paddedData.toList());
      final processedSpectrum = Float64x2List(spectrum.length);

      final nyquist = sr / 2;
      final binSize = nyquist / spectrum.length;

      for (int i = 0; i < spectrum.length; i++) {
        final frequency = i * binSize;

        double filterGain = 1.0;
        if (frequency < highPassCutoff) {
          filterGain *= frequency / highPassCutoff;
        }
        if (frequency > lowPassCutoff) {
          filterGain *= math.exp(
            -((frequency - lowPassCutoff) / (nyquist - lowPassCutoff)),
          );
        }

        final complex = spectrum[i];
        processedSpectrum[i] = Float64x2(
          complex.x * filterGain,
          complex.y * filterGain,
        );
      }

      // Convert back to time domain
      final ifft = FFT(processedSpectrum.length);
      final result = ifft.realInverseFft(processedSpectrum);

      // Return original chunk size
      return Float32List.fromList(result.take(chunk.length).toList());
    });
  }

  @override
  List<AudioEnhancementType> getSupportedEnhancements() {
    return [
      AudioEnhancementType.noiseReduction,
      AudioEnhancementType.echocancellation,
      AudioEnhancementType.autoGainControl,
      AudioEnhancementType.spectralSubtraction,
      AudioEnhancementType.frequencyFiltering,
    ];
  }

  @override
  Future<bool> isReady() async {
    return _isInitialized;
  }

  @override
  ProcessingMode get processingMode => _config.processingMode;

  @override
  Future<void> setProcessingMode(ProcessingMode mode) async {
    _config = _config.copyWith(processingMode: mode);
  }

  @override
  Map<String, dynamic> getPerformanceMetrics() {
    return Map.from(_performanceMetrics);
  }

  @override
  Future<void> resetToDefaults() async {
    _config = const AudioEnhancementConfig();
    _noiseProfile = null;
    _performanceMetrics.clear();
  }

  double _calculateRMS(Float32List data) {
    double sum = 0.0;
    for (final sample in data) {
      sum += sample * sample;
    }
    return math.sqrt(sum / data.length);
  }

  Float32List _padToWindowSize(Float32List data) {
    final targetSize = _config.windowSize;
    if (data.length >= targetSize) {
      return data.sublist(0, targetSize);
    }

    final padded = Float32List(targetSize);
    for (int i = 0; i < data.length; i++) {
      padded[i] = data[i];
    }
    // Remaining elements are already 0 from Float32List constructor
    return padded;
  }

  Future<Float32List> _processInChunks(
    Float32List audioData,
    int sampleRate,
    Future<Float32List> Function(Float32List chunk, int sampleRate) processor,
  ) async {
    if (audioData.length <= _config.windowSize) {
      return await processor(audioData, sampleRate);
    }

    final result = Float32List(audioData.length);
    final chunkSize = _config.windowSize;
    final overlapSize = _config.overlapSize;

    for (int i = 0; i < audioData.length; i += chunkSize - overlapSize) {
      final end = math.min(i + chunkSize, audioData.length);
      final chunk = audioData.sublist(i, end);
      final processedChunk = await processor(chunk, sampleRate);

      // Copy processed chunk to result with overlap handling
      final copyLength = math.min(processedChunk.length, result.length - i);
      for (int j = 0; j < copyLength; j++) {
        if (i + j < result.length) {
          result[i + j] = processedChunk[j];
        }
      }
    }

    return result;
  }
}
