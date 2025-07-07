enum RecordingState {
  idle,
  initializing,
  recording,
  paused,
  stopping,
  processing,
  stopped,
  error;

  bool get isActive => this == RecordingState.recording;
  bool get isPaused => this == RecordingState.paused;
  bool get isStopped =>
      this == RecordingState.stopped || this == RecordingState.idle;
  bool get canRecord =>
      this == RecordingState.idle || this == RecordingState.stopped;
  bool get canPause => this == RecordingState.recording;
  bool get canResume => this == RecordingState.paused;
  bool get canStop =>
      this == RecordingState.recording || this == RecordingState.paused;
}
