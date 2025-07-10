# Meeting Summarizer

**An intelligent, cross-platform application to record, enhance, transcribe, and summarize your meetings using advanced AI.**

[![Build Status](https://github.com/yhsung/meeting-summarizer/actions/workflows/ci.yml/badge.svg)
](https://github.com/yhsung/meeting-summarizer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%26%20Layered-orange)](docs/architecture.md)

This repository contains the complete source code for the Meeting Summarizer project, including the cross-platform Flutter application and the powerful `task-master` development toolkit for agentic workflows.

## ✨ Key Features

-   **High-Fidelity Audio Recording**: Simple, intuitive interface for capturing meeting audio.
-   **Advanced Audio Enhancement**: A real-time audio processing pipeline to improve clarity using Noise Reduction, Echo Cancellation, and Automatic Gain Control (AGC).
-   **AI-Powered Transcription**: State-of-the-art speech-to-text integration for highly accurate transcriptions.
-   **Intelligent Summarization**: A sophisticated AI engine that generates multiple summary types: Executive Summaries, Detailed Notes, and Action Item Lists.
-   **Secure & Encrypted Storage**: Local SQLite database with optional, transparent AES-256-GCM encryption for all sensitive data.
-   **Cross-Platform**: Single codebase supporting Android, iOS, macOS, Web, and Windows.

## 🏛️ Architecture

The application is built using a **Layered Architecture**, heavily inspired by **Clean Architecture** principles. This ensures a strong separation of concerns, making the codebase scalable, maintainable, and highly testable.

For a deep dive into the architecture, including diagrams and data flow, please see the **Software Architecture Document**.

## 🚀 Getting Started

There are two main ways to interact with this project: running the Flutter application or using the development tools.

### Running the Flutter Application

1.  **Navigate to the app directory:**
    ```bash
    cd meeting_summarizer
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the app:**
    ```bash
    flutter run
    ```

## 📂 Project Structure

The repository is organized into several key areas:

-   `meeting_summarizer/`: The source code for the Flutter application.
-   `docs/`: High-level project documentation, including architecture and structure.
-   `.taskmaster/`: Configuration and data for the `task-master` development tool.
-   `.github/`: GitHub-specific files, including workflows and instruction prompts for AI assistants.

For a detailed explanation of the directory layout and the purpose of each component, please refer to the **Project Structure Document**.
