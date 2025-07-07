# Quality Gates

Run comprehensive quality checks before committing code changes.

## Code Quality Commands

```bash
# Format code consistently
dart format .

# Check for static analysis issues
flutter analyze

# Run all unit and widget tests
flutter test

# Generate code (for JSON serialization, etc.)
flutter pub run build_runner build
```

## Build Verification

```bash
# Verify web compilation
flutter build web

# Verify Android compilation
flutter build apk --debug

# Verify macOS compilation (if targeting)
flutter build macos
```

## Workflow

1. **Format & Analyze**: Run `dart format .` and `flutter analyze`
2. **Test**: Run `flutter test` to ensure all tests pass
3. **Build**: Verify all target platforms compile successfully
4. **Commit**: Only commit after all quality gates pass

## Usage

Run this before any git commit to ensure code quality and compilation integrity.