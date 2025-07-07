# Audio Enhancement Capabilities

The meeting summarizer includes comprehensive audio enhancement features powered by FFT-based signal processing to improve audio quality for better transcription and analysis.

## Core Audio Enhancement Features

- **Noise Reduction**: Advanced algorithms to reduce background noise while preserving speech clarity
- **Echo Cancellation**: Removes echo artifacts from recordings to improve audio quality
- **Automatic Gain Control (AGC)**: Dynamically adjusts audio levels to maintain consistent volume
- **Spectral Subtraction**: Advanced noise reduction using frequency domain analysis
- **Frequency Filtering**: High-pass and low-pass filters to remove unwanted frequency components
- **Real-time Processing**: Stream-based processing for live audio enhancement
- **Post-processing Mode**: Batch processing for recorded audio files

## Dependencies & Libraries

- **fftea ^1.5.0+1**: Fast Fourier Transform library for frequency domain processing
- Supports efficient FFT/IFFT operations for real-time audio processing
- Optimized for power-of-two and arbitrary-sized arrays

## Audio Enhancement Service Usage

### Basic Setup

```dart
// Initialize the service
final enhancementService = AudioEnhancementService();
await enhancementService.initialize();

// Configure enhancement parameters
final config = AudioEnhancementConfig(
  enableNoiseReduction: true,
  enableEchoCanellation: false,
  enableAutoGainControl: true,
  noiseReductionStrength: 0.7,
  processingMode: ProcessingMode.realTime,
);
await enhancementService.configure(config);
```

### Processing Audio Data

```dart
// Process audio data
final result = await enhancementService.processAudio(audioData, sampleRate);

// Stream processing for real-time enhancement
final enhancedStream = enhancementService.processAudioStream(
  inputAudioStream, 
  sampleRate
);
```

### Individual Enhancement Functions

```dart
// Apply specific enhancements individually
final noiseCleaned = await enhancementService.applyNoiseReduction(audioData, sampleRate, 0.5);
final echoFree = await enhancementService.applyEchoCancellation(audioData, sampleRate, 0.3);
final normalized = await enhancementService.applyAutoGainControl(audioData, sampleRate, 0.8);
final filtered = await enhancementService.applyFrequencyFiltering(audioData, sampleRate, 80.0, 8000.0);
final spectralCleaned = await enhancementService.applySpectralSubtraction(audioData, sampleRate, 2.0, 0.01);
```

## Configuration Options

### AudioEnhancementConfig Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableNoiseReduction` | bool | true | Enable/disable noise reduction |
| `enableEchoCanellation` | bool | false | Enable/disable echo cancellation |
| `enableAutoGainControl` | bool | true | Enable/disable automatic gain control |
| `enableSpectralSubtraction` | bool | false | Enable/disable spectral subtraction |
| `enableFrequencyFiltering` | bool | false | Enable/disable frequency filtering |
| `processingMode` | ProcessingMode | realTime | Real-time or post-processing mode |
| `noiseReductionStrength` | double | 0.5 | Noise reduction intensity (0.0-1.0) |
| `echoCancellationStrength` | double | 0.5 | Echo cancellation intensity (0.0-1.0) |
| `gainControlThreshold` | double | 0.8 | AGC activation threshold |
| `spectralSubtractionAlpha` | double | 2.0 | Spectral subtraction over-subtraction factor |
| `spectralSubtractionBeta` | double | 0.01 | Spectral subtraction spectral floor factor |
| `highPassCutoff` | double | 80.0 | High-pass filter cutoff frequency (Hz) |
| `lowPassCutoff` | double | 8000.0 | Low-pass filter cutoff frequency (Hz) |
| `windowSize` | int | 1024 | FFT window size |
| `overlapSize` | int | 512 | Overlap size for chunk processing |

## Performance & Metrics

The service includes comprehensive performance tracking:

- **Processing Time**: Elapsed time for each audio chunk
- **Total Samples**: Cumulative number of samples processed
- **Average Processing Time**: Running average of processing latency
- **Algorithm Usage**: Counters for each enhancement type

### Accessing Performance Metrics

```dart
// Get current performance metrics
final metrics = enhancementService.getPerformanceMetrics();
print('Processed samples: ${metrics['processedSamples']}');
print('Average processing time: ${metrics['averageProcessingTime']}ms');
print('Noise reduction calls: ${metrics['noiseReductionCalls']}');
```

## Processing Modes

### Real-time Mode
- Designed for live audio streams
- Low-latency processing
- Optimized for continuous operation
- Suitable for recording applications

### Post-processing Mode
- Batch processing of recorded files
- Higher quality algorithms
- More computational resources available
- Suitable for file enhancement

```dart
// Switch processing modes
await enhancementService.setProcessingMode(ProcessingMode.postProcessing);
```

## Algorithm Details

### Noise Reduction
- Uses RMS-based noise gating
- Adaptive threshold based on signal characteristics
- Preserves speech content while attenuating background noise

### Echo Cancellation
- Delayed subtraction algorithm
- Configurable delay length (default: 100ms)
- Effective for removing echo artifacts

### Automatic Gain Control
- Windowed RMS analysis
- Dynamic range compression
- Prevents clipping and maintains consistent levels

### Spectral Subtraction
- Frequency domain noise reduction
- Estimates noise profile from silent sections
- Applies over-subtraction with spectral floor

### Frequency Filtering
- FFT-based high-pass and low-pass filtering
- Removes unwanted frequency components
- Preserves speech frequency range

## Integration with Audio Configuration

The existing `AudioConfiguration` class includes built-in support for enhancement features:

```dart
final audioConfig = AudioConfiguration(
  enableNoiseReduction: true,      // Integrates with enhancement service
  enableAutoGainControl: true,     // Integrates with enhancement service
  // ... other audio settings
);
```

The audio enhancement service seamlessly integrates with the existing audio recording pipeline and can be enabled/disabled through the standard audio configuration.

## Best Practices

### Real-time Applications
- Use minimal enhancement settings for low latency
- Enable only essential algorithms (noise reduction, AGC)
- Monitor performance metrics to ensure real-time performance

### Post-processing Applications
- Enable all applicable enhancements for maximum quality
- Use higher-quality settings (larger window sizes, stronger algorithms)
- Process in batches for efficiency

### Configuration Tuning
- Adjust noise reduction strength based on environment
- Use echo cancellation only when echo is present
- Tune frequency filters based on audio content type

### Error Handling
- Always check service initialization status
- Handle processing exceptions gracefully
- Fallback to original audio if enhancement fails

```dart
try {
  final result = await enhancementService.processAudio(audioData, sampleRate);
  return result.enhancedAudioData;
} catch (e) {
  print('Enhancement failed: $e');
  return audioData; // Return original audio
}
```