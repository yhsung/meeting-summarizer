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
│   │   │   │   └── user_rights/
│   │   │   │       ├── user_profile.dart      # Comprehensive user profile with roles and guardian relationships
│   │   │   │       ├── user_role.dart         # Hierarchical role system with permission inheritance
│   │   │   │       ├── access_permission.dart # Fine-grained permission model with conditions and expiration
│   │   │   │       ├── rights_delegation.dart # Rights delegation between users with approval workflows
│   │   │   │       ├── access_audit_log.dart  # Comprehensive audit trail with risk assessment
│   │   │   │       └── user_rights_service_event.dart # Event system for real-time user rights monitoring
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
│   │   │       │   ├── icloud_provider.dart               # iCloud Drive integration with macOS support
│   │   │       │   ├── google_drive_provider.dart         # Google Drive API v3 integration
│   │   │       │   ├── onedrive_provider.dart             # Microsoft OneDrive Graph API integration
│   │   │       │   └── dropbox_provider.dart              # Dropbox API v2 integration
│   │   │       ├── transcription_service_factory.dart     # Transcription service factory with web platform exclusions
│   │   │       ├── local_whisper_service.dart             # Local Whisper transcription (mobile/desktop only)
│   │   │       ├── local_whisper_service_stub.dart        # Web platform stub for local Whisper
│   │   │       ├── enhanced_user_rights_service.dart      # Comprehensive user rights management with RBAC and GDPR integration
│   │   │       ├── permission_inheritance_manager.dart    # Hierarchical permission inheritance with role-based access control
│   │   │       └── fine_grained_access_manager.dart       # Fine-grained access validation with conditions and audit logging
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
│   │   │       └── cloud_encryption_service_test.dart   # Cloud encryption service comprehensive tests (15 test groups)
│   │   ├── features/
│   │   │   └── audio_recording/
│   │   │       ├── audio_recording_service_test.dart
│   │   │       └── platform/
│   │   │           └── audio_recording_platform_test.dart
│   │   └── widget_test.dart            # Basic widget tests
│   ├── android/                        # Android platform configuration
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

### Removed Dependencies
- **syncfusion_flutter_pdfviewer**: Removed due to Flutter v1 embedding conflicts and lack of usage