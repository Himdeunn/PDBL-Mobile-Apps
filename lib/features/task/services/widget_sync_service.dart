import 'dart:convert';
import 'package:home_widget/home_widget.dart';

class WidgetSyncService {
  static Future<void> syncFocusTodayWidget(List<dynamic> allTasks) async {
    final now = DateTime.now();

    final todayTasks = allTasks.where((task) {
      if (task.dueDate == null) return false;
      if (task.dueDate!.year != now.year ||
          task.dueDate!.month != now.month ||
          task.dueDate!.day != now.day) {
        return false;
      }

      final dueDateTime = _combineDateAndTime(task.dueDate!, task.dueTime);
      return dueDateTime == null || dueDateTime.isAfter(now);
    }).toList();

    final taskJsonByKey = <String, Map<String, dynamic>>{};

    for (final t in todayTasks) {
      final isTeam = t.teamId != null;
      final isLocked = isTeam && t.leaderChecked == true;
      final widgetKey = isTeam && t.apiId != null
          ? 'team:${t.apiId}'
          : 'personal:${t.id}';

      taskJsonByKey[widgetKey] = {
        'widgetKey': widgetKey,
        'id': t.id.toString(),
        'title': t.title ?? '',
        'dueTime': t.dueTime ?? '',
        'priority': t.priority ?? 'medium',
        'isTeam': isTeam,
        'isCompleted': t.isCompleted == true || isLocked,
        'isLocked': isLocked,
        'team_id': t.teamId?.toString() ?? '',
      };
    }

    final taskJsonList = taskJsonByKey.values.toList();

    await HomeWidget.saveWidgetData<String>(
      'focus_today_tasks',
      jsonEncode(taskJsonList),
    );

    // Force notify both the provider AND the list view data changed
    await HomeWidget.updateWidget(
      name: 'FocusTodayWidgetProvider',
      androidName: 'FocusTodayWidgetProvider',
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
}
