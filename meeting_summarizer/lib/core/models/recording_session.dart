import '../enums/recording_state.dart';
import 'audio_configuration.dart';

class RecordingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final RecordingState state;
  final Duration duration;
  final String? filePath;
  final double? fileSize;
  final AudioConfiguration configuration;
  final List<double> waveformData;
  final double currentAmplitude;
  final String? errorMessage;

  const RecordingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.state,
    required this.duration,
    this.filePath,
    this.fileSize,
    required this.configuration,
    this.waveformData = const [],
    this.currentAmplitude = 0.0,
    this.errorMessage,
  });

  RecordingSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    RecordingState? state,
    Duration? duration,
    String? filePath,
    double? fileSize,
    AudioConfiguration? configuration,
    List<double>? waveformData,
    double? currentAmplitude,
    String? errorMessage,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      state: state ?? this.state,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      configuration: configuration ?? this.configuration,
      waveformData: waveformData ?? this.waveformData,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isActive => state.isActive;
  bool get isPaused => state.isPaused;
  bool get isFinished => state.isStopped && filePath != null;
  bool get hasError => state == RecordingState.error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordingSession &&
        other.id == id &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.state == state &&
        other.duration == duration &&
        other.filePath == filePath &&
        other.fileSize == fileSize &&
        other.configuration == configuration &&
        other.currentAmplitude == currentAmplitude &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      startTime,
      endTime,
      state,
      duration,
      filePath,
      fileSize,
      configuration,
      currentAmplitude,
      errorMessage,
    );
  }
}