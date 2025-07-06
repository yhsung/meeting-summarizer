import 'dart:typed_data';

/// Enum for different types of audio enhancement
enum AudioEnhancementType {
  noiseReduction,
  echocancellation,
  autoGainControl,
  spectralSubtraction,
  frequencyFiltering,
}

/// Enum for processing modes
enum ProcessingMode { realTime, postProcessing }

/// Configuration for audio enhancement parameters
class AudioEnhancementConfig {
  final bool enableNoiseReduction;
  final bool enableEchoCanellation;
  final bool enableAutoGainControl;
  final bool enableSpectralSubtraction;
  final bool enableFrequencyFiltering;
  final ProcessingMode processingMode;
  final double noiseReductionStrength;
  final double echoCancellationStrength;
  final double gainControlThreshold;
  final double spectralSubtractionAlpha;
  final double spectralSubtractionBeta;
  final double highPassCutoff;
  final double lowPassCutoff;
  final int windowSize;
  final int overlapSize;

  const AudioEnhancementConfig({
    this.enableNoiseReduction = true,
    this.enableEchoCanellation = false,
    this.enableAutoGainControl = true,
    this.enableSpectralSubtraction = false,
    this.enableFrequencyFiltering = false,
    this.processingMode = ProcessingMode.realTime,
    this.noiseReductionStrength = 0.5,
    this.echoCancellationStrength = 0.5,
    this.gainControlThreshold = 0.8,
    this.spectralSubtractionAlpha = 2.0,
    this.spectralSubtractionBeta = 0.01,
    this.highPassCutoff = 80.0,
    this.lowPassCutoff = 8000.0,
    this.windowSize = 1024,
    this.overlapSize = 512,
  });

  AudioEnhancementConfig copyWith({
    bool? enableNoiseReduction,
    bool? enableEchoCanellation,
    bool? enableAutoGainControl,
    bool? enableSpectralSubtraction,
    bool? enableFrequencyFiltering,
    ProcessingMode? processingMode,
    double? noiseReductionStrength,
    double? echoCancellationStrength,
    double? gainControlThreshold,
    double? spectralSubtractionAlpha,
    double? spectralSubtractionBeta,
    double? highPassCutoff,
    double? lowPassCutoff,
    int? windowSize,
    int? overlapSize,
  }) {
    return AudioEnhancementConfig(
      enableNoiseReduction: enableNoiseReduction ?? this.enableNoiseReduction,
      enableEchoCanellation:
          enableEchoCanellation ?? this.enableEchoCanellation,
      enableAutoGainControl:
          enableAutoGainControl ?? this.enableAutoGainControl,
      enableSpectralSubtraction:
          enableSpectralSubtraction ?? this.enableSpectralSubtraction,
      enableFrequencyFiltering:
          enableFrequencyFiltering ?? this.enableFrequencyFiltering,
      processingMode: processingMode ?? this.processingMode,
      noiseReductionStrength:
          noiseReductionStrength ?? this.noiseReductionStrength,
      echoCancellationStrength:
          echoCancellationStrength ?? this.echoCancellationStrength,
      gainControlThreshold: gainControlThreshold ?? this.gainControlThreshold,
      spectralSubtractionAlpha:
          spectralSubtractionAlpha ?? this.spectralSubtractionAlpha,
      spectralSubtractionBeta:
          spectralSubtractionBeta ?? this.spectralSubtractionBeta,
      highPassCutoff: highPassCutoff ?? this.highPassCutoff,
      lowPassCutoff: lowPassCutoff ?? this.lowPassCutoff,
      windowSize: windowSize ?? this.windowSize,
      overlapSize: overlapSize ?? this.overlapSize,
    );
  }
}

/// Result of audio enhancement processing
class AudioEnhancementResult {
  final Float32List enhancedAudioData;
  final Map<String, dynamic> processingMetrics;
  final Duration processingTime;
  final double noiseReductionApplied;
  final double gainAdjustmentApplied;

  const AudioEnhancementResult({
    required this.enhancedAudioData,
    required this.processingMetrics,
    required this.processingTime,
    required this.noiseReductionApplied,
    required this.gainAdjustmentApplied,
  });
}

/// Abstract interface for audio enhancement services
abstract class AudioEnhancementServiceInterface {
  /// Initialize the audio enhancement service
  Future<void> initialize();

  /// Dispose and cleanup resources
  Future<void> dispose();

  /// Configure enhancement parameters
  Future<void> configure(AudioEnhancementConfig config);

  /// Get current enhancement configuration
  AudioEnhancementConfig get currentConfig;

  /// Process audio data with enhancement
  Future<AudioEnhancementResult> processAudio(
    Float32List audioData,
    int sampleRate,
  );

  /// Process audio data in real-time stream
  Stream<Float32List> processAudioStream(
    Stream<Float32List> audioStream,
    int sampleRate,
  );

  /// Estimate noise profile from audio data
  Future<void> estimateNoiseProfile(Float32List audioData, int sampleRate);

  /// Apply noise reduction to audio data
  Future<Float32List> applyNoiseReduction(
    Float32List audioData,
    int sampleRate,
    double strength,
  );

  /// Apply echo cancellation to audio data
  Future<Float32List> applyEchoCancellation(
    Float32List audioData,
    int sampleRate,
    double strength,
  );

  /// Apply automatic gain control to audio data
  Future<Float32List> applyAutoGainControl(
    Float32List audioData,
    int sampleRate,
    double threshold,
  );

  /// Apply spectral subtraction noise reduction
  Future<Float32List> applySpectralSubtraction(
    Float32List audioData,
    int sampleRate,
    double alpha,
    double beta,
  );

  /// Apply frequency filtering (high-pass and low-pass)
  Future<Float32List> applyFrequencyFiltering(
    Float32List audioData,
    int sampleRate,
    double highPassCutoff,
    double lowPassCutoff,
  );

  /// Get available enhancement types for current platform
  List<AudioEnhancementType> getSupportedEnhancements();

  /// Check if enhancement service is ready
  Future<bool> isReady();

  /// Get current processing mode
  ProcessingMode get processingMode;

  /// Switch between real-time and post-processing modes
  Future<void> setProcessingMode(ProcessingMode mode);

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics();

  /// Reset all enhancement parameters to default
  Future<void> resetToDefaults();
}
