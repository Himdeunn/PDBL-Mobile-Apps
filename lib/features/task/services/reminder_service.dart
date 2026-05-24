import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/notification_helper.dart';

class TaskReminder {
  final String unit; // 'D', 'W', 'M', 'Y'
  final int amount;
  final int hour;
  final int minute;

  const TaskReminder({
    required this.unit,
    required this.amount,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
    'unit': unit,
    'amount': amount,
    'hour': hour,
    'minute': minute,
  };

  factory TaskReminder.fromJson(Map<String, dynamic> json) => TaskReminder(
    unit: json['unit'] as String,
    amount: json['amount'] as int,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
  );

  String get label {
    final unitLabel = switch (unit) {
      'D' => amount == 1 ? '1 day' : '$amount days',
      'W' => amount == 1 ? '1 week' : '$amount weeks',
      'M' => amount == 1 ? '1 month' : '$amount months',
      'Y' => amount == 1 ? '1 year' : '$amount years',
      _ => '$amount $unit',
    };
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$unitLabel before — $h:$m';
  }

  Duration get duration {
    return switch (unit) {
      'D' => Duration(days: amount),
      'W' => Duration(days: amount * 7),
      'M' => Duration(days: amount * 30),
      'Y' => Duration(days: amount * 365),
      _ => Duration(days: amount),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TaskReminder &&
      other.unit == unit &&
      other.amount == amount &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(unit, amount, hour, minute);
}

class ReminderService {
  static const String _keyPrefix = 'task_reminders_';

  // Per-period limits to prevent notification spam
  static const int maxPerWeek = 20;
  static const int maxPerMonth = 50;
  static const int maxPerYear = 200;

  // Notification ID base offset for custom reminders (above the global deadline ones)
  // taskId * _baseMultiplier + reminderIndex
  static const int _baseMultiplier = 1000000;

  // ─── Storage ────────────────────────────────────────────────────────────────

  static Future<List<TaskReminder>> getRemindersForTask(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$taskId');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TaskReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveRemindersForTask(
    int taskId,
    List<TaskReminder> reminders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix$taskId',
      jsonEncode(reminders.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> clearRemindersForTask(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$taskId');
  }

  // ─── Limit checks ───────────────────────────────────────────────────────────

  /// Returns how many reminders are scheduled across ALL tasks
  /// within each period relative to [deadline].
  static Future<Map<String, int>> countScheduledInPeriods(
    DateTime deadline,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int week = 0, month = 0, year = 0;

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        final r = TaskReminder.fromJson(e as Map<String, dynamic>);
        // We count by how many reminders fire in each period window
        // A reminder's fire time is deadline - duration, at r.hour:r.minute
        final fireDate = deadline.subtract(r.duration);
        final fire = DateTime(
          fireDate.year,
          fireDate.month,
          fireDate.day,
          r.hour,
          r.minute,
        );
        if (fire.isAfter(now)) {
          if (!fire.isBefore(weekStart)) week++;
          if (!fire.isBefore(monthStart)) month++;
          if (!fire.isBefore(yearStart)) year++;
        }
      }
    }

    return {'week': week, 'month': month, 'year': year};
  }

  /// Check if adding [count] more reminders for [deadline] would exceed limits.
  /// Returns null if OK, or an error message if exceeded.
  static Future<String?> checkLimits(
    DateTime deadline, {
    int adding = 1,
  }) async {
    final counts = await countScheduledInPeriods(deadline);
    if ((counts['week']! + adding) > maxPerWeek) {
      return 'Weekly reminder limit reached ($maxPerWeek/week). Remove some reminders first.';
    }
    if ((counts['month']! + adding) > maxPerMonth) {
      return 'Monthly reminder limit reached ($maxPerMonth/month). Remove some reminders first.';
    }
    if ((counts['year']! + adding) > maxPerYear) {
      return 'Yearly reminder limit reached ($maxPerYear/year). Remove some reminders first.';
    }
    return null;
  }

  // ─── Scheduling ─────────────────────────────────────────────────────────────

  static Future<void> scheduleRemindersForTask({
    required int taskId,
    required String taskTitle,
    required DateTime deadline,
    required List<TaskReminder> reminders,
    String priority = 'medium',
    String? description,
  }) async {
    await cancelScheduledReminders(taskId);

    for (int i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      final fireDate = deadline.subtract(r.duration);
      final fire = DateTime(
        fireDate.year,
        fireDate.month,
        fireDate.day,
        r.hour,
        r.minute,
      );

      if (fire.isAfter(DateTime.now())) {
        await NotificationHelper.scheduleCustomReminder(
          id: taskId * _baseMultiplier + i,
          title: '⏰ Reminder: $taskTitle',
          body: 'Task due in ${r.label.split(' before').first}.',
          description: description,
          priority: priority,
          scheduledDate: fire,
          payload: 'task_$taskId',
        );
      }
    }

    await _saveRemindersForTask(taskId, reminders);
  }

  static Future<void> cancelScheduledReminders(int taskId) async {
    final reminders = await getRemindersForTask(taskId);
    final count = reminders.isEmpty ? 10 : reminders.length;
    for (int i = 0; i < count; i++) {
      await NotificationHelper.cancelById(taskId * _baseMultiplier + i);
    }
  }

  static Future<void> deleteRemindersForTask(int taskId) async {
    await cancelScheduledReminders(taskId);
    await clearRemindersForTask(taskId);
  }
}
