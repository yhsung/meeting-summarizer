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
│   │   │   ├── enums/
│   │   │   │   ├── audio_format.dart      # Audio format definitions with compression ratios
│   │   │   │   ├── audio_quality.dart     # Quality levels with detailed properties
│   │   │   │   └── recording_state.dart   # Recording state management
│   │   │   ├── models/
│   │   │   │   ├── audio_configuration.dart  # Enhanced audio config with serialization
│   │   │   │   └── recording_session.dart     # Recording session management
│   │   │   └── services/
│   │   │       ├── audio_service_interface.dart           # Service interface definition
│   │   │       ├── audio_format_manager.dart              # Platform-aware format selection
│   │   │       ├── codec_manager.dart                     # Codec selection and management
│   │   │       ├── file_size_optimizer.dart               # File size optimization strategies
│   │   │       ├── audio_enhancement_service_interface.dart # Audio enhancement interface with noise reduction, echo cancellation, AGC
│   │   │       └── audio_enhancement_service.dart         # Audio enhancement implementation using FFT-based processing
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
│   │   │   └── services/
│   │   │       ├── audio_format_manager_test.dart       # Format manager tests
│   │   │       ├── codec_manager_test.dart               # Codec manager tests
│   │   │       ├── file_size_optimizer_test.dart        # Optimizer tests
│   │   │       └── audio_enhancement_service_test.dart   # Audio enhancement comprehensive tests
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

- **Enums**: Type-safe definitions for audio formats, quality levels, and states
- **Models**: Data classes for configuration and session management
- **Services**: Business logic and platform abstractions

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