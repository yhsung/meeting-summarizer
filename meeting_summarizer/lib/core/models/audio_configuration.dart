import '../enums/audio_format.dart';
import '../enums/audio_quality.dart';

class AudioConfiguration {
  final AudioFormat format;
  final AudioQuality quality;
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final bool enableNoiseReduction;
  final bool enableAutoGainControl;
  final Duration? recordingLimit;
  final String? outputDirectory;
  final int? maxFileSizeMB;
  final bool adaptiveQuality;

  AudioConfiguration({
    this.format = AudioFormat.wav,
    this.quality = AudioQuality.high,
    int? sampleRate,
    int? bitDepth,
    this.channels = 1,
    this.enableNoiseReduction = true,
    this.enableAutoGainControl = true,
    this.recordingLimit,
    this.outputDirectory,
    this.maxFileSizeMB,
    this.adaptiveQuality = false,
  }) : sampleRate = sampleRate ?? quality.sampleRate,
       bitDepth = bitDepth ?? quality.bitDepth;

  const AudioConfiguration.raw({
    required this.format,
    required this.quality,
    required this.sampleRate,
    required this.bitDepth,
    this.channels = 1,
    this.enableNoiseReduction = true,
    this.enableAutoGainControl = true,
    this.recordingLimit,
    this.outputDirectory,
    this.maxFileSizeMB,
    this.adaptiveQuality = false,
  });

  bool get noiseReduction => enableNoiseReduction;
  bool get autoGainControl => enableAutoGainControl;

  int get bitRate => quality.bitRate;

  double get estimatedFileSizePerMinute {
    final bytesPerSecond = (sampleRate * bitDepth * channels) / 8;
    final sizeInMB = (bytesPerSecond * 60) / (1024 * 1024);
    return sizeInMB * format.compressionRatio;
  }

  bool get isStereo => channels == 2;
  bool get isMono => channels == 1;

  String get configurationSummary {
    return '${format.extension.toUpperCase()} • ${quality.label} • ${sampleRate}Hz • ${bitDepth}bit • ${channels}ch';
  }

  AudioConfiguration copyWith({
    AudioFormat? format,
    AudioQuality? quality,
    int? sampleRate,
    int? bitDepth,
    int? channels,
    bool? enableNoiseReduction,
    bool? enableAutoGainControl,
    Duration? recordingLimit,
    String? outputDirectory,
    int? maxFileSizeMB,
    bool? adaptiveQuality,
  }) {
    return AudioConfiguration(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
      enableNoiseReduction: enableNoiseReduction ?? this.enableNoiseReduction,
      enableAutoGainControl:
          enableAutoGainControl ?? this.enableAutoGainControl,
      recordingLimit: recordingLimit ?? this.recordingLimit,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      maxFileSizeMB: maxFileSizeMB ?? this.maxFileSizeMB,
      adaptiveQuality: adaptiveQuality ?? this.adaptiveQuality,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'format': format.extension,
      'quality': quality.label,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'channels': channels,
      'enableNoiseReduction': enableNoiseReduction,
      'enableAutoGainControl': enableAutoGainControl,
      'recordingLimit': recordingLimit?.inSeconds,
      'outputDirectory': outputDirectory,
      'maxFileSizeMB': maxFileSizeMB,
      'adaptiveQuality': adaptiveQuality,
    };
  }

  factory AudioConfiguration.fromMap(Map<String, dynamic> map) {
    return AudioConfiguration(
      format: AudioFormat.fromExtension(map['format'] ?? 'wav'),
      quality: AudioQuality.values.firstWhere(
        (q) => q.label == map['quality'],
        orElse: () => AudioQuality.high,
      ),
      sampleRate: map['sampleRate'],
      bitDepth: map['bitDepth'],
      channels: map['channels'] ?? 1,
      enableNoiseReduction: map['enableNoiseReduction'] ?? true,
      enableAutoGainControl: map['enableAutoGainControl'] ?? true,
      recordingLimit: map['recordingLimit'] != null
          ? Duration(seconds: map['recordingLimit'])
          : null,
      outputDirectory: map['outputDirectory'],
      maxFileSizeMB: map['maxFileSizeMB'],
      adaptiveQuality: map['adaptiveQuality'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioConfiguration &&
        other.format == format &&
        other.quality == quality &&
        other.sampleRate == sampleRate &&
        other.bitDepth == bitDepth &&
        other.channels == channels &&
        other.enableNoiseReduction == enableNoiseReduction &&
        other.enableAutoGainControl == enableAutoGainControl &&
        other.recordingLimit == recordingLimit &&
        other.outputDirectory == outputDirectory &&
        other.maxFileSizeMB == maxFileSizeMB &&
        other.adaptiveQuality == adaptiveQuality;
  }

  @override
  int get hashCode {
    return Object.hash(
      format,
      quality,
      sampleRate,
      bitDepth,
      channels,
      enableNoiseReduction,
      enableAutoGainControl,
      recordingLimit,
      outputDirectory,
      maxFileSizeMB,
      adaptiveQuality,
    );
  }
}
