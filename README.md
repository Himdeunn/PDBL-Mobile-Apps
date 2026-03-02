# Wudi - Productivity & Task Management Mobile App

Wudi is a comprehensive productivity and task management mobile application built with Flutter. It provides users with an intuitive interface to manage daily tasks, track focus time, and organize their schedules efficiently.

This repository contains the frontend source code developed using a modern, scalable Flutter architecture.

## Architecture

The application implements a strict **Feature-First Clean Architecture**. This approach ensures separation of concerns, high maintainability, and scalability for enterprise-level development.

The codebase is structured logically:

```text
lib/
 ├── core/
 │   ├── models/            # Shared data entities and models
 │   ├── network/           # Centralized API client configuration (Dio interceptors)
 │   ├── storage/           # Encrypted local storage configuration
 │   └── theme/             # Global application theme, colors, and shared UI components
 └── features/
     ├── auth/              # Authentication flow (Login, Register, Guest Mode)
     ├── calendar/          # Monthly and weekly schedule views
     ├── home/              # Main dashboard and daily task overview
     ├── profile/           # User profile management and settings
     ├── shell/             # Main navigation container and bottom navigation bar
     └── task/              # Task creation and management interfaces
```

## Recent Updates & Optimizations

The application has recently undergone a major architectural overhaul to meet industry-standard best practices:

### 1. Structural Refactoring
*   **Feature-First Migration:** Transitioned from a flat `pages/` and `components/` layout to a modular `features/` structure.
*   **Centralized Theming:** Extracted all hardcoded UI constants (hex colors, text styles, padding) into a centralized `AppTheme` and `AppColors` configuration, ensuring UI consistency across all screens.

### 2. Security Enhancements
*   **Dio Integration:** Replaced the default `http` package with `dio` for robust network requests. Implemented a centralized `ApiClient` with an `AuthInterceptor` that automatically injects Bearer tokens into request headers.
*   **Encrypted Storage:** Removed the unencrypted `Isar` local database for session management. Integrated `flutter_secure_storage` to securely encrypt authentication tokens and user session data using Android Keystore and iOS Keychain.

### 3. Performance Optimizations
*   **Widget Constification:** Enforced `const` constructors on all static widgets, text elements, and styling definitions. This drastically reduces the widget tree rebuild footprint, improving the rendering pipeline and achieving consistent 60 FPS performance.
*   **Dead Code Elimination:** Removed unused dependencies and legacy generated code from the previous architecture.

## Getting Started

### Prerequisites

*   Flutter SDK (3.11.0 or higher)
*   Dart SDK
*   Android Studio / Xcode for platform-specific compilation
*   An active backend environment (currently configured for ngrok testing)

### Installation

1. Clone the repository to your local machine.
2. Navigate to the project root directory.
3. Install the required Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Verify the codebase for any static analysis issues:
   ```bash
   flutter analyze
   ```
5. Run the application on your connected device or emulator:
   ```bash
   flutter run
   ```

## Key Technologies

*   **Flutter Framework:** Cross-platform UI toolkit.
*   **Dio:** Advanced HTTP client for network requests, interceptors, and error handling.
*   **Flutter Secure Storage:** Cryptographic local storage for sensitive session data.
*   **Animated Bottom Navigation Bar:** Custom navigation implementation for the main application shell.
