import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import '../../features/task/models/task_local.dart';
import '../storage/secure_storage.dart';
import '../../features/task/services/task_repository.dart';
import '../../features/group/services/team_service.dart';
import '../../features/task/pages/create_task_page.dart';
import '../../features/group/pages/team_detail_page.dart';
import '../../features/auth/services/auth_service.dart';
import '../storage/local_database.dart';
import 'navigator_service.dart';
import '../../features/task/services/widget_sync_service.dart';

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('HomeWidgetPreferences');
  if (uri?.scheme == 'wudi-widget' && uri?.host == 'toggle-task') {
    await WidgetService.handleBackgroundAction(uri!);
  }
}

class WidgetService {
  static const String _androidWidgetName = 'FocusTodayWidgetProvider';
  static Uri? _pendingLaunchUri;
  static final StreamController<void> _dashboardRequestController =
      StreamController<void>.broadcast();

  static Stream<void> get dashboardRequested =>
      _dashboardRequestController.stream;

  static Future<void> init() async {
    // Pastikan Flutter menggunakan group yang sama dengan Android agar data sinkron
    await HomeWidget.setAppGroupId('HomeWidgetPreferences');

    // Handle clicks when app is already running
    HomeWidget.widgetClicked.listen((Uri? uri) {
      _handleWidgetClick(uri);
    });

    // Register background callback for checkbox/background actions
    await HomeWidget.registerBackgroundCallback(homeWidgetBackgroundCallback);

    // Handle initial launch from widget
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) {
      _pendingLaunchUri = initialUri;
    }
  }

  static Uri? claimPendingLaunchUri() {
    final uri = _pendingLaunchUri;
    _pendingLaunchUri = null;
    return uri;
  }

  static void handleWidgetClick(Uri? uri) {
    _handleWidgetClick(uri);
  }

  static void _handleWidgetClick(Uri? uri) {
    if (uri == null || uri.scheme != 'wudi-widget') return;

    final taskIdStr = uri.queryParameters['id'];
    final teamId = uri.queryParameters['team_id'];
    final isTeamStr = uri.queryParameters['isTeam'];

    if (uri.host == 'toggle-task' && taskIdStr != null) {
      final taskId = int.tryParse(taskIdStr);
      if (taskId == null) {
        debugPrint("WUDI_WIDGET_ERROR: Invalid toggle task id $taskIdStr");
        return;
      }

      _handleToggleBackground(taskId, alreadyToggledInWidget: true);
      return;
    }

    _navigateFromWidgetUri(uri, taskIdStr, teamId, isTeamStr);
  }

  static void _navigateFromWidgetUri(
    Uri uri,
    String? taskIdStr,
    String? teamId,
    String? isTeamStr,
  ) {
    // Polling mechanism to ensure Navigator is ready
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      attempts++;
      final navigator = NavigatorService.navigatorKey.currentState;
      
      if (navigator != null) {
        timer.cancel();
        if (uri.host == 'add-task') {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => CreateTaskPage(authService: AuthService()),
            ),
            (route) => route.isFirst,
          );
        } else if (uri.host == 'task-detail' && taskIdStr != null) {
          final taskId = int.tryParse(taskIdStr);
          if (taskId == null) {
            debugPrint("WUDI_WIDGET_ERROR: Invalid detail task id $taskIdStr");
            return;
          }
          final isTeam = isTeamStr == 'true';
          
          if (isTeam && teamId != null) {
            final parsedTeamId = int.tryParse(teamId);
            if (parsedTeamId == null) {
              debugPrint("WUDI_WIDGET_ERROR: Invalid team id $teamId");
              return;
            }

            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => TeamDetailPage(teamId: parsedTeamId),
              ),
              (route) => route.isFirst,
            );
          } else {
            _dashboardRequestController.add(null);
            navigator.popUntil((route) => route.isFirst);
          }
        }
      } else if (attempts >= 15) { // Timeout after 3 seconds
        timer.cancel();
        debugPrint("WUDI_WIDGET_ERROR: Navigator timeout for ${uri.host}");
      }
    });
  }

  static Future<void> handleBackgroundAction(Uri uri) async {
    if (uri.host == 'toggle-task') {
      final taskIdStr = uri.queryParameters['id'];
      final widgetKey = uri.queryParameters['widget_key'];
      if (taskIdStr != null) {
        final taskId = int.tryParse(taskIdStr);
        if (taskId == null) {
          debugPrint("WUDI_WIDGET_ERROR: Invalid background task id $taskIdStr");
          return;
        }

        debugPrint("WUDI_WIDGET_SYNC: Background toggle received for task $taskIdStr");
        // We need to ensure Isar/LocalDB is initialized in the background isolate
        await LocalDatabase.init();
        await _handleToggleBackground(taskId, widgetKey: widgetKey, alreadyToggledInWidget: true);
      }
    }
  }

  static Future<void> _handleToggleBackground(
    int taskId, {
    String? widgetKey,
    bool alreadyToggledInWidget = false,
  }) async {
    try {
      final user = await SecureStorage.getUser();
      final userEmail = user?.email ?? 'guest';
      debugPrint("WUDI_WIDGET_SYNC: Loading DB task $taskId for $userEmail");

      final isar = LocalDatabase.isar;
      final task = await _findWidgetTask(isar, taskId, widgetKey);
      if (task != null) {
        if (task.userEmail != userEmail) {
          debugPrint("WUDI_WIDGET_SYNC: Task $taskId belongs to ${task.userEmail}, not $userEmail");
          return;
        }

        if (alreadyToggledInWidget) {
          debugPrint("WUDI_WIDGET_SYNC: Widget cache already toggled for task $taskId");
        }

        if (task.teamId != null) {
          await _syncTeamToggleFromWidget(task, userEmail, isar);
          return;
        }

        await isar.writeTxn(() async {
          final fresh = await isar.taskLocals.get(taskId);
          if (fresh == null) return;
          fresh.isCompleted = !fresh.isCompleted;
          fresh.isSynced = false;
          fresh.lastLocalUpdate = DateTime.now().millisecondsSinceEpoch;
          await isar.taskLocals.put(fresh);
        });

        final updatedTasks = await isar.taskLocals
            .filter()
            .userEmailEqualTo(userEmail)
            .findAll();
        await WidgetSyncService.syncFocusTodayWidget(updatedTasks);
        debugPrint("WUDI_WIDGET_SYNC: Synced task $taskId to DB/widget");
      } else {
        if (widgetKey != null && widgetKey.startsWith('team:')) {
          final apiId = int.tryParse(widgetKey.substring('team:'.length));
          if (apiId != null) {
            await _syncTeamToggleByApiId(apiId, userEmail, isar);
            return;
          }
        }

        debugPrint("WUDI_WIDGET_SYNC: Task $taskId not found in DB for $userEmail");
      }
    } catch (e) {
      debugPrint("WUDI_WIDGET_ERROR (Toggle): $e");
    }
  }

  static Future<TaskLocal?> _findWidgetTask(Isar isar, int taskId, String? widgetKey) async {
    if (widgetKey != null && widgetKey.startsWith('team:')) {
      final apiId = int.tryParse(widgetKey.substring('team:'.length));
      if (apiId != null) {
        final task = await isar.taskLocals.filter().apiIdEqualTo(apiId).findFirst();
        if (task != null) return task;
      }
    }

    return isar.taskLocals.get(taskId);
  }

  static Future<void> _syncTeamToggleFromWidget(
    TaskLocal task,
    String userEmail,
    Isar isar,
  ) async {
    if (task.apiId == null) {
      debugPrint("WUDI_WIDGET_SYNC: Team task ${task.id} has no API id");
      return;
    }

    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: ".env");
    }

    final response = await TeamService().toggleMemberTaskStatus(task.apiId!);
    final todoData = response['todo'];
    if (todoData is! Map) {
      debugPrint("WUDI_WIDGET_SYNC: Team task ${task.id} returned no todo data");
      return;
    }

    await _applyTeamTodoToLocalTask(task, todoData, userEmail, isar);

    final updatedTasks = await isar.taskLocals
        .filter()
        .userEmailEqualTo(userEmail)
        .findAll();
    await WidgetSyncService.syncFocusTodayWidget(updatedTasks);
    await TaskRepository().fetchTasksFromServer(userEmail, force: true);
    await fullSync();
    debugPrint("WUDI_WIDGET_SYNC: Synced team task ${task.id} to API/DB/widget");
  }

  static Future<void> _syncTeamToggleByApiId(
    int apiId,
    String userEmail,
    Isar isar,
  ) async {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: ".env");
    }

    final response = await TeamService().toggleMemberTaskStatus(apiId);
    final todoData = response['todo'];
    if (todoData is! Map) {
      debugPrint("WUDI_WIDGET_SYNC: Team API task $apiId returned no todo data");
      return;
    }

    final existing = await isar.taskLocals.filter().apiIdEqualTo(apiId).findFirst();
    if (existing != null) {
      await _applyTeamTodoToLocalTask(existing, todoData, userEmail, isar);
    }

    await TaskRepository().fetchTasksFromServer(userEmail, force: true);
    await fullSync();
    debugPrint("WUDI_WIDGET_SYNC: Synced team API task $apiId and refreshed widget");
  }

  static Future<void> _applyTeamTodoToLocalTask(
    TaskLocal task,
    Map<dynamic, dynamic> todoData,
    String userEmail,
    Isar isar,
  ) async {
    final completedByRaw = todoData['completed_by'];
    final completedBy = completedByRaw is List ? completedByRaw : <dynamic>[];
    final assignedEmailsRaw = todoData['assigned_emails'];
    final assignedEmails = assignedEmailsRaw is List ? assignedEmailsRaw : <dynamic>[];
    final assignedEmailValues = assignedEmails
        .map((e) => e.toString().toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final completedByNormalized = completedBy
        .map((e) => e.toString().toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final userEmailNormalized = userEmail.toLowerCase().trim();
    final isFullyCompleted = todoData['is_completed'] == true;
    final myEmailChecked = completedByNormalized.contains(userEmailNormalized);

    await isar.writeTxn(() async {
      final fresh = await isar.taskLocals.get(task.id);
      if (fresh == null) return;
      fresh.isCompleted = isFullyCompleted || myEmailChecked;
      fresh.leaderChecked = isFullyCompleted && !myEmailChecked;
      fresh.completedBy = completedByNormalized.isEmpty
          ? null
          : completedByNormalized.join(',');
      fresh.totalAssigned = assignedEmails.length;
      if (assignedEmailValues.isNotEmpty) {
        fresh.assignedEmails = assignedEmailValues.join(',');
      }
      fresh.isSynced = true;
      await isar.taskLocals.put(fresh);
    });
  }

  static Future<void> updateWidgetData({
    List<TaskLocal>? personalTasks,
    List<dynamic>? teamTasks,
    bool? isLoggedIn,
    bool? hasTeam,
  }) async {
    if (isLoggedIn != null) {
      await HomeWidget.saveWidgetData<bool>('is_logged_in', isLoggedIn);
    }

    if (hasTeam != null) {
      await HomeWidget.saveWidgetData<bool>('has_team', hasTeam);
    }

    // REMOVED current_tab saving from Flutter to avoid overwriting native state

      if (personalTasks != null || teamTasks != null) {
      final combinedTasksByKey = <String, Map<String, dynamic>>{};
      final now = DateTime.now();
      
      if (personalTasks != null) {
        // Filter for today's tasks only
        final todayPersonal = personalTasks.where((t) {
           if (t.dueDate == null) return false;
           if (t.dueDate!.year != now.year ||
               t.dueDate!.month != now.month ||
               t.dueDate!.day != now.day) {
             return false;
           }

           final dueDateTime = _combineDateAndTime(t.dueDate!, t.dueTime);
           return dueDateTime == null || dueDateTime.isAfter(now);
        }).toList();

        for (final t in todayPersonal) {
          final isTeam = t.teamId != null;
          final isLocked = isTeam && t.leaderChecked == true;
          final widgetKey = isTeam && t.apiId != null
              ? 'team:${t.apiId}'
              : 'personal:${t.id}';

          combinedTasksByKey[widgetKey] = {
          'widgetKey': widgetKey,
          'id': t.id.toString(),
          'title': t.title,
          'dueTime': t.dueTime ?? '',
          'priority': t.priority,
          'isTeam': isTeam,
          'team_id': t.teamId?.toString() ?? '',
          'isCompleted': t.isCompleted || isLocked,
          'isLocked': isLocked,
        };
        }
      }

      if (teamTasks != null) {
        final userEmail = (await SecureStorage.getUser())?.email?.toLowerCase().trim();
        // Filter for today's team tasks
        final todayTeam = teamTasks.where((t) {
            if (t['deadline'] == null) return false;
            try {
              final dt = DateTime.parse(t['deadline'].toString());
              return dt.year == now.year &&
                  dt.month == now.month &&
                  dt.day == now.day &&
                  dt.isAfter(now);
            } catch (_) { return false; }
        }).toList();

        for (final t in todayTeam) {
          final apiId = t['id']?.toString() ?? '';
          if (apiId.isEmpty) continue;
          final widgetKey = 'team:$apiId';
          final completedByRaw = t['completed_by'];
          final completedBy = completedByRaw is List ? completedByRaw : <dynamic>[];
          final assignedEmailsRaw = t['assigned_emails'];
          final assignedEmails = assignedEmailsRaw is List ? assignedEmailsRaw : <dynamic>[];
          final isAssignedToMe = userEmail != null && assignedEmails.any(
            (e) => e.toString().toLowerCase().trim() == userEmail,
          );
          if (!isAssignedToMe) continue;

          final isFullyCompleted = t['is_completed'] == true;
          final myEmailChecked = completedBy.any(
            (e) => e.toString().toLowerCase().trim() == userEmail,
          );
          final deadline = DateTime.parse(t['deadline'].toString());

          combinedTasksByKey[widgetKey] = {
          'widgetKey': widgetKey,
          'id': combinedTasksByKey[widgetKey]?['id'] ?? apiId,
          'title': t['judul'] ?? t['title'] ?? '',
          'dueTime': _formatWidgetTime(deadline),
          'priority': t['priority'] ?? 'low',
          'isTeam': true,
          'team_id': t['team_id']?.toString() ?? '',
          'isCompleted': isFullyCompleted || myEmailChecked,
          'isLocked': isFullyCompleted && !myEmailChecked,
        };
        }
      }

      final combinedTasks = combinedTasksByKey.values.toList();
      final jsonStr = jsonEncode(combinedTasks);
      debugPrint("WUDI_WIDGET_FLUTTER: Saving focus_today_tasks (${combinedTasks.length} items)");
      await HomeWidget.saveWidgetData<String>('focus_today_tasks', jsonStr);
    }

    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }

  static DateTime? _combineDateAndTime(DateTime date, String? dueTime) {
    if (dueTime == null || dueTime.trim().isEmpty) return null;

    final parts = dueTime.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    if (hour == null || minute == null) return null;

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  static String _formatWidgetTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static int _syncCount = 0;
  static bool _syncing = false;

  static Future<void> fullSync() async {
    // Basic debounce: if a sync is already in progress, just mark that another one is needed
    // or simply skip if it's too frequent. For now, simple skipping if already syncing.
    if (_syncing) {
       _syncCount++;
       return;
    }

    _syncing = true;
    try {
      final user = await SecureStorage.getUser();
      final isLoggedIn = user != null && !user.isGuest;

      List<TaskLocal>? personalTasks;
      List<dynamic> allTeamTasks = [];
      bool hasTeam = false;

      // Fetch personal tasks
      final repository = TaskRepository();
      final email = (user == null || user.isGuest) ? 'guest' : (user.email ?? 'guest');
      personalTasks = await repository.getAllTasks(email);

      // Fallback: If no tasks found for email, check if there are tasks marked as 'guest'
      if ((personalTasks.isEmpty) && email != 'guest') {
          final guestTasks = await repository.getAllTasks('guest');
          if (guestTasks.isNotEmpty) {
            personalTasks = guestTasks;
          }
      }

      // Fetch team tasks if logged in
      if (isLoggedIn) {
        try {
          final teamService = TeamService();
          final dashboardData = await teamService.getDashboardData();
          final teams = dashboardData['teams'] as List? ?? dashboardData['data']?['teams'] as List?;
          hasTeam = teams != null && teams.isNotEmpty;

          if (hasTeam) {
              for (var team in teams) {
                  try {
                      final teamId = int.tryParse(team['id'].toString());
                      if (teamId == null) continue;

                      final details = await teamService.getTeamDetails(teamId);
                      final tasks = details['tasks'] as List? ?? details['data']?['tasks'] as List? ?? [];

                      // Inject team_id if missing for redirection
                      for (var task in tasks) {
                        task['team_id'] = teamId;
                      }
                      allTeamTasks.addAll(tasks);
                  } catch (e) {
                      debugPrint("WUDI_WIDGET_ERROR (Team Loop): $e");
                  }
              }
          }
        } catch (e) {
            debugPrint("WUDI_WIDGET_ERROR (Team Fetch): $e");
        }
      }

      // Final consolidated update
      await updateWidgetData(
        personalTasks: personalTasks,
        teamTasks: allTeamTasks,
        isLoggedIn: isLoggedIn,
        hasTeam: hasTeam,
      );
    } catch (e) {
      // Silently fail
    } finally {
      _syncing = false;
      // If a sync was requested during an active sync, run it once more at the end
      if (_syncCount > 0) {
        _syncCount = 0;
        fullSync();
      }
    }
  }
}
