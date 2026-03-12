# WUDI - Task Management Application

WUDI is a cross-platform task management application developed with Flutter, designed to facilitate efficient daily productivity and team collaboration. The application features a premium user interface with real-time data synchronization, comprehensive calendar integration, and automated guest-to-user data migration.

## Primary Features

- **Task Management**: Full CRUD capabilities for tasks including detailed descriptions, deadline management, and multi-level priority categorization (Low, Medium, High).
- **Collaboration and Team Management**: Dedicated infrastructure for creating and managing project teams. Features include member invitations via email, role-based member management (Owner/Member), and administrative actions such as removing or banning members.
- **Shared Project Tasks**: Collaborative task lists within team contexts. Members can assign tasks to specific colleagues, track completion status with optimistic UI updates, and perform collaborative edits.
- **Calendar Integration**: Temporal visualization of tasks with color-coded priority indicators and interactive monthly navigation.
- **Unified Dashboard**: Daily task overview featuring a continuous week-strip for rapid date-based browsing.
- **Guest Access**: Full application functionality without mandatory authentication. Local data is identified via unique Device IDs and prepared for future synchronization.
- **Account Synchronization**: Secure user authentication allowing multi-device data parity. Local guest data is automatically merged with user accounts upon successful login.
- **Offline-First Architecture**: Persistent local storage implemented with the Isar database engine. The application maintains full functionality without active internet connectivity and synchronizes changes once the connection is restored.
- **Optimistic UI Updates**: Instant state transitions for critical actions such as task completion, ensuring a highly responsive user experience.
- **Contextual Actions**: Intuitive swipe-based interactions for rapid task modification or removal.
- **Global Search**: High-performance filtering of task entries directly from the primary navigation layer.

## Technical Architecture

| Component         | Implementation            |
|-------------------|---------------------------|
| Mobile Framework  | Flutter (Dart)            |
| Local Persistence | Isar Database 3.1.0       |
| Network Layer     | Dio                       |
| State Management  | Reactive Streams          |
| Authentication    | Flutter Secure Storage    |
| Backend Engine    | Laravel + Sanctum         |
| Communication     | RESTful JSON API          |

## Project Directory Overview

```text
lib/
  core/
    network/        # API integration and network middleware
    storage/        # Local database and secure credential management
    theme/          # Design system, specialized UI components, and styling
  features/
    auth/           # Identity management and authentication services
    calendar/       # Date-based task visualization and management
    group/          # Team collaboration, member management, and shared tasks
    home/           # Primary dashboard and temporal navigation
    shell/          # Application scaffolding and primary navigation
    task/           # Personal task processing and data repository logic
```

## Setup and Deployment

### Technical Prerequisites

- Flutter SDK (Version 3.11.0 or higher)
- Android Studio or Visual Studio Code with Flutter plugins
- Access to the PDBL-BACKEND API service

### Installation Procedure

1. Obtain the source code:
   ```bash
   git clone https://github.com/Himdeunn/PDBL-Mobile-Apps.git
   cd PDBL-Mobile-Apps
   git checkout fajar_Branch
   ```

2. Configure environment variables in a `.env` file at the root directory:
   ```text
   API_URL=https://api.example.com/api
   ```

3. Initialize dependencies:
   ```bash
   flutter pub get
   ```

4. Generate database schemas:
   ```bash
   dart run build_runner build
   ```

5. Execute the development build:
   ```bash
   flutter run
   ```

### Production Build Processes

```bash
# Architecture-specific APK (Recommended for direct distribution)
flutter build apk --target-platform android-arm64

# Multi-ABI Split APKs
flutter build apk --split-per-abi

# Android App Bundle (Recommended for Play Store distribution)
flutter build appbundle
```

## API Specification

The application integrates with the Laravel backend via a structured REST API:

| Interaction | Endpoint                | Purpose                        | Security      |
|-------------|-------------------------|--------------------------------|---------------|
| POST        | /api/register           | User Account Creation          | Public        |
| POST        | /api/login              | Authentication                 | Public        |
| POST        | /api/logout             | Session Termination            | Authenticated |
| GET         | /api/todos              | Retrieve Task History          | Identifier    |
| POST        | /api/todos              | Append New Task                | Identifier    |
| PUT         | /api/todos/{id}         | Modify Existing Entry          | Identifier    |
| DELETE      | /api/todos/{id}         | Remove Task Entry              | Identifier    |
| GET         | /api/teams              | List All Enrolled Teams        | Authenticated |
| POST        | /api/teams              | Initialize New Project Team    | Authenticated |
| GET         | /api/teams/{id}         | Fetch Team Details and Tasks   | Authenticated |
| PUT         | /api/teams/{id}         | Update Team Profile            | Authenticated |
| DELETE      | /api/teams/{id}         | Disband Project Team           | Authenticated |
| POST        | /api/teams/{id}/invite  | Dispatch Member Invitation     | Authenticated |
| POST        | /api/teams/{id}/accept  | Accept Project Invitation      | Authenticated |
| POST        | /api/teams/{id}/decline | Decline Project Invitation     | Authenticated |
| DELETE      | /api/teams/{id}/members/{uid}| Evict Team Member         | Authenticated |
| POST        | /api/teams/{id}/members/{uid}/ban| Restrict Member Access | Authenticated |

Note: Identifier-based endpoints utilize either a Bearer token or an X-Device-ID header for operation.

## Troubleshooting

### API Connectivity in Production Builds
If the application fails to connect to the backend after a release build (APK), verify that the `AndroidManifest.xml` includes the necessary network permissions. The application requires these to communicate over the internet:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## License

This software is distributed under the MIT License. Refer to the [LICENSE](LICENSE) file for complete terms.
