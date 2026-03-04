# WUDI - Task Management Application

WUDI is a cross-platform task management application built with Flutter, designed to help users organize their daily productivity. It features a clean, premium interface with real-time task synchronization, calendar integration, and seamless guest-to-user data migration.

## Features

- **Task Management**: Create, edit, delete, and complete tasks with titles, descriptions, deadlines, and priority levels (Low, Medium, High).
- **Calendar View**: Visualize tasks across dates with color-coded priority indicators and an interactive monthly calendar.
- **Today Dashboard**: Quick overview of the current day's tasks with a scrollable week strip for browsing nearby dates.
- **Guest Mode**: Use the app without an account. Tasks are stored locally and synced to the backend using a unique Device ID.
- **Account Synchronization**: Register or log in to sync tasks across devices. Guest tasks are automatically migrated to the user account upon authentication.
- **Offline-First Architecture**: All data is stored locally using Isar database, ensuring the app works without an internet connection. Changes are synced when connectivity is restored.
- **Optimistic UI Updates**: Task state changes (e.g., marking as complete) reflect instantly in the UI without waiting for server confirmation.
- **Swipe Actions**: Slide tasks to quickly edit or delete them.
- **Search**: Filter tasks by title directly from the home screen.

## Tech Stack

| Layer         | Technology                |
|---------------|---------------------------|
| Framework     | Flutter (Dart)            |
| Local Database| Isar 3.1.0                |
| Networking    | Dio                       |
| State         | StatefulWidget + Streams  |
| Auth Storage  | flutter_secure_storage    |
| Backend       | Laravel (PHP) + Sanctum   |
| API Protocol  | RESTful JSON              |

## Project Structure

```
lib/
  core/
    network/        # API client, Dio interceptors
    storage/        # Isar database setup, SecureStorage
    theme/          # App colors, custom widgets (buttons, text fields)
  features/
    auth/           # Login, Register pages and AuthService
    calendar/       # Calendar page with monthly view and task list
    home/           # Home page with today tasks and week strip
    shell/          # Main navigation scaffold, bottom navbar
    task/           # Task CRUD pages, TaskRepository, TaskLocal model
```

## Getting Started

### Prerequisites

- Flutter SDK (3.11.0 or later)
- Dart SDK (included with Flutter)
- Android Studio or VS Code with Flutter extensions
- A running instance of the PDBL-BACKEND Laravel API (for synchronization)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Himdeunn/PDBL-Mobile-Apps.git
   cd PDBL-Mobile-Apps
   git checkout fajar_Branch
   ```

2. Create a `.env` file in the project root:
   ```
   API_URL=https://your-api-domain.com/api
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Generate Isar schemas:
   ```bash
   dart run build_runner build
   ```

5. Run the application:
   ```bash
   flutter run
   ```

### Building for Release

```bash
# Single APK (arm64 only, recommended for direct distribution)
flutter build apk --target-platform android-arm64

# Split APKs (one per architecture)
flutter build apk --split-per-abi

# App Bundle (recommended for Google Play Store)
flutter build appbundle
```

## Backend API

The application communicates with a Laravel backend via RESTful endpoints:

| Method | Endpoint         | Description            | Auth Required |
|--------|------------------|------------------------|---------------|
| POST   | /api/register    | Create a new account   | No            |
| POST   | /api/login       | Authenticate user      | No            |
| POST   | /api/logout      | Invalidate token       | Yes           |
| GET    | /api/todos       | List tasks             | Mixed         |
| POST   | /api/todos       | Create a task          | Mixed         |
| PUT    | /api/todos/{id}  | Update a task          | Mixed         |
| DELETE | /api/todos/{id}  | Delete a task          | Mixed         |

Mixed authentication endpoints accept either a Bearer token (authenticated users) or an X-Device-ID header (guest users).

## Configuration

Environment variables are managed through a `.env` file using the `flutter_dotenv` package:

| Variable  | Description                    | Example                              |
|-----------|--------------------------------|--------------------------------------|
| API_URL   | Base URL for the backend API   | https://your-domain.com/api          |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
