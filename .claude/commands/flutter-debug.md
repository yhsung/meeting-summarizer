# Flutter Debug Commands

Essential Flutter debugging and development commands.

## Development Commands

```bash
# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build

# Check Flutter doctor
flutter doctor -v

# Check outdated packages
flutter pub outdated
```

## Build Troubleshooting

```bash
# Android build issues
flutter clean && flutter pub get
cd android && ./gradlew clean && cd ..

# iOS/macOS build issues
cd ios && pod install && cd ..
cd macos && pod install && cd ..

# Web build issues
flutter build web --web-renderer html
```

## Testing & Analysis

```bash
# Run specific test file
flutter test test/path/to/test_file.dart

# Run tests with coverage
flutter test --coverage

# Analyze specific file
flutter analyze lib/path/to/file.dart

# Check for unused dependencies
flutter pub deps
```

## Performance

```bash
# Profile build
flutter build --profile

# Analyze bundle size
flutter build web --analyze-size

# Run performance tests
flutter test integration_test/
```

## Build Troubleshooting

### Common Build Issues and Solutions

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

## Usage

Use these commands for Flutter development, debugging, and performance analysis.