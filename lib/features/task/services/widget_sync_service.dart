import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/task_local.dart';

class WidgetSyncService {
  static Future<void> syncFocusTodayWidget(List<dynamic> allTasks) async {
    final now = DateTime.now();
    
    // 1. Ambil task HANYA untuk hari ini & yang belum selesai
    final todayTasks = allTasks.where((task) {
      if (task.dueDate == null || task.isCompleted == true) return false;
      return task.dueDate!.year == now.year &&
             task.dueDate!.month == now.month &&
             task.dueDate!.day == now.day;
    }).toList();

    // 2. Format jadi List of Map/JSON, gabungkan semua dan kasih tanda isTeam
    final List<Map<String, dynamic>> taskJsonList = todayTasks.map((t) => {
      'title': t.title ?? '',
      'dueTime': t.dueTime ?? '',
      'priority': t.priority ?? 'medium',
      'isTeam': (t.teamId != null) ? true : false,
    }).toList();

    // 3. Simpan ke sistem Android SharedPreferences milik HomeWidget
    await HomeWidget.saveWidgetData<String>('focus_today_tasks', jsonEncode(taskJsonList));
    
    // 4. Trigger Widget Update
    await HomeWidget.updateWidget(
      name: 'FocusTodayWidgetProvider',
      androidName: 'FocusTodayWidgetProvider',
    );
  }
}