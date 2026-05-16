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
- [Shorebird Release and Patch](#shorebird-release-and-patch)
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
- [Google Sign-In and Android Signing](#google-sign-in-and-android-signing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- **Task Management** -- Full CRUD with title, description, deadline, priority levels (high/medium/low), and completion tracking. Swipe-based actions for quick edit and delete.
- **Offline-First Architecture** -- Local Isar database stores all tasks and notifications. The app works fully without internet and syncs when connectivity is restored.
- **Guest Mode** -- Complete task management without account creation. Tasks are identified by a unique device ID and automatically migrate to the account on registration or login.
- **Team Collaboration** -- Create teams, invite members by email, assign tasks to specific members, and track per-member completion progress. Role-based management with owner and member roles.
- **Chat** -- Personal and team chat with message history, replies, edits, deletion controls, mention highlighting, unread indicators, read marking, cached message state, and REST polling fallback.
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
- **Email Verification** -- New registrations are gated behind a 6-digit OTP sent to the user's email. Resend is supported with cooldown.
- **Forgot Password Flow** -- Request OTP by email, verify the code on a dedicated screen, then set a new password.
- **Google Sign-In** -- One-tap sign in or register with a Google account.
- **Notification Tap Navigation** -- Tapping a push notification navigates the app to the correct tab: team/invite/kick events go to the Group tab, task events go to the Home tab. Handled for all three app states: killed (getInitialMessage), backgrounded (onMessageOpenedApp), and local notification tap.
- **Bounded Image Cache** -- All network images are routed through a custom cache manager (WudiCacheManager) limited to 100 objects with a 7-day TTL, capping disk usage at approximately 50-100 MB regardless of usage volume.
- **Maintenance Mode** -- Firebase Remote Config controls a kill-switch that shows a maintenance dialog when the app is under scheduled downtime.
- **Force Update** -- Remote Config minimum version check prompts users to update when the installed build is too old.

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
| Network Images       | cached_network_image 3.4.1            |
| Image Cache          | flutter_cache_manager 3.4.1           |
| UUID Generation      | uuid 4.5.3                            |
| Home Widget          | home_widget 0.7.0+1                   |
| Timezone             | flutter_timezone 5.0.1 + timezone 0.11 |
| Encryption           | crypto 3.0.3                          |
| Remote Config        | firebase_remote_config (feature flags, maintenance mode) |

---

## Architecture

The application follows a **feature-first architecture** with a shared core layer:

```
lib/
|-- core/           # Shared infrastructure (network, storage, theme, utils)
|-- features/       # Feature modules (auth, home, task, group, chat, calendar, profile, shell, splash)
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
|   |-- services/
|   |   |-- remote_config_service.dart   # Firebase Remote Config: maintenance mode, force update flags
|   |-- utils/
|   |   |-- debouncer.dart               # Input debouncing utility for search
|   |   |-- error_handler.dart           # Centralized error handling and user-friendly messages
|   |   |-- image_cache_manager.dart     # WudiCacheManager: 100 object / 7-day TTL disk cache
|   |   |-- image_utils.dart             # Image processing and compression utilities
|   |   |-- navigator_service.dart       # Global navigation key and navigator access
|   |   |-- network_utils.dart           # HTTP headers builder (Origin, Referer, ngrok bypass)
|   |   |-- notification_helper.dart     # Local notification scheduling, FCM tap event streams
|   |   |-- widget_service.dart          # Home widget update service
|   |-- widgets/
|       |-- auth_required_dialog.dart    # Dialog shown when auth-only feature accessed in guest mode
|       |-- maintenance_dialog.dart      # Full-screen dialog shown during maintenance mode
|       |-- update_dialog.dart           # Force-update prompt with Play Store deep link
|
|-- features/
|   |-- auth/
|   |   |-- pages/
|   |   |   |-- welcome_page.dart        # Onboarding/welcome screen
|   |   |   |-- login_page.dart          # Login form with rate limiting and Google Sign-In
|   |   |   |-- register_page.dart       # Registration form with rate limiting
|   |   |   |-- verify_email_page.dart   # OTP input for new account email verification
|   |   |   |-- forgot_password_page.dart # Email input for password reset OTP request
|   |   |   |-- verify_otp_page.dart     # OTP input for password reset verification
|   |   |   |-- reset_password_page.dart # New password form after OTP verified
|   |   |-- services/
|   |       |-- auth_service.dart        # JWT auth, Google login, token storage, session management
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
|   |-- chat/
|   |   |-- models/
|   |   |   |-- chat_models.dart       # Conversation, member, and message models
|   |   |-- pages/
|   |   |   |-- chat_list_page.dart    # Conversation inbox with unread state
|   |   |   |-- chat_room_page.dart    # Message room, composer, replies, editing, deletion
|   |   |-- services/
|   |       |-- chat_service.dart      # REST/Firestore chat sync, cache, polling fallback
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
|   |   |   |-- notification_settings_page.dart # Reminder days, time, vibration, remote alerts
|   |   |-- services/
|   |   |   |-- profile_service.dart     # Avatar upload, name/email/password update
|   |   |   |-- notification_service.dart # Notification CRUD and sync
|   |   |   |-- notification_settings_service.dart # Reminder configuration
|   |   |   |-- global_reminder_service.dart # Per-task reminder scheduling bridge
|   |   |-- widgets/
|   |       |-- task_alert_item.dart     # Individual notification list item
|   |       |-- global_reminder_card.dart # Card displaying active global reminder schedule
|   |       |-- global_reminder_sheet.dart # Bottom sheet for editing reminder interval
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

| Goal | Command | Output or note |
| --- | --- | --- |
| Build release APK for direct installation | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Build ARM64-only APK | `flutter build apk --release --target-platform android-arm64` | Smaller APK for common Android devices |
| Build split APKs by ABI | `flutter build apk --release --split-per-abi` | Multiple APKs under `build/app/outputs/flutter-apk/` |
| Build Android App Bundle for Play Store | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| Generate launcher icons after asset changes | `dart run flutter_launcher_icons` | Updates generated launcher icon assets |

For Play Store releases that need Shorebird patch support, prefer the Shorebird release command in the next section instead of plain `flutter build appbundle --release`.

---

## Shorebird Release and Patch

Shorebird has been initialized for this Flutter app. The required config file is `shorebird.yaml`, and it is included as a Flutter asset in `pubspec.yaml`.

Do not write the Shorebird app ID in this README. Keep it in `shorebird.yaml` only.

| Goal | Command | Output or note |
| --- | --- | --- |
| Check Shorebird setup | `shorebird doctor` | Should report `No issues detected`. |
| Create Android release for Play Store | `shorebird release android` | Produces `build/app/outputs/bundle/release/app-release.aab`. |
| Create APK for manual testing | `shorebird release android --artifact apk` | Produces `build/app/outputs/flutter-apk/app-release.apk`. |
| Validate Android release without publishing | `shorebird release android --dry-run` | Useful before the real release command. |
| Patch an existing live Android release | `shorebird patch android` | Use only for patchable Dart/Flutter changes. |

If Shorebird reports that the release version already exists, bump the `version` field in `pubspec.yaml`, for example from `1.0.5+7` to `1.0.6+8`, then run the release command again.

| Change type | Can use Shorebird patch? | Required action |
| --- | --- | --- |
| Dart business logic | Yes | Run `shorebird patch android`. |
| Flutter UI, layout, text, or routing | Yes | Run `shorebird patch android`. |
| Native Android files under `android/` | No | Create a new Shorebird release and upload the new AAB to Play Store. |
| Gradle, signing config, or app permissions | No | Create a new Shorebird release and upload the new AAB to Play Store. |
| Plugin dependency changes with native code | No | Create a new Shorebird release and upload the new AAB to Play Store. |
| `google-services.json` or Firebase config changes | No | Create a new Shorebird release and upload the new AAB to Play Store. |
| Package name or application ID changes | No | Create a new Shorebird release and upload the new AAB to Play Store. |

---

## Feature Modules

### Authentication

- Welcome screen with onboarding introduction
- Login with email/password and client-side rate limiting (cooldown after repeated failures)
- Google Sign-In: one-tap authentication that creates or links an account by email
- Registration with name, email, password confirmation, and input validation
- Email verification: new accounts are held at a verification screen until a 6-digit OTP sent to the registered email is confirmed
- Forgot password flow: email entry, OTP verification, and new password submission across three dedicated screens
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


### Chat

- Conversation inbox for team and personal chats
- Chat room with message history, sender metadata, timestamps, and reply previews
- Message composer with multiline input, 2000-character guidance, mention suggestions, and send cooldown handling
- Message actions: reply, copy, edit within the allowed window, and delete for self or everyone when permitted
- Team mentions with `@all` and member-name highlighting
- Read-state updates through the backend and unread counters in the conversation list
- Local message cache through secure storage so recent conversations remain visible during transient network errors
- REST polling fallback for reliable message delivery when Firestore is unavailable or delayed
- Firebase Cloud Messaging integration for chat notifications outside the active conversation

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

### Image Cache

**WudiCacheManager** (`core/utils/image_cache_manager.dart`):
- Custom `CacheManager` instance shared by all `CachedNetworkImage` and `CachedNetworkImageProvider` widgets in the app
- Limit: 100 cached objects, 7-day stale period -- caps disk usage at approximately 50-100 MB under normal use
- Prevents unbounded cache growth that would otherwise reach hundreds of megabytes with GIF-heavy content
- Applied to: home header avatar, profile avatar, team avatars, group card team and member avatars, team detail member list

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
| Chat          | GET/POST/PATCH/DELETE `/chat/...`         | JWT         |
| Email Check   | GET `/users/check-email`                  | JWT         |

**Hybrid Auth** endpoints accept either JWT Bearer token (registered users) or X-Device-ID header (guest users). Chat endpoints require JWT authentication because conversations are tied to registered users and team membership.

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

## Google Sign-In and Android Signing

Google Sign-In depends on the package name and the certificate that signed the installed app. Do not document raw fingerprint values, API keys, OAuth client IDs, or app IDs in this README.

| File or console | Purpose | Security note |
| --- | --- | --- |
| `android/app/google-services.json` | Firebase and Android OAuth client config | Contains credential-like values; keep it out of public commits. |
| `android/key.properties` | Points Gradle to the upload keystore | Secret local signing config; keep it ignored. |
| `android/app/build.gradle.kts` | Defines package name and signing behavior | Debug/profile/release are configured to use the upload keystore locally. |
| Firebase Console | Stores SHA fingerprints for Android OAuth | Add fingerprints there, not in README. |
| Play Console, App integrity | Shows Play App Signing certificate | Required for Play Store/internal testing installs. |

Required Firebase fingerprint entries:

| Install path | Fingerprints needed in Firebase | Where to get them |
| --- | --- | --- |
| APK/AAB installed directly from local build | Upload key SHA-1 and SHA-256 | `cd android && bash ./gradlew :app:signingReport --console=plain` |
| App installed from Play Store/internal testing | Play App Signing SHA-1 and SHA-256 | Play Console, App integrity, App signing key certificate |

After adding or changing Firebase fingerprints:

| Step | Action |
| --- | --- |
| 1 | Download a fresh `google-services.json` from Firebase Console. |
| 2 | Replace `android/app/google-services.json`. |
| 3 | Run `cd android && bash ./gradlew :app:processReleaseGoogleServices --console=plain`. |
| 4 | Build a new Shorebird release and upload the new AAB to Play Store/internal testing. |

Google login flow:

| Step | Component | Behavior |
| --- | --- | --- |
| 1 | Login or welcome page | Runs `GoogleSignIn(scopes: ['email', 'profile']).signIn()`. |
| 2 | Google SDK | Returns account id, email, display name, and photo URL when account picker succeeds. |
| 3 | `AuthService.googleLogin()` | Clears stale auth session data, keeps device ID, then posts to `auth/google`. |
| 4 | Backend | Expects `google_id`, `email`, `name`, `avatar_url`, and optional `device_id`; not `id_token`. |
| 5 | Frontend | Stores JWT/user data and navigates into the app after backend success. |

Recent Google login related changes:

| Area | File | Change |
| --- | --- | --- |
| Signing | `android/app/build.gradle.kts` | Debug and profile builds use the release signing config so local builds use the registered upload key. |
| Auth service | `lib/features/auth/services/auth_service.dart` | Google login clears stale auth session data before the backend request. |
| Secure storage | `lib/core/storage/secure_storage.dart` | Added `clearAuthSession()` to clear auth cache without deleting the persistent device ID. |

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

### Google Sign-In Fails Before Backend Request

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| `ApiException: 10` or `DEVELOPER_ERROR` | OAuth/signing mismatch | Confirm the installed app uses package `com.pdbl.wudi` and its signing certificate is registered in Firebase/Google Cloud. |
| Local APK works but Play Store/internal testing fails | Missing Play App Signing fingerprint | Add Play App Signing SHA-1 and SHA-256 in Firebase, download a fresh `google-services.json`, then release a new AAB. |
| Account picker succeeds but login fails after that | Backend request or session handling | Check Dio logs and confirm `POST /api/auth/google` reaches the backend. |

Useful runtime checks:

| Purpose | Command |
| --- | --- |
| Capture Google login logs | `adb logcat \| grep -i -E "google\|signin\|ApiException\|DEVELOPER_ERROR\|auth/google\|DioException"` |
| Check signing variants | `cd android && bash ./gradlew :app:signingReport --console=plain` |
| Validate release Google services config | `cd android && bash ./gradlew :app:processReleaseGoogleServices --console=plain` |

### Offline Sync Not Working

1. Verify `connectivity_plus` detects network changes correctly
2. Check that the task repository sync logic runs on connectivity state change
3. Ensure the backend `/todos/bulk` endpoint is accessible

---

## License

MIT License. See [LICENSE](LICENSE) for details.
