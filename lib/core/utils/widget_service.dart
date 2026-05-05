import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../../features/task/models/task_local.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/task/services/task_repository.dart';
import '../../features/group/services/team_service.dart';
import '../../features/task/pages/task_page.dart';
import '../../features/task/pages/create_task_page.dart';
import '../../features/group/pages/team_detail_page.dart';
import 'navigator_service.dart';
import '../../features/task/services/widget_sync_service.dart';

class WidgetService {
  static const String _androidWidgetName = 'WidgetProvider';

  static Future<void> init() async {
    // Pastikan Flutter menggunakan group yang sama dengan Android agar data sinkron
    await HomeWidget.setAppGroupId('HomeWidgetPreferences');

    // Handle clicks when app is already running
    HomeWidget.widgetClicked.listen((Uri? uri) {
      _handleWidgetClick(uri);
    });

    // Handle initial launch from widget
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) {
      _handleWidgetClick(initialUri);
    }
  }

  static void _handleWidgetClick(Uri? uri) {
    if (uri == null || uri.scheme != 'home_widget') return;

    final taskIdStr = uri.queryParameters['id'];
    final teamId = uri.queryParameters['team_id'];
    final isTeamStr = uri.queryParameters['isTeam'];

    if (uri.host == 'toggle_task' && taskIdStr != null) {
      _handleToggleBackground(int.parse(taskIdStr));
      return;
    }

    // Polling mechanism to ensure Navigator is ready
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      attempts++;
      final navigator = NavigatorService.navigatorKey.currentState;
      
      if (navigator != null) {
        timer.cancel();
        if (uri.host == 'add_task') {
          navigator.push(
            MaterialPageRoute(builder: (_) => const CreateTaskPage()),
          );
        } else if (uri.host == 'task_detail' && taskIdStr != null) {
          final taskId = int.parse(taskIdStr);
          final isTeam = isTeamStr == 'true';
          
          if (isTeam && teamId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => TeamDetailPage(teamId: int.parse(teamId)),
              ),
            );
          } else {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => TaskPage(taskId: taskId.toString()),
              ),
            );
          }
        }
      } else if (attempts >= 15) { // Timeout after 3 seconds
        timer.cancel();
        debugPrint("WUDI_WIDGET_ERROR: Navigator timeout for ${uri.host}");
      }
    });
  }

  static Future<void> _handleToggleBackground(int taskId) async {
    try {
      final repository = TaskRepository();
      final user = await SecureStorage.getUser();
      final userEmail = user?.email ?? 'guest';
      
      // Fetch the most up-to-date tasks from the repository
      final allTasks = await repository.getAllTasks(userEmail);
      
      final task = allTasks.where((t) => t.id == taskId).firstOrNull;
      if (task != null) {
        // Toggle the status (this already triggers WidgetSyncService in most cases)
        await repository.toggleTaskStatus(task, userEmail);
        
        // Explicitly sync the widget again to be absolutely sure the UI updates immediately
        final updatedTasks = await repository.getAllTasks(userEmail);
        await WidgetSyncService.syncFocusTodayWidget(updatedTasks);
      }
    } catch (e) {
      debugPrint("WUDI_WIDGET_ERROR (Toggle): $e");
    }
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
      final List<Map<String, dynamic>> combinedTasks = [];
      
      if (personalTasks != null) {
        combinedTasks.addAll(personalTasks.map((t) => {
          'id': t.id.toString(),
          'title': t.title,
          'dueTime': t.dueTime ?? '',
          'priority': t.priority,
          'isTeam': false,
          'isCompleted': t.isCompleted,
        }));
      }

      if (teamTasks != null) {
        combinedTasks.addAll(teamTasks.map((t) => {
          'id': t['id']?.toString() ?? '',
          'title': t['judul'] ?? t['title'] ?? '',
          'dueTime': t['deadline'] != null && t['deadline'].toString().contains(' ') 
              ? t['deadline'].toString().split(' ')[1] 
              : '',
          'priority': t['priority'] ?? 'low',
          'isTeam': true,
          'team_id': t['team_id']?.toString() ?? '',
          'isCompleted': t['is_completed'] == true,
        }));
      }

      final jsonStr = jsonEncode(combinedTasks);
      await HomeWidget.saveWidgetData<String>('focus_today_tasks', jsonStr);
    }

    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
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
      if (user != null) {
        final repository = TaskRepository();
        final email = user.isGuest ? 'guest' : (user.email ?? '');
        personalTasks = await repository.getAllTasks(email);

        // Fallback: If no tasks found for email, check if there are tasks marked as 'guest'
        if ((personalTasks == null || personalTasks.isEmpty) && email != 'guest') {
           final guestTasks = await repository.getAllTasks('guest');
           if (guestTasks.isNotEmpty) {
             personalTasks = guestTasks;
           }
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
              for (var team in teams!) {
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
