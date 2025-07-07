/// Database schema definition for the Meeting Summarizer application
///
/// This file contains SQL statements for creating tables, indexes, and constraints
/// for the local SQLite database.
library;

class DatabaseSchema {
  static const String databaseName = 'meeting_summarizer.db';
  static const int databaseVersion = 1;

  /// Migration-related constants
  static const int minSupportedVersion = 1;
  static const int maxSupportedVersion = 4;

  /// Recordings table - stores audio recording metadata
  static const String createRecordingsTable = '''
    CREATE TABLE recordings (
      id TEXT PRIMARY KEY,
      filename TEXT NOT NULL,
      file_path TEXT NOT NULL,
      duration INTEGER NOT NULL, -- Duration in milliseconds
      file_size INTEGER NOT NULL, -- File size in bytes
      format TEXT NOT NULL, -- Audio format (wav, mp3, m4a)
      quality TEXT NOT NULL, -- Quality setting (high, medium, low)
      sample_rate INTEGER NOT NULL, -- Sample rate in Hz
      bit_depth INTEGER NOT NULL, -- Bit depth (8, 16, 24)
      channels INTEGER NOT NULL DEFAULT 1, -- Number of audio channels
      title TEXT, -- User-provided title
      description TEXT, -- User-provided description
      tags TEXT, -- JSON array of tags
      location TEXT, -- Recording location
      waveform_data TEXT, -- JSON array of waveform data points
      created_at INTEGER NOT NULL, -- Unix timestamp
      updated_at INTEGER NOT NULL, -- Unix timestamp
      is_deleted INTEGER NOT NULL DEFAULT 0, -- Soft delete flag
      metadata TEXT -- Additional metadata as JSON
    );
  ''';

  /// Transcriptions table - stores speech-to-text results
  static const String createTranscriptionsTable = '''
    CREATE TABLE transcriptions (
      id TEXT PRIMARY KEY,
      recording_id TEXT NOT NULL,
      text TEXT NOT NULL,
      confidence REAL NOT NULL DEFAULT 0.0, -- Confidence score 0.0-1.0
      language TEXT NOT NULL DEFAULT 'en',
      provider TEXT NOT NULL, -- Transcription service provider
      segments TEXT, -- JSON array of time-segmented transcription data
      status TEXT NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
      error_message TEXT, -- Error details if transcription failed
      processing_time INTEGER, -- Processing time in milliseconds
      word_count INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (recording_id) REFERENCES recordings (id) ON DELETE CASCADE
    );
  ''';

  /// Summaries table - stores AI-generated summaries
  static const String createSummariesTable = '''
    CREATE TABLE summaries (
      id TEXT PRIMARY KEY,
      transcription_id TEXT NOT NULL,
      content TEXT NOT NULL,
      type TEXT NOT NULL, -- brief, detailed, bullet_points, action_items
      provider TEXT NOT NULL, -- AI service provider
      model TEXT, -- AI model used for generation
      prompt TEXT, -- Prompt used for generation
      confidence REAL NOT NULL DEFAULT 0.0,
      word_count INTEGER NOT NULL DEFAULT 0,
      character_count INTEGER NOT NULL DEFAULT 0,
      key_points TEXT, -- JSON array of key points
      action_items TEXT, -- JSON array of action items
      sentiment TEXT, -- positive, negative, neutral
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (transcription_id) REFERENCES transcriptions (id) ON DELETE CASCADE
    );
  ''';

  /// Settings table - stores application configuration and user preferences
  static const String createSettingsTable = '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      type TEXT NOT NULL, -- string, int, double, bool, json
      category TEXT NOT NULL, -- audio, transcription, summary, ui, general
      description TEXT,
      is_sensitive INTEGER NOT NULL DEFAULT 0, -- Whether to store in secure storage
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  /// Search index table - for full-text search functionality
  static const String createSearchIndexTable = '''
    CREATE VIRTUAL TABLE search_index USING fts5(
      content_id,
      content_type, -- recording, transcription, summary
      title,
      content,
      tags,
      tokenize = 'porter ascii'
    );
  ''';

  /// Performance indexes for optimized queries
  static const List<String> createIndexes = [
    // Recordings indexes
    'CREATE INDEX idx_recordings_created_at ON recordings (created_at DESC);',
    'CREATE INDEX idx_recordings_duration ON recordings (duration);',
    'CREATE INDEX idx_recordings_format ON recordings (format);',
    'CREATE INDEX idx_recordings_deleted ON recordings (is_deleted);',
    'CREATE INDEX idx_recordings_title ON recordings (title);',

    // Transcriptions indexes
    'CREATE INDEX idx_transcriptions_recording_id ON transcriptions (recording_id);',
    'CREATE INDEX idx_transcriptions_status ON transcriptions (status);',
    'CREATE INDEX idx_transcriptions_language ON transcriptions (language);',
    'CREATE INDEX idx_transcriptions_confidence ON transcriptions (confidence DESC);',
    'CREATE INDEX idx_transcriptions_created_at ON transcriptions (created_at DESC);',

    // Summaries indexes
    'CREATE INDEX idx_summaries_transcription_id ON summaries (transcription_id);',
    'CREATE INDEX idx_summaries_type ON summaries (type);',
    'CREATE INDEX idx_summaries_created_at ON summaries (created_at DESC);',
    'CREATE INDEX idx_summaries_confidence ON summaries (confidence DESC);',

    // Settings indexes
    'CREATE INDEX idx_settings_category ON settings (category);',
    'CREATE INDEX idx_settings_sensitive ON settings (is_sensitive);',
  ];

  /// Database triggers for automatic timestamp updates
  static const List<String> createTriggers = [
    // Recordings triggers
    '''CREATE TRIGGER update_recordings_timestamp 
       AFTER UPDATE ON recordings 
       BEGIN 
         UPDATE recordings SET updated_at = strftime('%s', 'now') * 1000 
         WHERE id = NEW.id; 
       END;''',

    // Transcriptions triggers
    '''CREATE TRIGGER update_transcriptions_timestamp 
       AFTER UPDATE ON transcriptions 
       BEGIN 
         UPDATE transcriptions SET updated_at = strftime('%s', 'now') * 1000 
         WHERE id = NEW.id; 
       END;''',

    // Summaries triggers
    '''CREATE TRIGGER update_summaries_timestamp 
       AFTER UPDATE ON summaries 
       BEGIN 
         UPDATE summaries SET updated_at = strftime('%s', 'now') * 1000 
         WHERE id = NEW.id; 
       END;''',

    // Settings triggers
    '''CREATE TRIGGER update_settings_timestamp 
       AFTER UPDATE ON settings 
       BEGIN 
         UPDATE settings SET updated_at = strftime('%s', 'now') * 1000 
         WHERE key = NEW.key; 
       END;''',

    // Search index maintenance triggers
    '''CREATE TRIGGER populate_search_index_recordings
       AFTER INSERT ON recordings
       BEGIN
         INSERT INTO search_index (content_id, content_type, title, content, tags)
         VALUES (NEW.id, 'recording', NEW.title, NEW.description, NEW.tags);
       END;''',

    '''CREATE TRIGGER update_search_index_recordings
       AFTER UPDATE ON recordings
       BEGIN
         UPDATE search_index 
         SET title = NEW.title, content = NEW.description, tags = NEW.tags
         WHERE content_id = NEW.id AND content_type = 'recording';
       END;''',

    '''CREATE TRIGGER populate_search_index_transcriptions
       AFTER INSERT ON transcriptions
       BEGIN
         INSERT INTO search_index (content_id, content_type, title, content, tags)
         VALUES (NEW.id, 'transcription', '', NEW.text, '');
       END;''',

    '''CREATE TRIGGER update_search_index_transcriptions
       AFTER UPDATE ON transcriptions
       BEGIN
         UPDATE search_index 
         SET content = NEW.text
         WHERE content_id = NEW.id AND content_type = 'transcription';
       END;''',

    '''CREATE TRIGGER populate_search_index_summaries
       AFTER INSERT ON summaries
       BEGIN
         INSERT INTO search_index (content_id, content_type, title, content, tags)
         VALUES (NEW.id, 'summary', NEW.type, NEW.content, NEW.key_points);
       END;''',

    '''CREATE TRIGGER update_search_index_summaries
       AFTER UPDATE ON summaries
       BEGIN
         UPDATE search_index 
         SET title = NEW.type, content = NEW.content, tags = NEW.key_points
         WHERE content_id = NEW.id AND content_type = 'summary';
       END;''',
  ];

  /// Default settings to populate on first app launch
  static const List<Map<String, dynamic>> defaultSettings = [
    // Audio settings
    {
      'key': 'audio_format',
      'value': 'wav',
      'type': 'string',
      'category': 'audio',
      'description': 'Default audio recording format',
      'is_sensitive': 0,
    },
    {
      'key': 'audio_quality',
      'value': 'medium',
      'type': 'string',
      'category': 'audio',
      'description': 'Default audio recording quality',
      'is_sensitive': 0,
    },
    {
      'key': 'recording_limit',
      'value': '3600000', // 1 hour in milliseconds
      'type': 'int',
      'category': 'audio',
      'description': 'Maximum recording duration in milliseconds',
      'is_sensitive': 0,
    },
    {
      'key': 'enable_noise_reduction',
      'value': 'true',
      'type': 'bool',
      'category': 'audio',
      'description': 'Enable noise reduction during recording',
      'is_sensitive': 0,
    },
    {
      'key': 'enable_auto_gain_control',
      'value': 'true',
      'type': 'bool',
      'category': 'audio',
      'description': 'Enable automatic gain control',
      'is_sensitive': 0,
    },

    // Transcription settings
    {
      'key': 'transcription_language',
      'value': 'en',
      'type': 'string',
      'category': 'transcription',
      'description': 'Default language for transcription',
      'is_sensitive': 0,
    },
    {
      'key': 'transcription_provider',
      'value': 'local',
      'type': 'string',
      'category': 'transcription',
      'description': 'Transcription service provider',
      'is_sensitive': 0,
    },
    {
      'key': 'auto_transcribe',
      'value': 'false',
      'type': 'bool',
      'category': 'transcription',
      'description': 'Automatically transcribe recordings',
      'is_sensitive': 0,
    },

    // Summary settings
    {
      'key': 'summary_type',
      'value': 'brief',
      'type': 'string',
      'category': 'summary',
      'description': 'Default summary type',
      'is_sensitive': 0,
    },
    {
      'key': 'auto_summarize',
      'value': 'false',
      'type': 'bool',
      'category': 'summary',
      'description': 'Automatically generate summaries',
      'is_sensitive': 0,
    },

    // UI settings
    {
      'key': 'theme_mode',
      'value': 'system',
      'type': 'string',
      'category': 'ui',
      'description': 'Application theme mode',
      'is_sensitive': 0,
    },
    {
      'key': 'waveform_enabled',
      'value': 'true',
      'type': 'bool',
      'category': 'ui',
      'description': 'Show waveform during recording',
      'is_sensitive': 0,
    },

    // General settings
    {
      'key': 'app_version',
      'value': '1.0.0',
      'type': 'string',
      'category': 'general',
      'description': 'Application version',
      'is_sensitive': 0,
    },
    {
      'key': 'first_launch',
      'value': 'true',
      'type': 'bool',
      'category': 'general',
      'description': 'Whether this is the first app launch',
      'is_sensitive': 0,
    },
  ];

  /// Get all table creation statements
  static List<String> get createTables => [
    createRecordingsTable,
    createTranscriptionsTable,
    createSummariesTable,
    createSettingsTable,
    createSearchIndexTable,
  ];

  /// Get all schema statements in the correct order
  static List<String> get allStatements => [
    ...createTables,
    ...createIndexes,
    ...createTriggers,
  ];
}
