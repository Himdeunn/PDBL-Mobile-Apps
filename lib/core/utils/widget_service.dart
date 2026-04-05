import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../../features/task/models/task_local.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/task/services/task_repository.dart';
import '../../features/group/services/team_service.dart';
import '../../features/task/pages/task_page.dart';
import '../../features/group/pages/team_detail_page.dart';
import 'navigator_service.dart';

class WidgetService {
  static const String _androidWidgetName = 'WidgetProvider';

  static Future<void> init() async {
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

    final taskId = uri.queryParameters['id'];
    final type = uri.queryParameters['type']; // 'personal' or 'team'
    final teamId = uri.queryParameters['team_id'];
    
    // Handle Login Redirection
    if (uri.host == 'login') {
      NavigatorService.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    if (type == 'personal') {
      NavigatorService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => TaskPage(taskId: taskId),
        ),
      );
    } else if (type == 'team' && teamId != null) {
      NavigatorService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => TeamDetailPage(
            teamId: int.parse(teamId),
            taskId: taskId,
          ),
        ),
      );
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

    if (personalTasks != null) {
      final tasksJson = personalTasks.map((t) => {
        'id': t.id.toString(),
        'title': t.title,
        'description': t.description ?? '',
        'date': t.dueDate != null ? '${t.dueDate!.day}/${t.dueDate!.month}/${t.dueDate!.year}' : '',
        'time': t.dueTime ?? '',
        'priority': t.priority,
      }).toList();
      await HomeWidget.saveWidgetData<String>('personal_tasks', jsonEncode(tasksJson));
    }

    if (teamTasks != null) {
      final tasksJson = teamTasks.map((t) => {
        'id': t['id'].toString(),
        'team_id': t['team_id']?.toString() ?? '', // Important for redirection
        'title': t['judul'] ?? t['title'] ?? '',
        'description': t['deskripsi'] ?? t['description'] ?? '',
        'date': t['deadline'] != null ? t['deadline'].toString().split(' ')[0] : '',
        'time': t['deadline'] != null && t['deadline'].toString().contains(' ') 
            ? t['deadline'].toString().split(' ')[1] 
            : '',
        'priority': t['priority'] ?? 'low',
      }).toList();
      await HomeWidget.saveWidgetData<String>('team_tasks', jsonEncode(tasksJson));
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
      // ... (rest of the logic)
      final isLoggedIn = user != null && !user.isGuest;
      
      List<TaskLocal>? personalTasks;
      List<dynamic> allTeamTasks = [];
      bool hasTeam = false;

      // Fetch personal tasks
      if (user != null) {
        final repository = TaskRepository();
        personalTasks = await repository.getAllTasks(user.isGuest ? 'guest' : user.email ?? '');
      }

      // Fetch team tasks if logged in
      if (isLoggedIn) {
        try {
          final teamService = TeamService();
          final dashboardData = await teamService.getDashboardData();
          final teams = dashboardData['teams'] as List?;
          hasTeam = teams != null && teams.isNotEmpty;
          
          if (hasTeam) {
              for (var team in teams) {
                  try {
                      final teamId = int.tryParse(team['id'].toString());
                      if (teamId == null) continue;
                      
                      final details = await teamService.getTeamDetails(teamId);
                      final tasks = details['tasks'] as List? ?? [];
                      // Inject team_id if missing for redirection
                      for (var task in tasks) {
                        task['team_id'] = teamId;
                      }
                      allTeamTasks.addAll(tasks);
                  } catch (_) {}
              }
          }
        } catch (e) {}
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
