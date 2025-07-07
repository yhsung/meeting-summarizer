# Task Master AI - Claude Code Integration Guide

## Essential Commands

### Core Workflow Commands

```bash
# Project Setup
task-master init                                    # Initialize Task Master in current project
task-master parse-prd .taskmaster/docs/prd.txt      # Generate tasks from PRD document
task-master models --setup                        # Configure AI models interactively

# Daily Development Workflow
task-master list                                   # Show all tasks with status
task-master next                                   # Get next available task to work on
task-master show <id>                             # View detailed task information (e.g., task-master show 1.2)
task-master set-status --id=<id> --status=done    # Mark task complete

# Task Management
task-master add-task --prompt="description" --research        # Add new task with AI assistance
task-master expand --id=<id> --research --force              # Break task into subtasks
task-master update-task --id=<id> --prompt="changes"         # Update specific task
task-master update --from=<id> --prompt="changes"            # Update multiple tasks from ID onwards
task-master update-subtask --id=<id> --prompt="notes"        # Add implementation notes to subtask

# Analysis & Planning
task-master analyze-complexity --research          # Analyze task complexity
task-master complexity-report                      # View complexity analysis
task-master expand --all --research               # Expand all eligible tasks

# Dependencies & Organization
task-master add-dependency --id=<id> --depends-on=<id>       # Add task dependency
task-master move --from=<id> --to=<id>                       # Reorganize task hierarchy
task-master validate-dependencies                            # Check for dependency issues
task-master generate                                         # Update task markdown files (usually auto-called)
```

## Project Structure

For detailed project structure, architecture overview, and file organization, see: [`docs/project-structure.md`](docs/project-structure.md)

### Quick Reference

- **Flutter App**: `meeting_summarizer/` - Main application code and tests
- **Task Management**: `.taskmaster/` - Task Master AI integration files
- **Claude Integration**: `.claude/` - Claude Code configuration and commands
- **Documentation**: `docs/` - Project documentation and guides
- **Core Services**: `meeting_summarizer/lib/core/services/` - Audio processing and business logic
- **Features**: `meeting_summarizer/lib/features/` - Feature-specific implementations
- **Tests**: `meeting_summarizer/test/` - Comprehensive test suite

## Audio Enhancement Capabilities

The meeting summarizer now includes comprehensive audio enhancement features powered by FFT-based signal processing:

### Core Audio Enhancement Features

- **Noise Reduction**: Advanced algorithms to reduce background noise while preserving speech clarity
- **Echo Cancellation**: Removes echo artifacts from recordings to improve audio quality
- **Automatic Gain Control (AGC)**: Dynamically adjusts audio levels to maintain consistent volume
- **Spectral Subtraction**: Advanced noise reduction using frequency domain analysis
- **Frequency Filtering**: High-pass and low-pass filters to remove unwanted frequency components
- **Real-time Processing**: Stream-based processing for live audio enhancement
- **Post-processing Mode**: Batch processing for recorded audio files

### Dependencies & Libraries

- **fftea ^1.5.0+1**: Fast Fourier Transform library for frequency domain processing
- Supports efficient FFT/IFFT operations for real-time audio processing
- Optimized for power-of-two and arbitrary-sized arrays

### Audio Enhancement Service Usage

```dart
// Initialize the service
final enhancementService = AudioEnhancementService();
await enhancementService.initialize();

// Configure enhancement parameters
final config = AudioEnhancementConfig(
  enableNoiseReduction: true,
  enableEchoCanellation: false,
  enableAutoGainControl: true,
  noiseReductionStrength: 0.7,
  processingMode: ProcessingMode.realTime,
);
await enhancementService.configure(config);

// Process audio data
final result = await enhancementService.processAudio(audioData, sampleRate);

// Stream processing for real-time enhancement
final enhancedStream = enhancementService.processAudioStream(
  inputAudioStream, 
  sampleRate
);

// Individual enhancement functions
final noiseCleaned = await enhancementService.applyNoiseReduction(audioData, sampleRate, 0.5);
final echoFree = await enhancementService.applyEchoCancellation(audioData, sampleRate, 0.3);
final normalized = await enhancementService.applyAutoGainControl(audioData, sampleRate, 0.8);
```

### Performance & Metrics

The service includes comprehensive performance tracking:
- Processing time per audio chunk
- Total samples processed
- Average processing latency
- Enhancement algorithm usage counters

### Integration with Audio Configuration

The existing `AudioConfiguration` class already includes placeholders for enhancement features:
- `enableNoiseReduction` - boolean flag for noise reduction
- `enableAutoGainControl` - boolean flag for AGC

The audio enhancement service seamlessly integrates with the existing audio recording pipeline.

## MCP Integration

Task Master provides an MCP server that Claude Code can connect to. Configure in `.mcp.json`:

```json
{
  "mcpServers": {
    "task-master-ai": {
      "command": "npx",
      "args": ["-y", "--package=task-master-ai", "task-master-ai"],
      "env": {
        "ANTHROPIC_API_KEY": "your_key_here",
        "PERPLEXITY_API_KEY": "your_key_here",
        "OPENAI_API_KEY": "OPENAI_API_KEY_HERE",
        "GOOGLE_API_KEY": "GOOGLE_API_KEY_HERE",
        "XAI_API_KEY": "XAI_API_KEY_HERE",
        "OPENROUTER_API_KEY": "OPENROUTER_API_KEY_HERE",
        "MISTRAL_API_KEY": "MISTRAL_API_KEY_HERE",
        "AZURE_OPENAI_API_KEY": "AZURE_OPENAI_API_KEY_HERE",
        "OLLAMA_API_KEY": "OLLAMA_API_KEY_HERE"
      }
    }
  }
}
```

### Essential MCP Tools

```javascript
help; // = shows available taskmaster commands
// Project setup
initialize_project; // = task-master init
parse_prd; // = task-master parse-prd

// Daily workflow
get_tasks; // = task-master list
next_task; // = task-master next
get_task; // = task-master show <id>
set_task_status; // = task-master set-status

// Task management
add_task; // = task-master add-task
expand_task; // = task-master expand
update_task; // = task-master update-task
update_subtask; // = task-master update-subtask
update; // = task-master update

// Analysis
analyze_project_complexity; // = task-master analyze-complexity
complexity_report; // = task-master complexity-report
```

## Claude Code Workflow Integration

### Standard Development Workflow

#### 1. Project Initialization

```bash
# Initialize Task Master
task-master init

# Create or obtain PRD, then parse it
task-master parse-prd .taskmaster/docs/prd.txt

# Analyze complexity and expand tasks
task-master analyze-complexity --research
task-master expand --all --research
```

If tasks already exist, another PRD can be parsed (with new information only!) using parse-prd with --append flag. This will add the generated tasks to the existing list of tasks..

#### 2. Daily Development Loop

```bash
# Start each session
task-master next                           # Find next available task
task-master show <id>                     # Review task details

# During implementation, check in code context into the tasks and subtasks
task-master update-subtask --id=<id> --prompt="implementation notes..."

# Before completing tasks - enforce quality gates
dart format .                             # Format code consistently
flutter analyze                           # Check for static analysis issues
flutter test                              # Run all unit and widget tests

# Verify builds before git tracking
flutter build web                         # Verify web compilation
flutter build apk --debug                 # Verify Android compilation
flutter build macos                       # Verify macOS compilation (if targeting)

# Update documentation to reflect changes
# CRITICAL: Update CLAUDE.md directory structure to reflect any new files/services
# - Add new services, models, or enums to the directory tree
# - Include descriptive comments for new components
# - Ensure the structure accurately represents current codebase

# Track changes with git only after successful builds and documentation updates
git add .                                 # Stage changes including CLAUDE.md updates
git commit -m "feat: task description"    # Commit with task reference
git push origin main                      # Push and trigger CI/CD

# Complete tasks
task-master set-status --id=<id> --status=done
```

#### 3. Multi-Claude Workflows

For complex projects, use multiple Claude Code sessions:

```bash
# Terminal 1: Main implementation
cd project && claude

# Terminal 2: Testing and validation
cd project-test-worktree && claude

# Terminal 3: Documentation updates
cd project-docs-worktree && claude
```

### Custom Slash Commands

Create `.claude/commands/taskmaster-next.md`:

```markdown
Find the next available Task Master task and show its details.

Steps:

1. Run `task-master next` to get the next task
2. If a task is available, run `task-master show <id>` for full details
3. Provide a summary of what needs to be implemented
4. Suggest the first implementation step
```

Create `.claude/commands/taskmaster-complete.md`:

```markdown
Complete a Task Master task: $ARGUMENTS

Steps:

1. Review the current task with `task-master show $ARGUMENTS`
2. Verify all implementation is complete
3. Run any tests related to this task
4. Mark as complete: `task-master set-status --id=$ARGUMENTS --status=done`
5. Show the next available task with `task-master next`
```

## Tool Allowlist Recommendations

Add to `.claude/settings.json`:

```json
{
  "allowedTools": [
    "Edit",
    "Bash(task-master *)",
    "Bash(git commit:*)",
    "Bash(git add:*)",
    "Bash(npm run *)",
    "mcp__task_master_ai__*"
  ]
}
```

## Configuration & Setup

### API Keys Required

At least **one** of these API keys must be configured:

- `ANTHROPIC_API_KEY` (Claude models) - **Recommended**
- `PERPLEXITY_API_KEY` (Research features) - **Highly recommended**
- `OPENAI_API_KEY` (GPT models)
- `GOOGLE_API_KEY` (Gemini models)
- `MISTRAL_API_KEY` (Mistral models)
- `OPENROUTER_API_KEY` (Multiple models)
- `XAI_API_KEY` (Grok models)

An API key is required for any provider used across any of the 3 roles defined in the `models` command.

### Model Configuration

```bash
# Interactive setup (recommended)
task-master models --setup

# Set specific models
task-master models --set-main claude-3-5-sonnet-20241022
task-master models --set-research perplexity-llama-3.1-sonar-large-128k-online
task-master models --set-fallback gpt-4o-mini
```

## Task Structure & IDs

### Task ID Format

- Main tasks: `1`, `2`, `3`, etc.
- Subtasks: `1.1`, `1.2`, `2.1`, etc.
- Sub-subtasks: `1.1.1`, `1.1.2`, etc.

### Task Status Values

- `pending` - Ready to work on
- `in-progress` - Currently being worked on
- `done` - Completed and verified
- `deferred` - Postponed
- `cancelled` - No longer needed
- `blocked` - Waiting on external factors

### Task Fields

```json
{
  "id": "1.2",
  "title": "Implement user authentication",
  "description": "Set up JWT-based auth system",
  "status": "pending",
  "priority": "high",
  "dependencies": ["1.1"],
  "details": "Use bcrypt for hashing, JWT for tokens...",
  "testStrategy": "Unit tests for auth functions, integration tests for login flow",
  "subtasks": []
}
```

## Claude Code Best Practices with Task Master

### Context Management

- Use `/clear` between different tasks to maintain focus
- This CLAUDE.md file is automatically loaded for context
- Use `task-master show <id>` to pull specific task context when needed

### Documentation Consistency

**CRITICAL**: Maintain accurate documentation at each revision

- **Directory Structure Updates**: Update CLAUDE.md directory structure whenever adding:
  - New services in `lib/core/services/`
  - New models in `lib/core/models/`
  - New enums in `lib/core/enums/`
  - New feature modules in `lib/features/`
  - New test files in `test/`
- **Component Documentation**: Include descriptive comments for each new component
- **Workflow Updates**: Update workflow sections when introducing new patterns
- **Integration Points**: Document how new components integrate with existing architecture
- **Update Timing**: Always update documentation BEFORE git tracking to ensure commits include current structure

### Iterative Implementation

1. `task-master show <subtask-id>` - Understand requirements
2. Explore codebase and plan implementation
3. `task-master update-subtask --id=<id> --prompt="detailed plan"` - Log plan
4. `task-master set-status --id=<id> --status=in-progress` - Start work
5. Implement code following logged plan
6. **Format and validate code before tracking:**
   - `dart format .` - Format source code consistently
   - `flutter analyze` - Check for static analysis issues
   - `flutter test` - Run all unit and widget tests
   - Run any project-specific lint/typecheck commands
7. **Verify builds before git tracking:**
   - `flutter build web` - Verify web compilation
   - `flutter build apk --debug` - Verify Android compilation
   - `flutter build macos` (if targeting macOS) - Verify desktop compilation
   - **CRITICAL**: Only proceed to git if builds are successful
8. **Update documentation to reflect changes:**
   - **MANDATORY**: Update CLAUDE.md directory structure for any new files
   - Add new services, models, enums, or test files to the directory tree
   - Include descriptive comments for new components
   - Ensure structure accurately represents current codebase state
   - Update workflow sections if new patterns or processes are introduced
9. **Track changes with git only after successful builds and docs:**
   - `git add .` - Stage all changes including CLAUDE.md updates
   - `git commit -m "descriptive message"` - Commit with clear message
   - `git push origin main` - Push to remote and trigger CI/CD
10. `task-master update-subtask --id=<id> --prompt="what worked/didn't work"` - Log progress
11. `task-master set-status --id=<id> --status=done` - Complete task

### Complex Workflows with Checklists

For large migrations or multi-step processes:

1. Create a markdown PRD file describing the new changes: `touch task-migration-checklist.md` (prds can be .txt or .md)
2. Use Taskmaster to parse the new prd with `task-master parse-prd --append` (also available in MCP)
3. Use Taskmaster to expand the newly generated tasks into subtasks. Consdier using `analyze-complexity` with the correct --to and --from IDs (the new ids) to identify the ideal subtask amounts for each task. Then expand them.
4. Work through items systematically, checking them off as completed
5. Use `task-master update-subtask` to log progress on each task/subtask and/or updating/researching them before/during implementation if getting stuck

### Git Integration

Task Master works well with `gh` CLI and enforces code quality before commits:

```bash
# Standard development workflow with quality gates
dart format .                     # Format code consistently
flutter analyze                   # Check for static analysis issues
flutter test                      # Run all unit and widget tests

# Verify builds before git tracking
flutter build web                 # Verify web compilation
flutter build apk --debug         # Verify Android compilation  
flutter build macos               # Verify macOS compilation (if targeting)

# Update documentation to reflect structural changes
# MANDATORY: Update CLAUDE.md directory structure for any new files/services
# - Add new components to the directory tree with descriptive comments
# - Ensure documentation accurately represents current codebase state

# Track changes with git only after successful builds and documentation updates
git add .                         # Stage changes including CLAUDE.md updates
git commit -m "feat: implement JWT auth (task 1.2)"  # Reference task in commits
git push origin main              # Push and trigger CI/CD

# Create PR for completed task
gh pr create --title "Complete task 1.2: User authentication" --body "Implements JWT auth system as specified in task 1.2"
```

### Parallel Development with Git Worktrees

```bash
# Create worktrees for parallel task development
git worktree add ../project-auth feature/auth-system
git worktree add ../project-api feature/api-refactor

# Run Claude Code in each worktree
cd ../project-auth && claude    # Terminal 1: Auth work
cd ../project-api && claude     # Terminal 2: API work
```

## Troubleshooting

### AI Commands Failing

```bash
# Check API keys are configured
cat .env                           # For CLI usage

# Verify model configuration
task-master models

# Test with different model
task-master models --set-fallback gpt-4o-mini
```

### MCP Connection Issues

- Check `.mcp.json` configuration
- Verify Node.js installation
- Use `--mcp-debug` flag when starting Claude Code
- Use CLI as fallback if MCP unavailable

### Task File Sync Issues

```bash
# Regenerate task files from tasks.json
task-master generate

# Fix dependency issues
task-master fix-dependencies
```

DO NOT RE-INITIALIZE. That will not do anything beyond re-adding the same Taskmaster core files.

## Important Notes

### AI-Powered Operations

These commands make AI calls and may take up to a minute:

- `parse_prd` / `task-master parse-prd`
- `analyze_project_complexity` / `task-master analyze-complexity`
- `expand_task` / `task-master expand`
- `expand_all` / `task-master expand --all`
- `add_task` / `task-master add-task`
- `update` / `task-master update`
- `update_task` / `task-master update-task`
- `update_subtask` / `task-master update-subtask`

### File Management

- Never manually edit `tasks.json` - use commands instead
- Never manually edit `.taskmaster/config.json` - use `task-master models`
- Task markdown files in `tasks/` are auto-generated
- Run `task-master generate` after manual changes to tasks.json

### Claude Code Session Management

- Use `/clear` frequently to maintain focused context
- Create custom slash commands for repeated Task Master workflows
- Configure tool allowlist to streamline permissions
- Use headless mode for automation: `claude -p "task-master next"`

### Multi-Task Updates

- Use `update --from=<id>` to update multiple future tasks
- Use `update-task --id=<id>` for single task updates
- Use `update-subtask --id=<id>` for implementation logging

### Research Mode

- Add `--research` flag for research-based AI enhancement
- Requires a research model API key like Perplexity (`PERPLEXITY_API_KEY`) in environment
- Provides more informed task creation and updates
- Recommended for complex technical tasks

### Build Troubleshooting

#### Common Build Issues and Solutions

**Android Build Issues:**
- **NDK Version Mismatch**: Update `android/app/build.gradle.kts` with correct NDK version
- **MinSdk Too Low**: Update `minSdk` to meet package requirements (e.g., `minSdk = 23`)
- **Gradle Sync Issues**: Run `flutter clean && flutter pub get` then retry

**macOS Build Issues:**
- **Deployment Target**: Update `macos/Podfile` platform version (e.g., `platform :osx, '10.15'`)
- **Xcode Config**: Add `MACOSX_DEPLOYMENT_TARGET = 10.15` to `.xcconfig` files
- **Pod Dependencies**: Run `cd macos && pod install` after platform updates

**Web Build Issues:**
- **Compilation Errors**: Check for platform-specific imports in web context
- **Asset Issues**: Verify assets are properly configured in `pubspec.yaml`

**General Build Strategy:**
1. Start with `flutter clean` if builds are failing unexpectedly
2. Build platforms in order: Web → Android → macOS/iOS → Windows
3. Fix platform-specific issues one at a time
4. Use `flutter doctor -v` to diagnose environment issues
5. Check package compatibility with `flutter pub outdated`

---

_This guide ensures Claude Code has immediate access to Task Master's essential functionality for agentic development workflows._
