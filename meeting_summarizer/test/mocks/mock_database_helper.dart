import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart' as models;
import 'package:meeting_summarizer/core/models/database/app_settings.dart';

/// Comprehensive mock database helper for testing
///
/// Provides an in-memory database simulation that mimics the behavior
/// of the real DatabaseHelper without requiring actual SQLite database files.
class MockDatabaseHelper {
  // Mock behavior configuration
  bool _shouldFailOperations = false;
  bool _shouldFailInitialization = false;
  Duration _mockOperationDelay = const Duration(milliseconds: 10);
  bool _isInitialized = false;

  // In-memory storage
  final Map<String, Recording> _recordings = {};
  final Map<String, Transcription> _transcriptions = {};
  final Map<String, models.Summary> _summaries = {};
  final Map<String, AppSettings> _settings = {};

  // Auto-increment counters for IDs
  int _recordingIdCounter = 1;
  int _transcriptionIdCounter = 1;
  int _summaryIdCounter = 1;
  int _settingsIdCounter = 1;

  // Statistics
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;

  // Mock configuration methods

  /// Configure mock to simulate operation failures
  void setMockOperationFailure(bool shouldFail) {
    _shouldFailOperations = shouldFail;
  }

  /// Configure mock to simulate initialization failures
  void setMockInitializationFailure(bool shouldFail) {
    _shouldFailInitialization = shouldFail;
  }

  /// Set mock operation delay for testing timing scenarios
  void setMockOperationDelay(Duration delay) {
    _mockOperationDelay = delay;
  }

  /// Reset all mock state to defaults
  void resetMockState() {
    _shouldFailOperations = false;
    _shouldFailInitialization = false;
    _mockOperationDelay = const Duration(milliseconds: 10);
    _recordings.clear();
    _transcriptions.clear();
    _summaries.clear();
    _settings.clear();
    _recordingIdCounter = 1;
    _transcriptionIdCounter = 1;
    _summaryIdCounter = 1;
    _settingsIdCounter = 1;
    _totalOperations = 0;
    _successfulOperations = 0;
    _failedOperations = 0;
  }

  /// Initialize the mock database
  Future<void> initialize() async {
    if (_shouldFailInitialization) {
      throw Exception('Mock database initialization failure');
    }

    await Future.delayed(_mockOperationDelay);

    // Create default settings
    _createDefaultSettings();

    _isInitialized = true;
    log('MockDatabaseHelper: Initialized successfully');
  }

  /// Close the mock database
  Future<void> close() async {
    _isInitialized = false;
    log('MockDatabaseHelper: Closed');
  }

  // Recording operations

  /// Insert a new recording
  Future<String> insertRecording(Recording recording) async {
    await _simulateOperation();

    final id = _recordingIdCounter.toString();
    final recordingWithId = recording.copyWith(
      id: id,
      createdAt: recording.createdAt,
      updatedAt: DateTime.now(),
    );

    _recordings[id] = recordingWithId;
    _recordingIdCounter++;

    log('MockDatabaseHelper: Inserted recording $id');
    return id;
  }

  /// Update an existing recording
  Future<void> updateRecording(Recording recording) async {
    await _simulateOperation();

    if (!_recordings.containsKey(recording.id)) {
      throw Exception('Recording not found: ${recording.id}');
    }

    final updatedRecording = recording.copyWith(updatedAt: DateTime.now());
    _recordings[recording.id] = updatedRecording;

    log('MockDatabaseHelper: Updated recording ${recording.id}');
  }

  /// Get recording by ID
  Future<Recording?> getRecording(String id) async {
    await _simulateOperation();

    final recording = _recordings[id];
    log(
      'MockDatabaseHelper: Retrieved recording $id: ${recording != null ? 'found' : 'not found'}',
    );
    return recording;
  }

  /// Get all recordings with optional filters
  Future<List<Recording>> getRecordings({
    int? limit,
    int? offset,
    String? orderBy,
    bool? ascending,
    Map<String, dynamic>? where,
  }) async {
    await _simulateOperation();

    var recordings = _recordings.values.toList();

    // Apply filters
    if (where != null) {
      recordings = recordings.where((recording) {
        return _matchesWhere(recording.toJson(), where);
      }).toList();
    }

    // Apply sorting
    if (orderBy != null) {
      recordings.sort((a, b) {
        final aValue = _getFieldValue(a.toJson(), orderBy);
        final bValue = _getFieldValue(b.toJson(), orderBy);
        final comparison = _compareValues(aValue, bValue);
        return ascending == false ? -comparison : comparison;
      });
    }

    // Apply pagination
    if (offset != null) {
      recordings = recordings.skip(offset).toList();
    }
    if (limit != null) {
      recordings = recordings.take(limit).toList();
    }

    log('MockDatabaseHelper: Retrieved ${recordings.length} recordings');
    return recordings;
  }

  /// Delete recording by ID
  Future<void> deleteRecording(String id) async {
    await _simulateOperation();

    if (!_recordings.containsKey(id)) {
      throw Exception('Recording not found: $id');
    }

    _recordings.remove(id);
    // Also remove related transcriptions and summaries
    _transcriptions.removeWhere(
      (_, transcription) => transcription.recordingId == id,
    );
    // Remove summaries related to transcriptions of this recording
    final relatedTranscriptionIds = _transcriptions.values
        .where((t) => t.recordingId == id)
        .map((t) => t.id)
        .toSet();
    _summaries.removeWhere(
      (_, summary) => relatedTranscriptionIds.contains(summary.transcriptionId),
    );

    log('MockDatabaseHelper: Deleted recording $id and related data');
  }

  // Transcription operations

  /// Insert a new transcription
  Future<String> insertTranscription(Transcription transcription) async {
    await _simulateOperation();

    final id = _transcriptionIdCounter.toString();
    final transcriptionWithId = transcription.copyWith(
      id: id,
      createdAt: transcription.createdAt,
      updatedAt: DateTime.now(),
    );

    _transcriptions[id] = transcriptionWithId;
    _transcriptionIdCounter++;

    log('MockDatabaseHelper: Inserted transcription $id');
    return id;
  }

  /// Update an existing transcription
  Future<void> updateTranscription(Transcription transcription) async {
    await _simulateOperation();

    if (!_transcriptions.containsKey(transcription.id)) {
      throw Exception('Transcription not found: ${transcription.id}');
    }

    final updatedTranscription = transcription.copyWith(
      updatedAt: DateTime.now(),
    );
    _transcriptions[transcription.id] = updatedTranscription;

    log('MockDatabaseHelper: Updated transcription ${transcription.id}');
  }

  /// Get transcription by ID
  Future<Transcription?> getTranscription(String id) async {
    await _simulateOperation();

    final transcription = _transcriptions[id];
    log(
      'MockDatabaseHelper: Retrieved transcription $id: ${transcription != null ? 'found' : 'not found'}',
    );
    return transcription;
  }

  /// Get transcriptions by recording ID
  Future<List<Transcription>> getTranscriptionsByRecording(
    String recordingId,
  ) async {
    await _simulateOperation();

    final transcriptions = _transcriptions.values
        .where((transcription) => transcription.recordingId == recordingId)
        .toList();

    log(
      'MockDatabaseHelper: Retrieved ${transcriptions.length} transcriptions for recording $recordingId',
    );
    return transcriptions;
  }

  /// Delete transcription by ID
  Future<void> deleteTranscription(String id) async {
    await _simulateOperation();

    if (!_transcriptions.containsKey(id)) {
      throw Exception('Transcription not found: $id');
    }

    _transcriptions.remove(id);
    // Also remove related summaries
    _summaries.removeWhere((_, summary) => summary.transcriptionId == id);

    log('MockDatabaseHelper: Deleted transcription $id and related summaries');
  }

  // Summary operations

  /// Insert a new summary
  Future<String> insertSummary(models.Summary summary) async {
    await _simulateOperation();

    final id = _summaryIdCounter.toString();
    final summaryWithId = summary.copyWith(
      id: id,
      createdAt: summary.createdAt,
      updatedAt: DateTime.now(),
    );

    _summaries[id] = summaryWithId;
    _summaryIdCounter++;

    log('MockDatabaseHelper: Inserted summary $id');
    return id;
  }

  /// Update an existing summary
  Future<void> updateSummary(models.Summary summary) async {
    await _simulateOperation();

    if (!_summaries.containsKey(summary.id)) {
      throw Exception('Summary not found: ${summary.id}');
    }

    final updatedSummary = summary.copyWith(updatedAt: DateTime.now());
    _summaries[summary.id] = updatedSummary;

    log('MockDatabaseHelper: Updated summary ${summary.id}');
  }

  /// Get summary by ID
  Future<models.Summary?> getSummary(String id) async {
    await _simulateOperation();

    final summary = _summaries[id];
    log(
      'MockDatabaseHelper: Retrieved summary $id: ${summary != null ? 'found' : 'not found'}',
    );
    return summary;
  }

  /// Get summaries by recording ID
  Future<List<models.Summary>> getSummariesByRecording(
    String recordingId,
  ) async {
    await _simulateOperation();

    // Get transcription IDs for this recording
    final transcriptionIds = _transcriptions.values
        .where((t) => t.recordingId == recordingId)
        .map((t) => t.id)
        .toSet();

    final summaries = _summaries.values
        .where((summary) => transcriptionIds.contains(summary.transcriptionId))
        .toList();

    log(
      'MockDatabaseHelper: Retrieved ${summaries.length} summaries for recording $recordingId',
    );
    return summaries;
  }

  /// Delete summary by ID
  Future<void> deleteSummary(String id) async {
    await _simulateOperation();

    if (!_summaries.containsKey(id)) {
      throw Exception('Summary not found: $id');
    }

    _summaries.remove(id);
    log('MockDatabaseHelper: Deleted summary $id');
  }

  // Settings operations

  /// Get setting by key
  Future<AppSettings?> getSetting(String key) async {
    await _simulateOperation();

    AppSettings? setting;
    try {
      setting = _settings.values.firstWhere((setting) => setting.key == key);
    } catch (e) {
      setting = null;
    }

    log('MockDatabaseHelper: Retrieved setting $key');
    return setting;
  }

  /// Update or insert setting
  Future<void> setSetting(String key, dynamic value) async {
    await _simulateOperation();

    final existingSettingId = _settings.entries
        .where((entry) => entry.value.key == key)
        .map((entry) => entry.key)
        .cast<String?>()
        .firstWhere((id) => true, orElse: () => null);

    final now = DateTime.now();
    final setting = AppSettings(
      key: key,
      value: value.toString(),
      type: SettingType.string,
      category: SettingCategory.general,
      isSensitive: false,
      createdAt: existingSettingId != null
          ? _settings[existingSettingId]!.createdAt
          : now,
      updatedAt: now,
    );

    if (existingSettingId != null) {
      _settings[existingSettingId] = setting;
    } else {
      _settings[_settingsIdCounter.toString()] = setting;
      _settingsIdCounter++;
    }

    log('MockDatabaseHelper: Set setting $key = $value');
  }

  /// Get all settings
  Future<List<AppSettings>> getAllSettings() async {
    await _simulateOperation();

    final settings = _settings.values.toList();
    log('MockDatabaseHelper: Retrieved ${settings.length} settings');
    return settings;
  }

  // Utility operations

  /// Execute raw query (simplified mock implementation)
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    await _simulateOperation();

    // Simple mock implementation for common queries
    if (sql.toLowerCase().contains('select count(*)')) {
      if (sql.toLowerCase().contains('recordings')) {
        return [
          {'count(*)': _recordings.length},
        ];
      } else if (sql.toLowerCase().contains('transcriptions')) {
        return [
          {'count(*)': _transcriptions.length},
        ];
      } else if (sql.toLowerCase().contains('summaries')) {
        return [
          {'count(*)': _summaries.length},
        ];
      }
    }

    log('MockDatabaseHelper: Executed raw query: $sql');
    return [];
  }

  /// Execute transaction (simplified mock)
  Future<T> transaction<T>(Future<T> Function() action) async {
    await _simulateOperation();

    try {
      final result = await action();
      log('MockDatabaseHelper: Transaction completed successfully');
      return result;
    } catch (e) {
      log('MockDatabaseHelper: Transaction failed: $e');
      rethrow;
    }
  }

  // Private helper methods

  Future<void> _simulateOperation() async {
    _totalOperations++;

    if (_shouldFailOperations) {
      _failedOperations++;
      throw Exception('Mock database operation failure');
    }

    await Future.delayed(_mockOperationDelay);
    _successfulOperations++;
  }

  void _createDefaultSettings() {
    final now = DateTime.now();
    final defaultSettings = [
      {'key': 'app_version', 'value': '1.0.0'},
      {'key': 'db_version', 'value': '1'},
      {'key': 'user_preferences', 'value': '{}'},
      {'key': 'theme_mode', 'value': 'system'},
      {'key': 'auto_sync', 'value': 'true'},
    ];

    for (final setting in defaultSettings) {
      final id = _settingsIdCounter.toString();
      _settings[id] = AppSettings(
        key: setting['key']!,
        value: setting['value']!,
        type: SettingType.string,
        category: SettingCategory.general,
        isSensitive: false,
        createdAt: now,
        updatedAt: now,
      );
      _settingsIdCounter++;
    }
  }

  bool _matchesWhere(Map<String, dynamic> data, Map<String, dynamic> where) {
    for (final entry in where.entries) {
      final key = entry.key;
      final expectedValue = entry.value;
      final actualValue = data[key];

      if (actualValue != expectedValue) {
        return false;
      }
    }
    return true;
  }

  dynamic _getFieldValue(Map<String, dynamic> data, String field) {
    return data[field];
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    if (a is Comparable && b is Comparable) {
      return a.compareTo(b);
    }

    return a.toString().compareTo(b.toString());
  }

  /// Generate mock recording data for testing
  Recording generateMockRecording({
    String? id,
    String? title,
    Duration? duration,
    String? filePath,
  }) {
    final random = math.Random();
    final now = DateTime.now();

    return Recording(
      id: id ?? '',
      filename: 'recording_$_recordingIdCounter.m4a',
      filePath: filePath ?? '/mock/path/recording_$_recordingIdCounter.m4a',
      duration: (duration ?? Duration(minutes: random.nextInt(60) + 1))
          .inMilliseconds,
      fileSize: random.nextInt(10000000) + 1000000, // 1-10MB
      format: 'm4a',
      quality: 'medium',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      title: title ?? 'Mock Recording $_recordingIdCounter',
      createdAt: now.subtract(Duration(days: random.nextInt(30))),
      updatedAt: now,
    );
  }

  /// Generate mock transcription data for testing
  Transcription generateMockTranscription({
    String? id,
    String? recordingId,
    String? text,
  }) {
    final random = math.Random();
    final now = DateTime.now();

    final mockTexts = [
      'This is a sample transcription for testing purposes.',
      'The meeting discussed important business matters and future plans.',
      'We reviewed the quarterly results and identified areas for improvement.',
      'The team presented their findings and recommendations for the project.',
      'Action items were assigned to various team members for follow-up.',
    ];

    return Transcription(
      id: id ?? '',
      recordingId: recordingId ?? '1',
      text: text ?? mockTexts[random.nextInt(mockTexts.length)],
      confidence: 0.8 + random.nextDouble() * 0.2, // 0.8-1.0
      language: 'en',
      provider: 'mock-provider',
      status: TranscriptionStatus.completed,
      processingTime: random.nextInt(5000) + 1000,
      wordCount: (text?.split(' ').length ?? 50) + random.nextInt(50),
      createdAt: now.subtract(Duration(days: random.nextInt(30))),
      updatedAt: now,
    );
  }

  /// Generate mock summary data for testing
  models.Summary generateMockSummary({
    String? id,
    String? recordingId,
    String? transcriptionId,
    String? content,
  }) {
    final random = math.Random();
    final now = DateTime.now();

    final mockSummaries = [
      'This meeting focused on project updates and strategic planning.',
      'Key decisions were made regarding budget allocation and timeline.',
      'The team discussed challenges and proposed solutions for implementation.',
      'Important milestones were reviewed and next steps were outlined.',
      'Stakeholder feedback was analyzed and incorporated into the plan.',
    ];

    return models.Summary(
      id: id ?? '',
      transcriptionId: transcriptionId ?? '1',
      content: content ?? mockSummaries[random.nextInt(mockSummaries.length)],
      type: models
          .SummaryType
          .values[random.nextInt(models.SummaryType.values.length)],
      provider: 'mock-provider',
      confidence: 0.8 + random.nextDouble() * 0.2, // 0.8-1.0
      wordCount: (content?.split(' ').length ?? 30) + random.nextInt(20),
      characterCount: (content?.length ?? 150) + random.nextInt(100),
      sentiment: models
          .SentimentType
          .values[random.nextInt(models.SentimentType.values.length)],
      createdAt: now.subtract(Duration(days: random.nextInt(30))),
      updatedAt: now,
    );
  }

  /// Get current mock state for debugging
  Map<String, dynamic> getMockState() {
    return {
      'isInitialized': _isInitialized,
      'shouldFailOperations': _shouldFailOperations,
      'shouldFailInitialization': _shouldFailInitialization,
      'mockOperationDelay': _mockOperationDelay.inMilliseconds,
      'totalOperations': _totalOperations,
      'successfulOperations': _successfulOperations,
      'failedOperations': _failedOperations,
      'recordingsCount': _recordings.length,
      'transcriptionsCount': _transcriptions.length,
      'summariesCount': _summaries.length,
      'settingsCount': _settings.length,
      'nextRecordingId': _recordingIdCounter,
      'nextTranscriptionId': _transcriptionIdCounter,
      'nextSummaryId': _summaryIdCounter,
      'nextSettingsId': _settingsIdCounter,
    };
  }

  /// Populate database with test data
  Future<void> populateWithTestData({int recordingCount = 5}) async {
    for (int i = 0; i < recordingCount; i++) {
      final recording = generateMockRecording();
      final recordingId = await insertRecording(recording);

      // Add transcription for each recording
      final transcription = generateMockTranscription(recordingId: recordingId);
      final transcriptionId = await insertTranscription(transcription);

      // Add summary for each transcription
      final summary = generateMockSummary(
        recordingId: recordingId,
        transcriptionId: transcriptionId,
      );
      await insertSummary(summary);
    }

    log(
      'MockDatabaseHelper: Populated database with $recordingCount test recordings',
    );
  }
}
