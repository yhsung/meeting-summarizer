/// Mock service generators for unit testing
/// This file contains mock annotations that will be used by build_runner
/// to generate mock implementations of core services.
///
/// Additionally, it provides access to comprehensive mock implementations
/// for testing without requiring mockito code generation.
library;

import 'package:mockito/annotations.dart';

// Import existing core services that need mocking
import 'package:meeting_summarizer/core/services/cloud_sync_service.dart';
import 'package:meeting_summarizer/core/services/google_speech_service.dart';
import 'package:meeting_summarizer/core/services/ai_summarization_service.dart';
import 'package:meeting_summarizer/core/services/openai_whisper_service.dart';
import 'package:meeting_summarizer/core/services/local_whisper_service.dart';
import 'package:meeting_summarizer/core/services/encrypted_database_service.dart';
import 'package:meeting_summarizer/core/services/audio_enhancement_service.dart';
import 'package:meeting_summarizer/core/services/permission_service.dart';
import 'package:meeting_summarizer/core/services/export_service.dart';
import 'package:meeting_summarizer/core/services/theme_service.dart';
import 'package:meeting_summarizer/core/services/advanced_search_service.dart';
import 'package:meeting_summarizer/core/services/batch_processing_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/enhanced_notifications_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/siri_shortcuts_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/android_auto_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/performance_optimization_service.dart';
import 'package:meeting_summarizer/core/services/settings_service.dart';

// Import comprehensive mock implementations
// Note: These are commented out as they're not directly used in this file
// import 'mock_audio_recording_service.dart';
// import 'mock_whisper_api_service.dart';
// import 'mock_database_helper.dart';
// import 'mock_data_generators.dart';
// import 'test_fixtures.dart';

// Generate mocks for core services
@GenerateMocks([
  // Transcription Services
  GoogleSpeechService,
  OpenAIWhisperService,
  LocalWhisperService,

  // Data Services
  EncryptedDatabaseService,
  CloudSyncService,

  // AI Services
  AISummarizationService,

  // Audio Services
  AudioEnhancementService,

  // System Services
  PermissionService,
  ExportService,
  ThemeService,
  AdvancedSearchService,
  BatchProcessingService,
  SettingsService,

  // Platform Services
  EnhancedNotificationsService,
  SiriShortcutsService,
  AndroidAutoService,
  PerformanceOptimizationService,
])
void main() {}
