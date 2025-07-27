# Project Structure Documentation

## Key Files & Project Structure

### Core Files

- `.taskmaster/tasks/tasks.json` - Main task data file (auto-managed)
- `.taskmaster/config.json` - AI model configuration (use `task-master models` to modify)
- `.taskmaster/docs/prd.txt` - Product Requirements Document for parsing
- `.taskmaster/tasks/*.txt` - Individual task files (auto-generated from tasks.json)
- `.env` - API keys for CLI usage

### Claude Code Integration Files

- `CLAUDE.md` - Auto-loaded context for Claude Code (this file)
- `.claude/settings.json` - Claude Code tool allowlist and preferences
- `.claude/commands/` - Custom slash commands for repeated workflows
- `.mcp.json` - MCP server configuration (project-specific)

### Directory Structure

```
project/                   # absolute path /Volumes/Samsung970EVOPlus/dev-projects/meeting-summarizer
├── .taskmaster/
│   ├── tasks/              # Task files directory
│   │   ├── tasks.json      # Main task database
│   │   ├── task-1.md      # Individual task files
│   │   └── task-2.md
│   ├── docs/              # Documentation directory
│   │   ├── prd.txt        # Product requirements
│   ├── reports/           # Analysis reports directory
│   │   └── task-complexity-report.json
│   ├── templates/         # Template files
│   │   └── example_prd.txt  # Example PRD template
│   └── config.json        # AI models & settings
├── .claude/
│   ├── settings.json      # Claude Code configuration
│   └── commands/         # Custom slash commands
├── .env                  # API keys
├── .mcp.json            # MCP configuration
├── docs/                 # Project documentation and architecture
│   ├── architecture.md       # Software architecture diagrams and explanation
│   └── project-structure.md  # This file - detailed project structure
├── meeting_summarizer/   # Flutter app directory
│   ├── lib/
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── database_helper.dart           # Main database operations with migration support
│   │   │   │   ├── database_schema.dart           # Database schema definitions and versioning
│   │   │   │   ├── database_migrations.dart       # Database migration system with backup/restore
│   │   │   │   ├── file_metadata_dao.dart         # SQLite data access for file metadata with FTS5 search
│   │   │   │   └── README.md                      # Database architecture documentation
│   │   │   ├── dao/
│   │   │   │   └── user_rights_dao.dart           # User rights database operations with comprehensive CRUD and query support
│   │   │   ├── interfaces/
│   │   │   │   ├── storage_organization_interface.dart # Storage organization service interface
│   │   │   │   ├── export_service_interface.dart      # Export service interface with multi-format support
│   │   │   │   └── cloud_sync_interface.dart          # Cloud synchronization service interface with incremental sync
│   │   │   ├── enums/
│   │   │   │   ├── audio_format.dart      # Audio format definitions with compression ratios
│   │   │   │   ├── audio_quality.dart     # Quality levels with detailed properties
│   │   │   │   ├── recording_state.dart   # Recording state management
│   │   │   │   ├── summary_type.dart      # AI summary type definitions (brief, detailed, executive, etc.)
│   │   │   │   ├── export_format.dart     # Export format definitions (JSON, CSV, XML, PDF, HTML, ZIP, TAR)
│   │   │   │   ├── compression_level.dart # Compression level options for export operations
│   │   │   │   └── user_rights_enums.dart # User rights system enums (status, actions, roles, permissions)
│   │   │   ├── models/
│   │   │   │   ├── audio_configuration.dart  # Enhanced audio config with serialization
│   │   │   │   ├── recording_session.dart     # Recording session management
│   │   │   │   ├── summarization_configuration.dart # AI summarization configuration with 200+ lines
│   │   │   │   ├── summarization_result.dart         # Comprehensive summarization results with metadata
│   │   │   │   ├── database/
│   │   │   │   │   ├── recording.dart         # Recording model with JSON serialization and encryption support
│   │   │   │   │   ├── transcription.dart     # Transcription model with status management
│   │   │   │   │   ├── summary.dart           # Summary model with sentiment analysis
│   │   │   │   │   └── app_settings.dart      # Application settings model with categories
│   │   │   │   ├── export/
│   │   │   │   │   ├── export_options.dart    # Export configuration with format-specific options
│   │   │   │   │   └── export_result.dart     # Export operation results with metadata and progress
│   │   │   │   ├── storage/
│   │   │   │   │   ├── file_category.dart     # File categorization system with 8 categories
│   │   │   │   │   ├── file_metadata.dart     # Comprehensive file metadata with JSON serialization
│   │   │   │   │   └── storage_stats.dart     # Storage analytics and statistics
│   │   │   │   ├── cloud_sync/
│   │   │   │   │   ├── cloud_provider.dart    # Cloud provider enums and configuration
│   │   │   │   │   ├── sync_status.dart       # Synchronization status tracking
│   │   │   │   │   ├── sync_conflict.dart     # Conflict detection and resolution models
│   │   │   │   │   ├── sync_operation.dart    # Sync operation tracking with progress
│   │   │   │   │   ├── file_change.dart       # File change detection with delta sync support
│   │   │   │   │   └── file_version.dart      # File versioning and history models
│   │   │   │   ├── user_rights/
│   │   │   │   │   ├── user_profile.dart      # Comprehensive user profile with roles and guardian relationships
│   │   │   │   │   ├── user_role.dart         # Hierarchical role system with permission inheritance
│   │   │   │   │   ├── access_permission.dart # Fine-grained permission model with conditions and expiration
│   │   │   │   │   ├── rights_delegation.dart # Rights delegation between users with approval workflows
│   │   │   │   │   ├── access_audit_log.dart  # Comprehensive audit trail with risk assessment
│   │   │   │   │   └── user_rights_service_event.dart # Event system for real-time user rights monitoring
│   │   │   │   ├── help/
│   │   │   │   │   ├── help_article.dart      # Help article model with categories, tags, and metadata
│   │   │   │   │   ├── faq_item.dart          # FAQ item model with voting and view tracking
│   │   │   │   │   ├── contextual_help.dart   # Context-aware tooltip and guided help model
│   │   │   │   │   └── help_tour.dart         # Multi-step guided tour model with navigation
│   │   │   │   └── feedback/
│   │   │   │       ├── feedback_item.dart     # Feedback data model with type categorization
│   │   │   │       └── feedback_analytics.dart # Analytics model for feedback insights
│   │   │   └── services/
│   │   │       ├── audio_service_interface.dart           # Service interface definition
│   │   │       ├── audio_format_manager.dart              # Platform-aware format selection
│   │   │       ├── codec_manager.dart                     # Codec selection and management
│   │   │       ├── file_size_optimizer.dart               # File size optimization strategies
│   │   │       ├── audio_enhancement_service_interface.dart # Audio enhancement interface with noise reduction, echo cancellation, AGC
│   │   │       ├── audio_enhancement_service.dart         # Audio enhancement implementation using FFT-based processing
│   │   │       ├── encryption_service.dart                # Enhanced AES-256-GCM encryption with PBKDF2, key rotation, and SecureKeyManager
│   │   │       ├── cloud_encryption_service.dart          # Enhanced cloud-specific encryption with file/chunk/metadata encryption
│   │   │       ├── encrypted_database_service.dart        # Database service with transparent encryption/decryption
│   │   │       ├── ai_summarization_service_interface.dart # AI summarization service interface
│   │   │       ├── base_ai_summarization_service.dart     # Base implementation with common functionality
│   │   │       ├── mock_ai_summarization_service.dart     # Mock implementation for testing and development
│   │   │       ├── summary_type_processors.dart           # Factory pattern for summary type processors
│   │   │       ├── specialized_summary_processors.dart    # Executive and action item processors
│   │   │       ├── topical_summary_processor.dart         # Topic-based summary formatting
│   │   │       ├── meeting_notes_processor.dart           # Professional meeting notes with timestamp processing
│   │   │       ├── prompt_template_service.dart           # Advanced prompt engineering with template system
│   │   │       ├── topic_extraction_service.dart          # AI-powered topic analysis and keyword identification
│   │   │       ├── quality_scoring_service.dart           # Quality assessment with feedback integration (1,146 lines)
│   │   │       ├── storage_organization_service.dart      # Basic file organization with JSON metadata cache
│   │   │       ├── enhanced_storage_organization_service.dart # Advanced storage organization with SQLite integration
│   │   │       ├── file_categorization_service.dart       # Smart file categorization and auto-tagging
│   │   │       ├── advanced_search_service.dart           # Comprehensive search with ranking and suggestions
│   │   │       ├── export_service.dart                    # Multi-format export system with batch processing
│   │   │       ├── cloud_sync_service.dart                # Main cloud synchronization service with incremental sync support
│   │   │       ├── incremental_transfer_manager.dart      # Bandwidth-optimized transfer coordination with resumption
│   │   │       ├── change_tracking_service.dart           # File modification detection with SHA-256 checksums
│   │   │       ├── delta_sync_service.dart                # Delta synchronization for changed file portions only
│   │   │       ├── file_chunking_service.dart             # Adaptive file chunking with integrity verification
│   │   │       ├── conflict_detection_service.dart        # Multi-provider conflict detection and analysis
│   │   │       ├── conflict_resolution_service.dart       # Automated and manual conflict resolution strategies
│   │   │       ├── version_management_service.dart        # File versioning and history management
│   │   │       ├── cloud_providers/
│   │   │       │   ├── cloud_provider_factory.dart        # Provider factory with platform-specific implementations
│   │   │       │   ├── cloud_provider_interface.dart      # Standard interface for all cloud providers
│   │   │       │   ├── icloud_provider.dart               # Complete CloudKit integration with container validation, authentication monitoring, document picker (1,411 lines)
│   │   │       │   ├── google_drive_provider.dart         # Google Drive API v3 integration
│   │   │       │   ├── onedrive_provider.dart             # Complete Microsoft Graph API v1.0 integration with OAuth2, resumable uploads, delta sync (1,264 lines)
│   │   │       │   └── dropbox_provider.dart              # Complete Dropbox API v2 integration with OAuth2, chunked uploads, Paper integration (1,472 lines)
│   │   │       ├── transcription_service_factory.dart     # Transcription service factory with web platform exclusions
│   │   │       ├── local_whisper_service.dart             # Local Whisper transcription (mobile/desktop only)
│   │   │       ├── local_whisper_service_stub.dart        # Web platform stub for local Whisper
│   │   │       ├── android_platform_service.dart         # Complete Android platform services integration with Auto, Quick Settings, Widgets, Assistant, Work Profile, Foreground Service (858 lines)
│   │   │       ├── ios_platform_service.dart             # Complete iOS platform services integration with Siri, Apple Watch, CallKit, Widgets, Spotlight, Files, Handoff (959 lines)
│   │   │       ├── platform_services/
│   │   │       │   ├── platform_service_interface.dart    # Platform service interfaces for cross-platform functionality
│   │   │       │   ├── android_auto_service.dart          # Android Auto integration with Media3 session management (900+ lines)
│   │   │       │   ├── apple_watch_service.dart          # Apple Watch companion app service
│   │   │       │   ├── callkit_service.dart               # iOS CallKit integration for call-like recording sessions
│   │   │       │   ├── enhanced_notifications_service.dart # Platform-specific notification enhancements
│   │   │       │   ├── macos_menubar_service.dart         # macOS menu bar integration
│   │   │       │   ├── performance_optimization_service.dart # Platform-specific performance optimizations
│   │   │       │   ├── siri_shortcuts_service.dart       # iOS Siri Shortcuts integration
│   │   │       │   └── windows_system_tray_service.dart   # Windows system tray service
│   │   │       ├── enhanced_user_rights_service.dart      # Comprehensive user rights management with RBAC and GDPR integration
│   │   │       ├── permission_inheritance_manager.dart    # Hierarchical permission inheritance with role-based access control
│   │   │       ├── fine_grained_access_manager.dart       # Fine-grained access validation with conditions and audit logging
│   │   │       ├── settings_service.dart                  # Comprehensive settings management with SharedPreferences persistence
│   │   │       ├── settings_backup_service.dart           # Settings backup and migration with cloud sync and encryption
│   │   │       ├── help_service.dart                      # In-app help system with articles, FAQ, contextual help and tours
│   │   │       └── feedback_service.dart                  # User feedback collection with smart rating prompts and analytics
│   │   ├── features/
│   │   │   ├── audio_recording/
│   │   │   │   ├── data/
│   │   │   │   │   ├── audio_recording_service.dart  # Main audio recording service
│   │   │   │   │   └── platform/
│   │   │   │   │       ├── audio_recording_platform.dart   # Platform abstraction
│   │   │   │   │       └── record_platform_adapter.dart    # Record package adapter
│   │   │   │   ├── domain/             # Domain layer (to be implemented)
│   │   │   │   └── presentation/       # UI layer (to be implemented)
│   │   │   ├── onboarding/
│   │   │   │   ├── data/
│   │   │   │   │   └── services/
│   │   │   │   │       └── onboarding_service.dart          # User onboarding state management using SharedPreferences
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── onboarding_screen.dart           # Interactive tutorial system with introduction_screen
│   │   │   │       └── widgets/
│   │   │   │           ├── permission_setup_widget.dart     # Permission request handling with real-time status tracking
│   │   │   │           ├── cloud_setup_widget.dart          # Cloud storage provider selection (iCloud, Google Drive, OneDrive, Dropbox)
│   │   │   │           └── audio_test_widget.dart           # Audio quality testing with volume visualization and recording simulation
│   │   │   ├── search/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── search_screen.dart              # Main search interface with tabs
│   │   │   │       └── widgets/
│   │   │   │           ├── advanced_search_widget.dart     # Advanced search form with filters
│   │   │   │           └── search_results_widget.dart      # Search results display with ranking
│   │   │   ├── transcription/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── transcription_screen.dart       # Transcription interface with file picker and custom tab bar
│   │   │   │       └── widgets/
│   │   │   │           ├── transcription_controls.dart     # Audio transcription controls
│   │   │   │           ├── transcription_viewer.dart       # Transcription display component
│   │   │   │           ├── transcription_progress.dart     # Progress tracking widget
│   │   │   │           ├── speaker_timeline.dart           # Speaker diarization timeline
│   │   │   │           └── transcription_settings.dart     # Transcription configuration
│   │   │   ├── user_rights/
│   │   │   │   └── widgets/
│   │   │   │       └── user_rights_dashboard.dart          # Comprehensive user rights dashboard with permissions, history, delegations
│   │   │   ├── settings/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── settings_screen.dart            # Comprehensive settings management screen with tabbed interface
│   │   │   │       └── widgets/
│   │   │   │           └── settings_widgets.dart           # Reusable settings widgets for different data types
│   │   │   ├── help/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   ├── help_screen.dart                # Main help interface with articles, FAQ, and search
│   │   │   │       │   └── help_article_screen.dart        # Detailed article view with sharing and voting
│   │   │   │       └── widgets/
│   │   │   │           ├── help_search_bar.dart            # Search with autocomplete suggestions
│   │   │   │           ├── help_category_grid.dart         # Visual category browser
│   │   │   │           ├── help_article_list.dart          # Article display with metadata
│   │   │   │           ├── help_faq_list.dart              # Expandable FAQ with voting
│   │   │   │           ├── help_quick_actions.dart         # Action buttons for common tasks
│   │   │   │           └── contextual_help_tooltip.dart    # Advanced tooltip system with animations
│   │   │   ├── feedback/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── feedback_screen.dart            # Feedback analytics dashboard with insights
│   │   │   │       └── widgets/
│   │   │   │           ├── rating_dialog.dart              # Smart rating dialog with usage-based timing
│   │   │   │           ├── feedback_form.dart              # Comprehensive feedback submission form
│   │   │   │           └── feedback_integration_widget.dart # App-wide feedback integration wrapper
│   │   │   └── summary/
│   │   │       └── presentation/
│   │   │           ├── screens/
│   │   │           │   └── summary_screen.dart              # AI summary interface
│   │   │           └── widgets/
│   │   │               ├── summary_generator.dart           # Summary generation controls
│   │   │               ├── summary_viewer.dart              # Summary display component
│   │   │               ├── summary_controls.dart            # Summary interaction controls
│   │   │               ├── summary_type_selector.dart       # Summary type selection
│   │   │               └── action_items_list.dart           # Action items display
│   │   │   └── sync/
│   │   │       └── presentation/
│   │   │           └── widgets/
│   │   │               └── conflict_resolution_dialog.dart      # Conflict resolution UI for manual resolution
│   │   └── main.dart                   # Flutter app entry point
│   ├── test/
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── database_helper_migrations_test.dart  # Database helper migration tests
│   │   │   │   └── database_migrations_test.dart         # Migration system tests
│   │   │   ├── models/
│   │   │   │   └── storage/
│   │   │   │       ├── file_metadata_test.dart           # File metadata model tests
│   │   │   │       └── storage_stats_test.dart           # Storage statistics tests
│   │   │   └── services/
│   │   │       ├── audio_format_manager_test.dart       # Format manager tests
│   │   │       ├── codec_manager_test.dart               # Codec manager tests
│   │   │       ├── file_size_optimizer_test.dart        # Optimizer tests
│   │   │       ├── audio_enhancement_service_test.dart   # Audio enhancement comprehensive tests
│   │   │       ├── encryption_service_test.dart          # Encryption service tests with key management
│   │   │       ├── encrypted_database_service_test.dart  # Encrypted database service integration tests
│   │   │       ├── quality_scoring_service_test.dart     # Quality scoring comprehensive tests (15 test cases)
│   │   │       ├── file_categorization_service_test.dart # File categorization and tagging tests
│   │   │       ├── advanced_search_service_test.dart     # Comprehensive search functionality tests (28 test cases)
│   │   │       ├── export_service_test.dart              # Multi-format export system tests (20 test cases)
│   │   │       ├── cloud_encryption_service_test.dart   # Cloud encryption service comprehensive tests (15 test groups)
│   │   │       ├── cloud_providers/
│   │   │       │   ├── icloud_provider_test.dart         # CloudKit integration comprehensive tests with authentication and file operations
│   │   │       │   ├── onedrive_provider_test.dart       # Microsoft Graph API integration tests with OAuth2 and delta sync
│   │   │       │   └── dropbox_provider_test.dart        # Dropbox API v2 integration tests with chunked uploads and Paper API
│   │   │       ├── android_platform_service_test.dart    # Android platform services integration tests with platform channels
│   │   │       ├── ios_platform_service_test.dart        # iOS platform services integration tests with comprehensive coverage (823 lines, 37 test cases)
│   │   │       ├── settings_service_test.dart            # Settings service comprehensive tests (34 test cases)
│   │   │       ├── settings_backup_service_test.dart     # Settings backup and migration service tests
│   │   │       └── help_service_test.dart                # Help system service tests with caching and analytics
│   │   ├── features/
│   │   │   ├── audio_recording/
│   │   │   │   ├── audio_recording_service_test.dart
│   │   │   │   └── platform/
│   │   │   │       └── audio_recording_platform_test.dart
│   │   │   └── feedback/
│   │   │       └── feedback_integration_test.dart        # Comprehensive feedback system integration tests
│   │   └── widget_test.dart            # Basic widget tests
│   ├── android/                        # Android platform configuration with comprehensive native integrations
│   │   ├── app/src/main/
│   │   │   ├── AndroidManifest.xml     # Enhanced with 25+ permissions for platform services
│   │   │   └── java/com/yhsung/meeting_summarizer/
│   │   │       ├── AndroidPlatformHandler.java     # Main platform channel handler for method calls
│   │   │       ├── QuickSettingsTileHandler.java   # Quick Settings tile implementation
│   │   │       ├── GoogleAssistantHandler.java     # Google Assistant integration handler
│   │   │       ├── WorkProfileHandler.java         # Work profile support and enterprise features
│   │   │       ├── ForegroundServiceHandler.java   # Background recording service implementation
│   │   │       └── HomeWidgetHandler.java          # Home screen widget functionality
│   ├── ios/                           # iOS platform configuration
│   ├── macos/                         # macOS platform configuration
│   ├── web/                           # Web platform configuration
│   ├── windows/                       # Windows platform configuration
│   ├── pubspec.yaml                   # Flutter dependencies (optimized, removed unused syncfusion_flutter_pdfviewer)
│   └── analysis_options.yaml         # Dart analysis configuration
└── CLAUDE.md                         # Main Claude Code context file
```

## Architecture Overview

### Core Layer (`lib/core/`)

The core layer contains shared components that can be used across the entire application:

- **Database**: SQLite database management with migration support and encryption
- **Enums**: Type-safe definitions for audio formats, quality levels, states, and summary types
- **Models**: Data classes for configuration, session management, database entities, and AI summarization
- **Services**: Business logic, platform abstractions, encryption services, and AI summarization engine

### Features Layer (`lib/features/`)

Organized by feature domains following clean architecture principles:

- **Data Layer**: Repository implementations, data sources, and platform-specific code
- **Domain Layer**: Business logic, entities, and use cases (to be implemented)
- **Presentation Layer**: UI components, state management, and user interactions (to be implemented)

### Test Structure (`test/`)

Mirrors the main source structure with comprehensive test coverage:

- **Unit Tests**: Individual component testing
- **Integration Tests**: Service interaction testing
- **Widget Tests**: UI component testing

### Database & Encryption Architecture

The application features a comprehensive database system with optional encryption:

#### Database Layer
- **SQLite Backend**: Cross-platform local database storage
- **Migration System**: Version-controlled schema upgrades with backup/restore
- **Transaction Support**: ACID compliance for data integrity
- **Search Integration**: Full-text search capabilities with FTS5

#### Encryption Layer
- **AES-256-GCM**: Production-grade encryption using PointyCastle cryptographic library
- **Key Management**: Advanced SecureKeyManager with PBKDF2 key derivation, key rotation, backup/recovery workflows
- **Transparent Operation**: Automatic encryption/decryption at the service layer
- **Field-Level Encryption**: Selective encryption of sensitive fields (descriptions, transcriptions)

#### Data Models
- **Recording**: Audio file metadata with waveform data and encryption support
- **Transcription**: Speech-to-text results with confidence scores and status tracking
- **Summary**: AI-generated summaries with sentiment analysis and version control
- **Settings**: Application configuration with categorization and sensitivity flags

### AI Summarization Engine Architecture

The application features a comprehensive AI summarization system implemented in Task 5:

#### Core Components
- **Service Interface**: Abstract interface defining summarization capabilities and service contracts
- **Base Implementation**: Common functionality shared across all AI providers
- **Mock Service**: Testing and development implementation with realistic data generation
- **Factory Pattern**: Dynamic processor selection based on summary type requirements

#### Specialized Processors
- **Summary Type Processors**: Factory-managed processors for different summary formats
- **Executive Summary**: High-level business summaries with decision focus
- **Meeting Notes**: Professional formatted notes with timestamp integration
- **Action Items**: Structured task extraction with assignments and deadlines
- **Topical Summary**: Topic-based organization with keyword analysis

#### Advanced Features
- **Prompt Engineering**: Template-based prompt generation with context injection
- **Topic Extraction**: AI-powered topic analysis with relevance scoring
- **Quality Scoring**: Multi-dimensional assessment with feedback integration
- **Metadata Processing**: Comprehensive result tracking with confidence scores

#### Quality Assessment System
- **Multi-dimensional Scoring**: Accuracy, completeness, clarity, relevance, structure
- **AI-powered Evaluation**: Advanced assessment with fallback mechanisms
- **User Feedback Integration**: Rating collection with sentiment analysis
- **Reference Comparison**: Benchmarking against reference summaries
- **Improvement Recommendations**: Automated suggestions based on quality analysis

### Export System Architecture

The application features a comprehensive multi-format export system implemented in Task 7.3:

#### Core Components
- **Export Service Interface**: Abstract interface defining export capabilities across multiple formats
- **Factory Pattern**: Dynamic format exporter selection with extensible architecture
- **Configuration System**: Comprehensive export options with format-specific settings
- **Progress Tracking**: Real-time export progress with cancellation support

#### Export Formats
- **JSON**: Structured data export with metadata and configuration options
- **CSV**: Tabular format optimized for spreadsheet analysis with proper escaping
- **XML**: Structured markup for interoperability with external systems
- **HTML**: Web-viewable reports with styling and formatted presentation
- **PDF**: Document format for professional reports (placeholder implementation)
- **ZIP/TAR**: Archive formats for file bundling with compression (placeholder implementation)

#### Advanced Features
- **Batch Operations**: Single file, multiple files, category-based, and date range exports
- **Validation System**: Pre-export validation with warnings and recommendations
- **Size Estimation**: Export size prediction with compression ratio calculations
- **Filtering Support**: Tag-based, category-based, and date range filtering
- **Metadata Control**: Configurable inclusion of file content, metadata, and system information

### Platform Support

The project supports multiple platforms through Flutter's cross-platform architecture:

- **Android**: Mobile application
- **iOS**: Mobile application
- **macOS**: Desktop application
- **Web**: Browser-based application
- **Windows**: Desktop application

## Development Workflow

1. **Task Management**: Use Task Master for planning and tracking development tasks
2. **Code Quality**: Maintain high standards with automated testing and analysis
3. **Documentation**: Keep this structure updated as the project evolves
4. **Integration**: Leverage Claude Code for AI-assisted development

## File Naming Conventions

- **Dart Files**: `snake_case.dart`
- **Test Files**: `component_name_test.dart`
- **Interface Files**: `interface_name_interface.dart`
- **Implementation Files**: Descriptive names indicating purpose

## Dependencies Management

### Core Dependencies
- **file_picker**: Cross-platform file selection for audio files
- **flutter**: Framework for cross-platform development
- **Essential packages**: Audio processing, database, encryption, UI components

### Dev Dependencies
- **flutter_test**: Testing framework
- **flutter_lints**: Code quality and style enforcement
- **build_runner**: Code generation for serialization

### Platform Dependencies
- **Android**: Gradle-based build system with NDK support
- **iOS/macOS**: CocoaPods dependency management
- **Web**: Dart2JS compilation for browser compatibility
- **Windows**: CMake-based native compilation

### Cloud Provider Implementation Architecture

The application features comprehensive cloud storage integration with four major providers:

#### iCloud Storage Provider (Task #1)
- **CloudKit Integration**: Native macOS/iOS CloudKit framework integration (1,411 lines)
- **Container Management**: Multi-container support with validation and automatic creation
- **Authentication**: Real-time authentication monitoring with automatic token refresh
- **Document Picker**: Native iOS document picker integration for file selection
- **Background Sync**: CKDatabase operations with record zone management
- **File Operations**: Upload, download, delete with progress tracking and error handling
- **Conflict Resolution**: Built-in CloudKit conflict detection and resolution strategies

#### OneDrive Storage Provider (Task #2)
- **Microsoft Graph API v1.0**: Complete integration with personal and business accounts (1,264 lines)
- **OAuth2 Authentication**: MSAL integration with automatic token refresh and scope management
- **Resumable Uploads**: Chunked upload sessions for large files with pause/resume capability
- **Delta Sync**: Incremental synchronization using Graph API delta queries for bandwidth optimization
- **Shared Links**: Public and private sharing with expiration and permission management
- **File Versioning**: Version history tracking with restore capabilities
- **Enterprise Features**: Work/School account support with conditional access policies

#### Dropbox Storage Provider (Task #3)
- **Dropbox API v2**: Complete integration with OAuth2 and advanced features (1,472 lines)
- **OAuth2 Flow**: PKCE-enhanced authorization with refresh token management
- **Chunked Uploads**: Large file upload with automatic chunking and integrity verification
- **Paper Integration**: Dropbox Paper document creation for collaborative transcripts
- **Shared Links**: Advanced sharing with download/preview permissions and expiration
- **Rate Limiting**: Intelligent request throttling with exponential backoff
- **Team Features**: Business account support with team folder access and admin controls

#### Platform Services Integration Architecture

The application features comprehensive platform integration for both Android and iOS:

#### Android Platform Services (Task #5)
- **Android Auto Integration**: Complete Media3 session management with vehicle UI (858 lines)
- **Quick Settings Tile**: One-tap recording access from notification panel
- **Home Screen Widgets**: Multiple widget sizes with real-time status updates
- **Google Assistant**: Voice command integration with custom actions and feedback
- **Work Profile Support**: Enterprise security with policy enforcement and audit logging
- **Foreground Service**: Background recording with persistent notification and controls
- **Platform Channels**: Native Java handlers for seamless Flutter-Android communication

#### iOS Platform Services (Task #4)
- **Siri Shortcuts Integration**: Voice-activated recording controls with NSUserActivity registration (959 lines)
- **Apple Watch Companion**: WatchConnectivity framework with real-time sync and remote control
- **CallKit Framework**: Automatic call recording with provider configuration and call state monitoring
- **iOS Home Screen Widgets**: WidgetKit integration with dynamic content and timeline management
- **Spotlight Search**: Core Spotlight indexing with search query handling and metadata management
- **Files App Integration**: Native Files app support with import/export and document picker
- **NSUserActivity Handoff**: Cross-device continuity with state preservation and activity management
- **Platform Channels**: Native iOS method channels for seamless Flutter-iOS communication

### Removed Dependencies
- **syncfusion_flutter_pdfviewer**: Removed due to Flutter v1 embedding conflicts and lack of usage