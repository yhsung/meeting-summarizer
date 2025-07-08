/// Model for transcription request configuration
library;

import '../enums/transcription_language.dart';

/// Configuration for audio transcription requests
class TranscriptionRequest {
  /// Target language for transcription (auto-detect if null)
  final TranscriptionLanguage? language;

  /// Custom prompt to guide the transcription (optional)
  final String? prompt;

  /// Temperature for transcription (0.0 - 1.0, higher = more random)
  final double temperature;

  /// File format of the audio (e.g., 'mp3', 'wav', 'm4a')
  final String? audioFormat;

  /// Whether to enable timestamp generation
  final bool enableTimestamps;

  /// Whether to enable word-level timestamps
  final bool enableWordTimestamps;

  /// Maximum number of alternative transcriptions to return
  final int maxAlternatives;

  /// Custom vocabulary to improve accuracy for specific terms
  final List<String>? customVocabulary;

  /// Model to use for transcription (e.g., 'whisper-1')
  final String model;

  /// Response format ('json', 'text', 'srt', 'verbose_json', 'vtt')
  final String responseFormat;

  /// Quality preference for speed vs accuracy trade-off
  final TranscriptionQuality quality;

  /// Whether to enable speaker diarization (identification)
  final bool enableSpeakerDiarization;

  /// Maximum number of speakers to identify (if diarization enabled)
  final int? maxSpeakers;

  /// Whether to enable profanity filtering
  final bool enableProfanityFilter;

  /// Custom metadata to include with the request
  final Map<String, dynamic>? metadata;

  const TranscriptionRequest({
    this.language,
    this.prompt,
    this.temperature = 0.0,
    this.audioFormat,
    this.enableTimestamps = false,
    this.enableWordTimestamps = false,
    this.maxAlternatives = 1,
    this.customVocabulary,
    this.model = 'whisper-1',
    this.responseFormat = 'verbose_json',
    this.quality = TranscriptionQuality.balanced,
    this.enableSpeakerDiarization = false,
    this.maxSpeakers,
    this.enableProfanityFilter = false,
    this.metadata,
  });

  /// Create a request with default settings
  factory TranscriptionRequest.withDefaults({
    TranscriptionLanguage? language,
    String? prompt,
  }) {
    return TranscriptionRequest(
      language: language,
      prompt: prompt,
      enableTimestamps: true,
      quality: TranscriptionQuality.balanced,
    );
  }

  /// Create a high-quality request for important recordings
  factory TranscriptionRequest.highQuality({
    TranscriptionLanguage? language,
    String? prompt,
    List<String>? customVocabulary,
  }) {
    return TranscriptionRequest(
      language: language,
      prompt: prompt,
      customVocabulary: customVocabulary,
      enableTimestamps: true,
      enableWordTimestamps: true,
      enableSpeakerDiarization: true,
      quality: TranscriptionQuality.high,
      temperature: 0.0,
    );
  }

  /// Create a fast request for quick transcription
  factory TranscriptionRequest.fast({TranscriptionLanguage? language}) {
    return TranscriptionRequest(
      language: language,
      quality: TranscriptionQuality.fast,
      enableTimestamps: false,
      enableWordTimestamps: false,
      temperature: 0.2,
    );
  }

  /// Copy with modified parameters
  TranscriptionRequest copyWith({
    TranscriptionLanguage? language,
    String? prompt,
    double? temperature,
    String? audioFormat,
    bool? enableTimestamps,
    bool? enableWordTimestamps,
    int? maxAlternatives,
    List<String>? customVocabulary,
    String? model,
    String? responseFormat,
    TranscriptionQuality? quality,
    bool? enableSpeakerDiarization,
    int? maxSpeakers,
    bool? enableProfanityFilter,
    Map<String, dynamic>? metadata,
  }) {
    return TranscriptionRequest(
      language: language ?? this.language,
      prompt: prompt ?? this.prompt,
      temperature: temperature ?? this.temperature,
      audioFormat: audioFormat ?? this.audioFormat,
      enableTimestamps: enableTimestamps ?? this.enableTimestamps,
      enableWordTimestamps: enableWordTimestamps ?? this.enableWordTimestamps,
      maxAlternatives: maxAlternatives ?? this.maxAlternatives,
      customVocabulary: customVocabulary ?? this.customVocabulary,
      model: model ?? this.model,
      responseFormat: responseFormat ?? this.responseFormat,
      quality: quality ?? this.quality,
      enableSpeakerDiarization:
          enableSpeakerDiarization ?? this.enableSpeakerDiarization,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      enableProfanityFilter:
          enableProfanityFilter ?? this.enableProfanityFilter,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model': model,
      'response_format': responseFormat,
      'temperature': temperature,
    };

    if (language != null && language != TranscriptionLanguage.auto) {
      json['language'] = language!.code;
    }

    if (prompt != null && prompt!.isNotEmpty) {
      json['prompt'] = prompt;
    }

    if (enableTimestamps) {
      json['timestamp_granularities'] = ['segment'];
      if (enableWordTimestamps) {
        json['timestamp_granularities'] = ['segment', 'word'];
      }
    }

    return json;
  }

  /// Convert to API-specific parameters
  Map<String, dynamic> toApiParameters() {
    final params = toJson();

    // Add internal parameters that don't go to the API
    params['quality'] = quality.name;
    params['enable_speaker_diarization'] = enableSpeakerDiarization;
    params['max_speakers'] = maxSpeakers;
    params['enable_profanity_filter'] = enableProfanityFilter;

    if (customVocabulary != null && customVocabulary!.isNotEmpty) {
      params['custom_vocabulary'] = customVocabulary;
    }

    if (metadata != null) {
      params['metadata'] = metadata;
    }

    return params;
  }

  @override
  String toString() {
    return 'TranscriptionRequest('
        'language: ${language?.displayName ?? 'auto'}, '
        'model: $model, '
        'quality: ${quality.name}, '
        'timestamps: $enableTimestamps'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TranscriptionRequest &&
        other.language == language &&
        other.prompt == prompt &&
        other.temperature == temperature &&
        other.audioFormat == audioFormat &&
        other.enableTimestamps == enableTimestamps &&
        other.enableWordTimestamps == enableWordTimestamps &&
        other.maxAlternatives == maxAlternatives &&
        other.model == model &&
        other.responseFormat == responseFormat &&
        other.quality == quality &&
        other.enableSpeakerDiarization == enableSpeakerDiarization &&
        other.maxSpeakers == maxSpeakers &&
        other.enableProfanityFilter == enableProfanityFilter;
  }

  @override
  int get hashCode {
    return Object.hash(
      language,
      prompt,
      temperature,
      audioFormat,
      enableTimestamps,
      enableWordTimestamps,
      maxAlternatives,
      model,
      responseFormat,
      quality,
      enableSpeakerDiarization,
      maxSpeakers,
      enableProfanityFilter,
    );
  }
}

/// Quality levels for transcription
enum TranscriptionQuality {
  /// Fast transcription with lower accuracy
  fast,

  /// Balanced speed and accuracy (default)
  balanced,

  /// High accuracy with slower processing
  high,

  /// Maximum accuracy with longest processing time
  maximum;

  /// Get display name for the quality level
  String get displayName {
    switch (this) {
      case TranscriptionQuality.fast:
        return 'Fast';
      case TranscriptionQuality.balanced:
        return 'Balanced';
      case TranscriptionQuality.high:
        return 'High Quality';
      case TranscriptionQuality.maximum:
        return 'Maximum Quality';
    }
  }

  /// Get description of the quality level
  String get description {
    switch (this) {
      case TranscriptionQuality.fast:
        return 'Quick transcription with basic accuracy';
      case TranscriptionQuality.balanced:
        return 'Good balance of speed and accuracy';
      case TranscriptionQuality.high:
        return 'High accuracy with longer processing time';
      case TranscriptionQuality.maximum:
        return 'Best possible accuracy, slowest processing';
    }
  }

  /// Get recommended use case
  String get useCase {
    switch (this) {
      case TranscriptionQuality.fast:
        return 'Quick notes, casual recordings';
      case TranscriptionQuality.balanced:
        return 'General meetings, interviews';
      case TranscriptionQuality.high:
        return 'Important meetings, legal recordings';
      case TranscriptionQuality.maximum:
        return 'Critical documents, formal proceedings';
    }
  }
}
