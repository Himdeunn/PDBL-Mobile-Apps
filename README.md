# WUDI - Mobile Application

Cross-platform task management application built with Flutter. Designed for daily productivity and team collaboration with offline-first architecture, push notifications, and seamless guest-to-account migration.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Environment Configuration](#environment-configuration)
- [Running the Application](#running-the-application)
- [Production Build](#production-build)
- [Feature Modules](#feature-modules)
  - [Authentication](#authentication)
  - [Task Management](#task-management)
  - [Team Collaboration](#team-collaboration)
  - [Calendar](#calendar)
  - [Notifications](#notifications)
  - [Profile](#profile)
- [Core Infrastructure](#core-infrastructure)
  - [Network Layer](#network-layer)
  - [Local Database](#local-database)
  - [Secure Storage](#secure-storage)
  - [Notification System](#notification-system)
  - [Connection Service](#connection-service)
- [API Integration](#api-integration)
- [Android Permissions](#android-permissions)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- **Task Management** -- Full CRUD with title, description, deadline, priority levels (high/medium/low), and completion tracking. Swipe-based actions for quick edit and delete.
- **Offline-First Architecture** -- Local Isar database stores all tasks and notifications. The app works fully without internet and syncs when connectivity is restored.
- **Guest Mode** -- Complete task management without account creation. Tasks are identified by a unique device ID and automatically migrate to the account on registration or login.
- **Team Collaboration** -- Create teams, invite members by email, assign tasks to specific members, and track per-member completion progress. Role-based management with owner and member roles.
- **Calendar View** -- Monthly calendar with color-coded priority indicators. Interactive navigation for date-based task browsing.
- **Push Notifications** -- Firebase Cloud Messaging integration for real-time alerts. Local notifications for deadline reminders with configurable reminder days and time.
- **Notification Center** -- In-app notification list with read/unread state, swipe-to-delete, and real-time updates for team invitations, member removals, and deadline alerts.
- **Notification Settings** -- Per-user configuration for reminder schedule (days before deadline), reminder time, vibration toggle, and remote alert toggle.
- **Profile Management** -- Avatar upload, display name update, email change, and password change with current password verification.
- **Optimistic UI Updates** -- Instant state transitions for task completion and status changes. The UI updates immediately while the server request processes in the background.
- **Global Search** -- Real-time task filtering from the home screen search bar with debounced input.
- **Daily Dashboard** -- Home screen with week strip navigation, daily task list, focus card showing progress, and quick task creation.
- **Client-Side Rate Limiting** -- Login and registration forms enforce cooldown periods after repeated failed attempts.
- **Automatic Token Refresh** -- Dio interceptor handles JWT expiration with concurrent request deduplication to prevent 401 storms.
- **Connection Monitoring** -- Real-time connectivity detection with automatic sync when connection is restored.

---

## Tech Stack

| Component            | Technology                            |
|----------------------|---------------------------------------|
| Framework            | Flutter (Dart SDK 3.11.0+)            |
| Local Database       | Isar Community 3.3.2                  |
| Network Client       | Dio 5.9.2                             |
| Secure Storage       | flutter_secure_storage 9.2.4          |
| Push Notifications   | firebase_messaging 16.1.3             |
| Local Notifications  | flutter_local_notifications 21.0.0    |
| State Management     | Reactive Streams (Isar watchers)      |
| Navigation Bar       | curved_navigation_bar 1.0.6           |
| Calendar             | Custom implementation with intl 0.19  |
| Typography           | google_fonts 8.0.2                    |
| Connectivity         | connectivity_plus 6.1.1               |
| Environment          | flutter_dotenv 6.0.0                  |
| Image Picker         | image_picker 1.1.2                    |
| UUID Generation      | uuid 4.5.3                            |
| Home Widget          | home_widget 0.7.0+1                   |
| Timezone             | flutter_timezone 5.0.1 + timezone 0.11 |
| Encryption           | crypto 3.0.3                          |

---

## Architecture

The application follows a **feature-first architecture** with a shared core layer:

```
lib/
|-- core/           # Shared infrastructure (network, storage, theme, utils)
|-- features/       # Feature modules (auth, home, task, group, calendar, profile, shell, splash)
|-- main.dart        # Entry point, Firebase init, notification setup
|-- firebase_options.dart  # Firebase configuration (generated)
```

**Data Flow:**

```
UI (Pages/Widgets)
    |
    v
Services (business logic, API calls)
    |
    +--> API Client (Dio) --> Backend REST API
    |
    +--> Local Database (Isar) --> Offline storage
    |
    +--> Secure Storage --> Tokens, credentials
```

**Key Design Patterns:**
- Feature modules are self-contained with pages, services, widgets, and models
- Services handle both local persistence and remote API synchronization
- Isar watchers provide reactive streams for automatic UI updates
- Optimistic updates: UI changes immediately, server sync happens in background
- Error handler provides centralized, user-friendly error reporting

---

## Project Structure

```
lib/
|-- core/
|   |-- models/
|   |   |-- user.dart                    # User data model
|   |-- network/
|   |   |-- api_client.dart              # Dio HTTP client with interceptors, auto-retry, token refresh
|   |   |-- firebase_service.dart        # FCM initialization, token management, background handlers
|   |-- services/
|   |   |-- connection_service.dart      # Network connectivity monitoring and auto-sync
|   |-- storage/
|   |   |-- local_database.dart          # Isar database initialization and management
|   |   |-- secure_storage.dart          # FlutterSecureStorage wrapper for tokens and credentials
|   |-- theme/
|   |   |-- app_theme.dart               # Application-wide theme definition
|   |   |-- logo.dart                    # Logo widget
|   |   |-- primary_button.dart          # Reusable primary button component
|   |   |-- primary_textfield.dart       # Reusable primary text field component
|   |   |-- secondary_button.dart        # Reusable secondary button component
|   |   |-- secondary_textfield.dart     # Reusable secondary text field component
|   |-- utils/
|   |   |-- debouncer.dart               # Input debouncing utility for search
|   |   |-- error_handler.dart           # Centralized error handling and user-friendly messages
|   |   |-- image_utils.dart             # Image processing and compression utilities
|   |   |-- navigator_service.dart       # Global navigation key and navigator access
|   |   |-- notification_helper.dart     # Local notification scheduling and channel setup
|   |   |-- widget_service.dart          # Home widget update service
|   |-- widgets/
|       |-- auth_required_dialog.dart    # Dialog shown when auth-only feature accessed in guest mode
|
|-- features/
|   |-- auth/
|   |   |-- pages/
|   |   |   |-- welcome_page.dart        # Onboarding/welcome screen
|   |   |   |-- login_page.dart          # Login form with rate limiting
|   |   |   |-- register_page.dart       # Registration form with rate limiting
|   |   |-- services/
|   |       |-- auth_service.dart        # JWT auth, token storage, session management, device ID
|   |
|   |-- home/
|   |   |-- pages/
|   |   |   |-- home_page.dart           # Main dashboard with daily overview
|   |   |-- widgets/
|   |       |-- home_header.dart         # Dashboard header with greeting and stats
|   |       |-- search_bar.dart          # Global task search with debounce
|   |       |-- week_strip.dart          # Horizontal scrollable week date picker
|   |       |-- daily_task_list.dart     # Task list filtered by selected date
|   |       |-- focus_card.dart          # Progress overview and focus statistics
|   |
|   |-- task/
|   |   |-- models/
|   |   |   |-- task_local.dart          # Isar schema for local task persistence
|   |   |   |-- task_local.g.dart        # Generated Isar adapter
|   |   |-- pages/
|   |   |   |-- task_page.dart           # Full task list with filters and sorting
|   |   |   |-- create_task_page.dart    # Task creation/editing form
|   |   |-- services/
|   |       |-- task_repository.dart     # Task CRUD, sync logic, offline queue management
|   |
|   |-- group/
|   |   |-- pages/
|   |   |   |-- group_page.dart          # Team list and invitation overview
|   |   |   |-- team_detail_page.dart    # Team detail with members and tasks
|   |   |   |-- member_detail_page.dart  # Individual member progress view
|   |   |   |-- create_group_task_page.dart  # Create task assigned to group
|   |   |   |-- create_team_task_page.dart   # Create task within a specific team
|   |   |   |-- edit_team_task_page.dart     # Edit existing team task
|   |   |-- services/
|   |   |   |-- team_service.dart        # Team CRUD, invitations, member management
|   |   |-- widgets/
|   |       |-- group_card.dart          # Team summary card with progress indicator
|   |       |-- invitation_card.dart     # Pending invitation card with accept/decline
|   |
|   |-- calendar/
|   |   |-- pages/
|   |       |-- calendar_page.dart       # Monthly calendar with task indicators
|   |
|   |-- profile/
|   |   |-- models/
|   |   |   |-- notification_local.dart  # Isar schema for local notification cache
|   |   |   |-- notification_local.g.dart # Generated Isar adapter
|   |   |-- pages/
|   |   |   |-- profile_page.dart        # User profile with settings tabs
|   |   |   |-- notification_page.dart   # Notification center with read/unread management
|   |   |-- services/
|   |   |   |-- profile_service.dart     # Avatar upload, name/email/password update
|   |   |   |-- notification_service.dart # Notification CRUD and sync
|   |   |   |-- notification_settings_service.dart # Reminder configuration
|   |   |-- widgets/
|   |       |-- task_alert_item.dart     # Individual notification list item
|   |
|   |-- shell/
|   |   |-- pages/
|   |   |   |-- main_navigation.dart     # Root scaffold with bottom navigation
|   |   |-- widgets/
|   |       |-- bottom_navbar.dart       # Curved bottom navigation bar
|   |
|   |-- splash/
|       |-- pages/
|           |-- splash_page.dart         # App startup with auth check and data preload
|
|-- main.dart                            # Entry point: Firebase init, Isar init, notification channels
|-- firebase_options.dart                # Generated Firebase configuration
```

---

## Requirements

- Flutter SDK 3.11.0 or higher
- Dart SDK 3.11.0 or higher
- Android Studio or Visual Studio Code with Flutter/Dart plugins
- Android SDK (minimum API 21)
- Access to the PDBL-BACKEND API service
- Firebase project (for push notifications)

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Himdeunn/PDBL-Mobile-Apps.git
   cd PDBL-Mobile-Apps
   ```

2. Create environment file at the project root:
   ```
   API_URL=https://your-api-domain.com/api
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Generate Isar database schemas:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. Run the application:
   ```bash
   flutter run
   ```

---

## Environment Configuration

Create a `.env` file in the project root directory:

```
API_URL=https://your-api-domain.com/api
```

This file is bundled as a Flutter asset and loaded at runtime via `flutter_dotenv`. The API client reads this value to construct all backend requests.

Firebase configuration is managed through `firebase_options.dart`, generated by the FlutterFire CLI.

> [!IMPORTANT]
> You must add your own `android/app/google-services.json` file to the project. This file is excluded from version control for security reasons. Follow the official [Firebase setup guide](https://firebase.google.com/docs/flutter/setup) to generate this for your project.

---

## Running the Application

**Development:**
```bash
flutter run
```

**With specific device:**
```bash
flutter run -d <device_id>
```

**Hot reload** is supported during development. Press `r` in the terminal or save files in your IDE.

---

## Production Build

**Architecture-specific APK (recommended for direct distribution):**
```bash
flutter build apk --target-platform android-arm64
```

**Split APKs by ABI:**
```bash
flutter build apk --split-per-abi
```

**Android App Bundle (recommended for Play Store):**
```bash
flutter build appbundle
```

**Generate launcher icons after asset changes:**
```bash
dart run flutter_launcher_icons
```

---

## Feature Modules

### Authentication

- Welcome screen with onboarding introduction
- Login with email/password and client-side rate limiting (cooldown after repeated failures)
- Registration with name, email, password confirmation, and input validation
- Automatic guest data migration: tasks created without an account are linked to the new account on registration or login
- JWT token stored in FlutterSecureStorage with automatic refresh via Dio interceptor
- Concurrent refresh request deduplication prevents token race conditions
- Session persistence across app restarts

### Task Management

- Create tasks with title, description, deadline, and priority (high/medium/low)
- Swipe-to-complete and swipe-to-delete with flutter_slidable
- Optimistic UI updates: completion state changes instantly before server confirmation
- Offline task creation: tasks stored in Isar and synced when connectivity is available
- Bulk sync endpoint for transferring multiple local tasks to the server
- Task filtering by date (via week strip on home page)
- Global search with debounced input

### Team Collaboration

- Create teams with name and description
- Invite registered users by email with real-time email validation
- Accept or decline team invitations from the notification center or group page
- Assign tasks to specific team members via email
- Per-member completion tracking: each assigned member checks completion individually
- Team progress visualization with percentage indicators
- Member detail view showing individual task statistics
- Owner privileges: invite, remove, and manage members

### Calendar

- Monthly calendar grid with navigation
- Color-coded task indicators by priority level
- Tap a date to view tasks due on that day
- Interactive month-by-month browsing

### Notifications

- In-app notification center with real-time updates
- Local Isar cache for offline notification access
- Notification types: team invitations, member removals, deadline reminders
- Mark individual notifications as read or mark all as read
- Swipe-to-delete with confirmation
- Push notifications via Firebase Cloud Messaging with high-priority Android channel
- Local notification scheduling for deadline reminders based on user settings
- Background message handling when app is killed or in background
- Boot-completed receiver to reschedule notifications after device restart

### Profile

- Avatar upload from camera or gallery with image compression
- Display name editing
- Email change with current password verification
- Password change with current password verification
- Notification settings configuration (reminder days, time, vibration, remote alerts)
- Logout with token invalidation and local data cleanup

---

## Core Infrastructure

### Network Layer

**API Client** (`core/network/api_client.dart`):
- Dio-based HTTP client with base URL from environment variables
- Automatic HTTPS enforcement
- Request interceptor attaching JWT token, X-Device-ID, and X-Timezone headers
- Response interceptor with automatic 401 handling and token refresh
- Concurrent refresh deduplication using Completer pattern
- Configurable timeout settings
- Device tracking via UUID-based device identification

### Local Database

**Isar Database** (`core/storage/local_database.dart`):
- Isar Community 3.3.2 for high-performance local persistence
- Schemas: `TaskLocal` (tasks), `NotificationLocal` (notifications)
- Reactive watchers for automatic UI updates when data changes
- Used as primary data source in offline-first architecture

### Secure Storage

**FlutterSecureStorage** (`core/storage/secure_storage.dart`):
- Encrypted key-value storage for sensitive data
- Stores: JWT token, user profile data, device ID
- Platform-specific encryption (Keychain on iOS, EncryptedSharedPreferences on Android)
- Device ID persistence across app reinstalls

### Notification System

**Local Notifications** (`core/utils/notification_helper.dart`):
- flutter_local_notifications with Android high-importance channel
- Exact alarm scheduling for deadline reminders
- Timezone-aware scheduling via flutter_timezone
- Boot-completed receiver reschedules notifications after device restart

**Firebase Cloud Messaging** (`core/network/firebase_service.dart`):
- FCM token registration with backend
- Foreground, background, and terminated state message handling
- High-priority Android notification channel (high_importance_channel_v2)
- FLUTTER_NOTIFICATION_CLICK intent filter for tap handling

### Connection Service

**Connectivity Monitoring** (`core/services/connection_service.dart`):
- Real-time network state detection via connectivity_plus
- Automatic data sync when connection transitions from offline to online
- Used by task repository and notification service for sync decisions

---

## API Integration

The application communicates with the PDBL-BACKEND via REST API:

| Feature       | Endpoint Pattern                          | Auth Model  |
|---------------|-------------------------------------------|-------------|
| Auth          | POST `/register`, `/login`, `/logout`     | Public/JWT  |
| Token         | POST `/refresh`, `/auth/register-fcm-token` | JWT       |
| Tasks         | GET/POST/PUT/DELETE `/todos`              | Hybrid      |
| Bulk Sync     | POST `/todos/bulk`                        | Hybrid      |
| Team Toggle   | POST `/todos/{id}/toggle-member`          | JWT         |
| Teams         | GET/POST/PUT/DELETE `/teams`              | JWT         |
| Invitations   | POST `/teams/{id}/invite|accept|decline`  | JWT         |
| Members       | DELETE `/teams/{id}/members/{uid}`        | JWT         |
| Profile       | POST `/profile/avatar|password|email|update` | JWT      |
| Notifications | GET/POST/DELETE `/notifications`          | JWT         |
| Settings      | GET/POST `/notification-settings`         | JWT         |
| Email Check   | GET `/users/check-email`                  | JWT         |

**Hybrid Auth** endpoints accept either JWT Bearer token (registered users) or X-Device-ID header (guest users).

---

## Android Permissions

The following permissions are declared in `AndroidManifest.xml`:

| Permission                  | Purpose                                           |
|-----------------------------|---------------------------------------------------|
| `INTERNET`                  | Network access for API communication              |
| `ACCESS_NETWORK_STATE`      | Connectivity monitoring for offline-first sync    |
| `VIBRATE`                   | Notification vibration feedback                   |
| `RECEIVE_BOOT_COMPLETED`    | Reschedule local notifications after device restart |
| `POST_NOTIFICATIONS`        | Display notifications (Android 13+)               |
| `SCHEDULE_EXACT_ALARM`      | Precise deadline reminder scheduling              |
| `USE_EXACT_ALARM`           | Exact alarm permission (Android 14+)              |
| `USE_FULL_SCREEN_INTENT`    | Full-screen notification display                  |

---

## Troubleshooting

### API Connection Fails in Release Build

Verify that `AndroidManifest.xml` includes network permissions:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Isar Build Errors

Regenerate database schemas:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Notifications Not Appearing

1. Verify Firebase configuration in `firebase_options.dart`
2. Check that FCM token is registered with the backend (POST `/auth/register-fcm-token`)
3. On Android 13+, ensure `POST_NOTIFICATIONS` permission is granted
4. Verify the notification channel ID matches: `high_importance_channel_v2`
5. For exact alarms on Android 12+, the user may need to manually grant the exact alarm permission in system settings

### Token Refresh Issues

The app uses idempotent token refresh with concurrent request deduplication. If persistent 401 errors occur:
1. Clear app data and re-login
2. Check that the backend JWT blacklist grace period is configured (recommended: 30 seconds)

### Offline Sync Not Working

1. Verify `connectivity_plus` detects network changes correctly
2. Check that the task repository sync logic runs on connectivity state change
3. Ensure the backend `/todos/bulk` endpoint is accessible

---

## License

MIT License. See [LICENSE](LICENSE) for details.
