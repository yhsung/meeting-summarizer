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
├── docs/                 # Project documentation
│   └── project-structure.md  # This file - detailed project structure
├── meeting_summarizer/   # Flutter app directory
│   ├── lib/
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── database_helper.dart           # Main database operations with migration support
│   │   │   │   ├── database_schema.dart           # Database schema definitions and versioning
│   │   │   │   ├── database_migrations.dart       # Database migration system with backup/restore
│   │   │   │   └── README.md                      # Database architecture documentation
│   │   │   ├── enums/
│   │   │   │   ├── audio_format.dart      # Audio format definitions with compression ratios
│   │   │   │   ├── audio_quality.dart     # Quality levels with detailed properties
│   │   │   │   ├── recording_state.dart   # Recording state management
│   │   │   │   └── summary_type.dart      # AI summary type definitions (brief, detailed, executive, etc.)
│   │   │   ├── models/
│   │   │   │   ├── audio_configuration.dart  # Enhanced audio config with serialization
│   │   │   │   ├── recording_session.dart     # Recording session management
│   │   │   │   ├── summarization_configuration.dart # AI summarization configuration with 200+ lines
│   │   │   │   ├── summarization_result.dart         # Comprehensive summarization results with metadata
│   │   │   │   └── database/
│   │   │   │       ├── recording.dart         # Recording model with JSON serialization and encryption support
│   │   │   │       ├── transcription.dart     # Transcription model with status management
│   │   │   │       ├── summary.dart           # Summary model with sentiment analysis
│   │   │   │       └── app_settings.dart      # Application settings model with categories
│   │   │   └── services/
│   │   │       ├── audio_service_interface.dart           # Service interface definition
│   │   │       ├── audio_format_manager.dart              # Platform-aware format selection
│   │   │       ├── codec_manager.dart                     # Codec selection and management
│   │   │       ├── file_size_optimizer.dart               # File size optimization strategies
│   │   │       ├── audio_enhancement_service_interface.dart # Audio enhancement interface with noise reduction, echo cancellation, AGC
│   │   │       ├── audio_enhancement_service.dart         # Audio enhancement implementation using FFT-based processing
│   │   │       ├── encryption_service.dart                # AES-256-GCM encryption service with secure key management
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
│   │   │       └── quality_scoring_service.dart           # Quality assessment with feedback integration (1,146 lines)
│   │   ├── features/
│   │   │   └── audio_recording/
│   │   │       ├── data/
│   │   │       │   ├── audio_recording_service.dart  # Main audio recording service
│   │   │       │   └── platform/
│   │   │       │       ├── audio_recording_platform.dart   # Platform abstraction
│   │   │       │       └── record_platform_adapter.dart    # Record package adapter
│   │   │       ├── domain/             # Domain layer (to be implemented)
│   │   │       └── presentation/       # UI layer (to be implemented)
│   │   └── main.dart                   # Flutter app entry point
│   ├── test/
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── database_helper_migrations_test.dart  # Database helper migration tests
│   │   │   │   └── database_migrations_test.dart         # Migration system tests
│   │   │   └── services/
│   │   │       ├── audio_format_manager_test.dart       # Format manager tests
│   │   │       ├── codec_manager_test.dart               # Codec manager tests
│   │   │       ├── file_size_optimizer_test.dart        # Optimizer tests
│   │   │       ├── audio_enhancement_service_test.dart   # Audio enhancement comprehensive tests
│   │   │       ├── encryption_service_test.dart          # Encryption service tests with key management
│   │   │       ├── encrypted_database_service_test.dart  # Encrypted database service integration tests
│   │   │       └── quality_scoring_service_test.dart     # Quality scoring comprehensive tests (15 test cases)
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
│   ├── pubspec.yaml                   # Flutter dependencies
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
- **AES-256-GCM**: Military-grade encryption for sensitive data
- **Key Management**: Secure key derivation and storage using Flutter Secure Storage
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

- **Core Dependencies**: Essential packages for app functionality
- **Dev Dependencies**: Tools for development, testing, and code quality
- **Platform Dependencies**: Platform-specific integrations and plugins