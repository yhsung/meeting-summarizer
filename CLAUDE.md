# Task Master AI - Claude Code Integration Guide

## Essential Commands

Essential TaskMaster and development commands are available as separate files in `.claude/commands/`:

- **`/taskmaster-setup`** - Initialize TaskMaster and configure models
- **`/taskmaster-next`** - Find and start next available task
- **`/taskmaster-complete <task-id>`** - Complete task with quality gates
- **`/taskmaster-list`** - View all tasks and manage task lifecycle
- **`/quality-gates`** - Run comprehensive code quality checks
- **`/git-workflow`** - Git workflow with quality gates and commit standards
- **`/flutter-debug`** - Flutter debugging and development commands

### Quick Commands

```bash
# Daily workflow
task-master next                    # Get next task
task-master show <id>              # View task details
task-master set-status --id=<id> --status=done  # Complete task

# Quality gates
dart format . && flutter analyze && flutter test

# Build verification
flutter build web && flutter build apk --debug
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

## Audio Enhancement

The meeting summarizer includes comprehensive audio enhancement capabilities powered by FFT-based signal processing. For detailed information about audio enhancement features, configuration, and usage, see: [`docs/audio-enhancement.md`](docs/audio-enhancement.md)

### Quick Overview

- **Noise Reduction**: Real-time background noise removal
- **Echo Cancellation**: Echo artifact removal for cleaner audio
- **Automatic Gain Control**: Dynamic level adjustment
- **Spectral Subtraction**: Advanced frequency-domain noise reduction
- **Real-time & Post-processing**: Support for both live and batch enhancement

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

All essential commands have been moved to `.claude/commands/` directory:

- `taskmaster-setup.md` - Project initialization and model configuration
- `taskmaster-next.md` - Find and start next available task
- `taskmaster-complete.md` - Complete task with validation
- `taskmaster-list.md` - Task management and lifecycle
- `quality-gates.md` - Code quality and testing workflow
- `git-workflow.md` - Git operations with quality gates
- `flutter-debug.md` - Flutter development and debugging

These can be used as `/command-name` in Claude Code sessions.

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
- **Component Documentation**: Include descriptive comments for each new component
- **Workflow Updates**: Update workflow sections when introducing new patterns
- **Integration Points**: Document how new components integrate with existing architecture
- **Update Timing**: Always update documentation BEFORE git tracking to ensure commits include current structure

### Iterative Implementation

Detailed implementation workflow is available in the command files:

1. **Task Start**: Use `/taskmaster-next` to find and understand next task
2. **Implementation**: Code following task requirements
3. **Quality Gates**: Use `/quality-gates` to validate code
4. **Git Workflow**: Use `/git-workflow` for proper commit process
5. **Task Completion**: Use `/taskmaster-complete <id>` to finish task

Key principles:
- Always run quality gates before committing
- Update documentation for structural changes
- Use TaskMaster commands to track progress
- Verify builds on all target platforms

### Complex Workflows with Checklists

For large migrations or multi-step processes:

1. Create a markdown PRD file describing the new changes: `touch task-migration-checklist.md` (prds can be .txt or .md)
2. Use Taskmaster to parse the new prd with `task-master parse-prd --append` (also available in MCP)
3. Use Taskmaster to expand the newly generated tasks into subtasks. Consdier using `analyze-complexity` with the correct --to and --from IDs (the new ids) to identify the ideal subtask amounts for each task. Then expand them.
4. Work through items systematically, checking them off as completed
5. Use `task-master update-subtask` to log progress on each task/subtask and/or updating/researching them before/during implementation if getting stuck

### Git Integration

Git workflow with quality gates is detailed in `/git-workflow` command. Key integration:

- TaskMaster tasks reference in commit messages
- Quality gates enforced before commits
- Documentation updates for structural changes
- GitHub CLI integration for PR creation

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

Comprehensive build troubleshooting guide is available in `/flutter-debug` command, including:

- Platform-specific build issues (Android, macOS, Web)
- Common solutions for NDK, MinSdk, Gradle, and Xcode issues
- General build strategy and debugging workflow
- Performance analysis and bundle optimization

---

_This guide ensures Claude Code has immediate access to Task Master's essential functionality for agentic development workflows._
