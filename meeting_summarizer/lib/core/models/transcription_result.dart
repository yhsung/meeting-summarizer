/// Model for transcription results
library;

import '../enums/transcription_language.dart';

/// Result of an audio transcription operation
class TranscriptionResult {
  /// The transcribed text
  final String text;

  /// Confidence score (0.0 - 1.0)
  final double confidence;

  /// Detected or specified language
  final TranscriptionLanguage? language;

  /// Processing time in milliseconds
  final int processingTimeMs;

  /// Audio duration in milliseconds
  final int audioDurationMs;

  /// Individual segments with timestamps (if enabled)
  final List<TranscriptionSegment> segments;

  /// Word-level timestamps (if enabled)
  final List<TranscriptionWord> words;

  /// Identified speakers (if speaker diarization enabled)
  final List<Speaker> speakers;

  /// Alternative transcriptions
  final List<TranscriptionAlternative> alternatives;

  /// Provider that generated this transcription
  final String provider;

  /// Model used for transcription
  final String model;

  /// Metadata from the transcription service
  final Map<String, dynamic> metadata;

  /// Timestamp when transcription was created
  final DateTime createdAt;

  /// Quality metrics for the transcription
  final TranscriptionQualityMetrics? qualityMetrics;

  const TranscriptionResult({
    required this.text,
    required this.confidence,
    this.language,
    required this.processingTimeMs,
    required this.audioDurationMs,
    this.segments = const [],
    this.words = const [],
    this.speakers = const [],
    this.alternatives = const [],
    required this.provider,
    required this.model,
    this.metadata = const {},
    required this.createdAt,
    this.qualityMetrics,
  });

  /// Create from OpenAI Whisper API response
  factory TranscriptionResult.fromWhisperResponse(
    Map<String, dynamic> response, {
    required int processingTimeMs,
    required int audioDurationMs,
    String provider = 'openai_whisper',
  }) {
    final text = response['text'] as String? ?? '';
    final language = response['language'] as String?;
    final segments = <TranscriptionSegment>[];
    final words = <TranscriptionWord>[];

    // Parse segments if available
    if (response['segments'] is List) {
      final segmentsList = response['segments'] as List;
      for (final segmentData in segmentsList) {
        if (segmentData is Map<String, dynamic>) {
          segments.add(TranscriptionSegment.fromJson(segmentData));

          // Extract words from segment
          if (segmentData['words'] is List) {
            final wordsList = segmentData['words'] as List;
            for (final wordData in wordsList) {
              if (wordData is Map<String, dynamic>) {
                words.add(TranscriptionWord.fromJson(wordData));
              }
            }
          }
        }
      }
    }

    return TranscriptionResult(
      text: text,
      confidence: _calculateOverallConfidence(segments),
      language: language != null
          ? TranscriptionLanguage.fromCode(language)
          : null,
      processingTimeMs: processingTimeMs,
      audioDurationMs: audioDurationMs,
      segments: segments,
      words: words,
      provider: provider,
      model: response['model'] as String? ?? 'whisper-1',
      metadata: response,
      createdAt: DateTime.now(),
      qualityMetrics: TranscriptionQualityMetrics.fromSegments(segments),
    );
  }

  /// Calculate overall confidence from segments
  static double _calculateOverallConfidence(
    List<TranscriptionSegment> segments,
  ) {
    if (segments.isEmpty) return 0.9; // Default confidence for simple responses

    double totalConfidence = 0.0;
    double totalDuration = 0.0;

    for (final segment in segments) {
      final duration = segment.end - segment.start;
      totalConfidence += segment.confidence * duration;
      totalDuration += duration;
    }

    return totalDuration > 0 ? totalConfidence / totalDuration : 0.9;
  }

  /// Get formatted text with timestamps
  String getFormattedTextWithTimestamps() {
    if (segments.isEmpty) return text;

    final buffer = StringBuffer();
    for (final segment in segments) {
      buffer.writeln(
        '[${_formatTimestamp(segment.start)} - ${_formatTimestamp(segment.end)}]',
      );
      buffer.writeln(segment.text.trim());
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Format timestamp for display
  String _formatTimestamp(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final milliseconds = ((seconds - seconds.floor()) * 1000).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }

  /// Get text by time range
  String getTextByTimeRange(double startSeconds, double endSeconds) {
    final filteredSegments = segments.where(
      (segment) => segment.start >= startSeconds && segment.end <= endSeconds,
    );

    return filteredSegments.map((segment) => segment.text).join(' ').trim();
  }

  /// Get speaker timeline
  List<SpeakerTimelineEntry> getSpeakerTimeline() {
    final timeline = <SpeakerTimelineEntry>[];
    String? currentSpeaker;
    double? segmentStart;
    final textBuffer = StringBuffer();

    for (final segment in segments) {
      if (segment.speakerId != currentSpeaker) {
        // Speaker changed, save previous segment
        if (currentSpeaker != null && segmentStart != null) {
          timeline.add(
            SpeakerTimelineEntry(
              speakerId: currentSpeaker,
              start: segmentStart,
              end: segment.start,
              text: textBuffer.toString().trim(),
            ),
          );
        }

        // Start new segment
        currentSpeaker = segment.speakerId;
        segmentStart = segment.start;
        textBuffer.clear();
      }

      textBuffer.write('${segment.text} ');
    }

    // Add final segment
    if (currentSpeaker != null && segmentStart != null && segments.isNotEmpty) {
      timeline.add(
        SpeakerTimelineEntry(
          speakerId: currentSpeaker,
          start: segmentStart,
          end: segments.last.end,
          text: textBuffer.toString().trim(),
        ),
      );
    }

    return timeline;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'language': language?.code,
      'processing_time_ms': processingTimeMs,
      'audio_duration_ms': audioDurationMs,
      'segments': segments.map((s) => s.toJson()).toList(),
      'words': words.map((w) => w.toJson()).toList(),
      'speakers': speakers.map((s) => s.toJson()).toList(),
      'alternatives': alternatives.map((a) => a.toJson()).toList(),
      'provider': provider,
      'model': model,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'quality_metrics': qualityMetrics?.toJson(),
    };
  }

  /// Create from JSON
  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      confidence: json['confidence'] as double,
      language: json['language'] != null
          ? TranscriptionLanguage.fromCode(json['language'] as String)
          : null,
      processingTimeMs: json['processing_time_ms'] as int,
      audioDurationMs: json['audio_duration_ms'] as int,
      segments:
          (json['segments'] as List?)
              ?.map(
                (s) => TranscriptionSegment.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          [],
      words:
          (json['words'] as List?)
              ?.map(
                (w) => TranscriptionWord.fromJson(w as Map<String, dynamic>),
              )
              .toList() ??
          [],
      speakers:
          (json['speakers'] as List?)
              ?.map((s) => Speaker.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      alternatives:
          (json['alternatives'] as List?)
              ?.map(
                (a) => TranscriptionAlternative.fromJson(
                  a as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      provider: json['provider'] as String,
      model: json['model'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      qualityMetrics: json['quality_metrics'] != null
          ? TranscriptionQualityMetrics.fromJson(
              json['quality_metrics'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  @override
  String toString() =>
      'TranscriptionResult(text: ${text.length} chars, confidence: $confidence)';
}

/// A segment of transcribed text with timing information
class TranscriptionSegment {
  final String text;
  final double start;
  final double end;
  final double confidence;
  final String? speakerId;

  const TranscriptionSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
    this.speakerId,
  });

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      text: json['text'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      speakerId: json['speaker_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'start': start,
      'end': end,
      'confidence': confidence,
      if (speakerId != null) 'speaker_id': speakerId,
    };
  }

  Duration get duration =>
      Duration(milliseconds: ((end - start) * 1000).round());
}

/// A single transcribed word with timing information
class TranscriptionWord {
  final String word;
  final double start;
  final double end;
  final double confidence;

  const TranscriptionWord({
    required this.word,
    required this.start,
    required this.end,
    required this.confidence,
  });

  factory TranscriptionWord.fromJson(Map<String, dynamic> json) {
    return TranscriptionWord(
      word: json['word'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'word': word, 'start': start, 'end': end, 'confidence': confidence};
  }
}

/// Identified speaker information
class Speaker {
  final String id;
  final String? name;
  final double confidence;
  final Map<String, dynamic> metadata;

  const Speaker({
    required this.id,
    this.name,
    required this.confidence,
    this.metadata = const {},
  });

  factory Speaker.fromJson(Map<String, dynamic> json) {
    return Speaker(
      id: json['id'] as String,
      name: json['name'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      'confidence': confidence,
      'metadata': metadata,
    };
  }
}

/// Alternative transcription result
class TranscriptionAlternative {
  final String text;
  final double confidence;

  const TranscriptionAlternative({
    required this.text,
    required this.confidence,
  });

  factory TranscriptionAlternative.fromJson(Map<String, dynamic> json) {
    return TranscriptionAlternative(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'confidence': confidence};
  }
}

/// Quality metrics for transcription
class TranscriptionQualityMetrics {
  final double averageConfidence;
  final double confidenceVariance;
  final int lowConfidenceSegments;
  final int totalSegments;
  final double speechRate; // words per minute
  final int silencePeriods;

  const TranscriptionQualityMetrics({
    required this.averageConfidence,
    required this.confidenceVariance,
    required this.lowConfidenceSegments,
    required this.totalSegments,
    required this.speechRate,
    required this.silencePeriods,
  });

  factory TranscriptionQualityMetrics.fromSegments(
    List<TranscriptionSegment> segments,
  ) {
    if (segments.isEmpty) {
      return const TranscriptionQualityMetrics(
        averageConfidence: 0.9,
        confidenceVariance: 0.0,
        lowConfidenceSegments: 0,
        totalSegments: 0,
        speechRate: 0.0,
        silencePeriods: 0,
      );
    }

    final confidences = segments.map((s) => s.confidence).toList();
    final averageConfidence =
        confidences.reduce((a, b) => a + b) / confidences.length;

    final variance =
        confidences
            .map((c) => (c - averageConfidence) * (c - averageConfidence))
            .reduce((a, b) => a + b) /
        confidences.length;

    final lowConfidenceSegments = segments
        .where((s) => s.confidence < 0.8)
        .length;

    // Calculate speech rate (approximate)
    final totalDuration = segments.isEmpty
        ? 0.0
        : segments.last.end - segments.first.start;
    final totalWords = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.text.split(' ').length,
    );
    final speechRate = totalDuration > 0
        ? (totalWords / totalDuration) * 60
        : 0.0;

    return TranscriptionQualityMetrics(
      averageConfidence: averageConfidence,
      confidenceVariance: variance,
      lowConfidenceSegments: lowConfidenceSegments,
      totalSegments: segments.length,
      speechRate: speechRate,
      silencePeriods: 0, // Would need additional analysis to calculate
    );
  }

  factory TranscriptionQualityMetrics.fromJson(Map<String, dynamic> json) {
    return TranscriptionQualityMetrics(
      averageConfidence: (json['average_confidence'] as num).toDouble(),
      confidenceVariance: (json['confidence_variance'] as num).toDouble(),
      lowConfidenceSegments: json['low_confidence_segments'] as int,
      totalSegments: json['total_segments'] as int,
      speechRate: (json['speech_rate'] as num).toDouble(),
      silencePeriods: json['silence_periods'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average_confidence': averageConfidence,
      'confidence_variance': confidenceVariance,
      'low_confidence_segments': lowConfidenceSegments,
      'total_segments': totalSegments,
      'speech_rate': speechRate,
      'silence_periods': silencePeriods,
    };
  }

  /// Overall quality score (0.0 - 1.0)
  double get qualityScore {
    final confidenceScore = averageConfidence;
    final consistencyScore = 1.0 - (confidenceVariance.clamp(0.0, 1.0));
    final reliabilityScore = totalSegments > 0
        ? 1.0 - (lowConfidenceSegments / totalSegments)
        : 1.0;

    return (confidenceScore + consistencyScore + reliabilityScore) / 3;
  }

  /// Quality rating
  String get qualityRating {
    final score = qualityScore;
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.8) return 'Good';
    if (score >= 0.7) return 'Fair';
    if (score >= 0.6) return 'Poor';
    return 'Very Poor';
  }
}

/// Speaker timeline entry for conversation analysis
class SpeakerTimelineEntry {
  final String speakerId;
  final double start;
  final double end;
  final String text;

  const SpeakerTimelineEntry({
    required this.speakerId,
    required this.start,
    required this.end,
    required this.text,
  });

  Duration get duration =>
      Duration(milliseconds: ((end - start) * 1000).round());

  Map<String, dynamic> toJson() {
    return {'speaker_id': speakerId, 'start': start, 'end': end, 'text': text};
  }
}
