# Meeting Summarizer Flutter App

This is the Flutter application for the Meeting Summarizer project. It provides the user interface and core functionality for recording, enhancing, and managing meeting audio.

## 🚀 Features

- **Audio Recording**: Record meetings and conversations with ease.
- **Audio Enhancement**: Improve audio quality with advanced signal processing.
-   - **Noise Reduction**: Remove background noise.
-   - **Echo Cancellation**: Eliminate echo for clearer audio.
-   - **Automatic Gain Control**: Normalize audio levels.
- **Cross-Platform**: Supports Android, iOS, macOS, Web, and Windows.

## 🛠️ Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- An IDE like [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio)

### Installation

1.  Navigate to the application directory:
    ```bash
    cd meeting_summarizer
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```

### Running the Application

```bash
flutter run
```

## Project Structure

The project follows a clean architecture, with a clear separation of concerns between the data, domain, and presentation layers.

- `lib/core`: Shared components like services, models, and enums.
- `lib/features`: Feature-specific implementations, such as audio recording and summarization.
- `test`: Unit, widget, and integration tests.

For a more detailed breakdown of the project structure, see the main project documentation.