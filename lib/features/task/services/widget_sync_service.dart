import 'dart:convert';
import 'package:home_widget/home_widget.dart';

class WidgetSyncService {
  static Future<void> syncFocusTodayWidget(List<dynamic> allTasks) async {
    final now = DateTime.now();
    
    final todayTasks = allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.year == now.year &&
             task.dueDate!.month == now.month &&
             task.dueDate!.day == now.day;
    }).toList();

    final List<Map<String, dynamic>> taskJsonList = todayTasks.map((t) => {
      'id': t.id.toString(),
      'title': t.title ?? '',
      'dueTime': t.dueTime ?? '',
      'priority': t.priority ?? 'medium',
      'isTeam': (t.teamId != null) ? true : false,
      'isCompleted': t.isCompleted == true,
      'team_id': t.teamId?.toString() ?? '',
    }).toList();

    await HomeWidget.saveWidgetData<String>('focus_today_tasks', jsonEncode(taskJsonList));
    
    // Force notify both the provider AND the list view data changed
    await HomeWidget.updateWidget(
      name: 'FocusTodayWidgetProvider',
      androidName: 'FocusTodayWidgetProvider',
    );
  }
}