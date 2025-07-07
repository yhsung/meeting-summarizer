# Git Workflow

Comprehensive git workflow with quality gates and proper commit messages.

## Update documentation

Update docs/project-structure.md for architectural, file, directory changes

## Pre-commit Workflow

```bash
# 1. Run quality gates
cd ${workspaceFolder}/meeting_summarizer
dart format .
flutter analyze
flutter test

# 2. Verify builds
flutter build web
flutter build apk --debug
flutter build macos

# 4. Stage and commit
git add ${workspaceFolder}
git status
git commit -m "descriptive commit message"
```

## Commit Message Format

```
type: brief description (Task X.Y)

Detailed description of changes:
• Feature 1: Description
• Feature 2: Description
• Dependencies: Added packages

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Git Operations

```bash
# Check status
git status

# View recent commits
git log --oneline -5

# Create pull request
gh pr create --title "Title" --body "Description"

# Push changes
git push origin main
```

## Usage

Follow this workflow for all code changes to maintain quality and proper version control.