import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/notification_helper.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../features/task/models/task_local.dart';
import '../../../features/task/services/task_repository.dart';
import 'global_reminder_scheduler.dart';

/// Type of tasks this reminder applies to.
enum ReminderTaskType { individual, team, all }

extension ReminderTaskTypeX on ReminderTaskType {
  String get label {
    switch (this) {
      case ReminderTaskType.individual:
        return 'Individual Task';
      case ReminderTaskType.team:
        return 'Team Task';
      case ReminderTaskType.all:
        return 'All Tasks';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderTaskType.individual:
        return Icons.person_outline;
      case ReminderTaskType.team:
        return Icons.groups_outlined;
      case ReminderTaskType.all:
        return Icons.checklist_outlined;
    }
  }

  String get key => name; // 'individual', 'team', 'all'

  static ReminderTaskType fromKey(String key) {
    return ReminderTaskType.values.firstWhere(
      (e) => e.name == key,
      orElse: () => ReminderTaskType.all,
    );
  }
}

/// How the reminder is triggered.
enum ReminderTriggerMode {
  /// Fire at a fixed time every day (e.g. 08:00 every day).
  daily,

  /// Fire X interval before the task deadline (e.g. 2 days before).
  beforeDeadline,
}

extension ReminderTriggerModeX on ReminderTriggerMode {
  String get label {
    switch (this) {
      case ReminderTriggerMode.daily:
        return 'Daily (fixed time)';
      case ReminderTriggerMode.beforeDeadline:
        return 'Before Deadline';
    }
  }

  String get key => name;

  static ReminderTriggerMode fromKey(String key) {
    return ReminderTriggerMode.values.firstWhere(
      (e) => e.name == key,
      orElse: () => ReminderTriggerMode.daily,
    );
  }
}

/// A single global reminder entry.
class GlobalReminder {
  final String id; // UUID-like unique key
  final ReminderTaskType taskType;
  final ReminderTriggerMode triggerMode;

  // Used when triggerMode == daily
  final int hour;
  final int minute;

  // Used when triggerMode == beforeDeadline
  final int intervalAmount; // e.g. 2
  final String intervalUnit; // 'H' (hours), 'D' (days), 'W' (weeks)

  final bool isEnabled;

  const GlobalReminder({
    required this.id,
    required this.taskType,
    required this.triggerMode,
    this.hour = 8,
    this.minute = 0,
    this.intervalAmount = 1,
    this.intervalUnit = 'D',
    this.isEnabled = true,
  });

  GlobalReminder copyWith({
    String? id,
    ReminderTaskType? taskType,
    ReminderTriggerMode? triggerMode,
    int? hour,
    int? minute,
    int? intervalAmount,
    String? intervalUnit,
    bool? isEnabled,
  }) {
    return GlobalReminder(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      triggerMode: triggerMode ?? this.triggerMode,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      intervalAmount: intervalAmount ?? this.intervalAmount,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskType': taskType.key,
    'triggerMode': triggerMode.key,
    'hour': hour,
    'minute': minute,
    'intervalAmount': intervalAmount,
    'intervalUnit': intervalUnit,
    'isEnabled': isEnabled,
  };

  factory GlobalReminder.fromJson(Map<String, dynamic> json) => GlobalReminder(
    id: json['id'] as String,
    taskType: ReminderTaskTypeX.fromKey(json['taskType'] as String),
    triggerMode: ReminderTriggerModeX.fromKey(json['triggerMode'] as String),
    hour: (json['hour'] as num).toInt(),
    minute: (json['minute'] as num).toInt(),
    intervalAmount: (json['intervalAmount'] as num).toInt(),
    intervalUnit: json['intervalUnit'] as String,
    isEnabled: json['isEnabled'] as bool? ?? true,
  );

  /// Human-readable description label.
  String get triggerLabel {
    if (triggerMode == ReminderTriggerMode.daily) {
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return 'Setiap hari jam $h:$m';
    } else {
      final unitLabel = switch (intervalUnit) {
        'H' => intervalAmount == 1 ? '1 hour' : '$intervalAmount hour',
        'W' => intervalAmount == 1 ? '1 week' : '$intervalAmount week',
        _ => intervalAmount == 1 ? '1 day' : '$intervalAmount day',
      };
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$unitLabel before deadline • $h:$m';
    }
  }

  /// Notification ID base for this global reminder (uses hash of id string).
  int get notificationIdBase => id.hashCode.abs() % 900000 + 100000;
}

/// Service for managing global reminders (stored in SharedPreferences).
class GlobalReminderService {
  static const String _storageKey = 'global_reminders';

  // ─── Storage ────────────────────────────────────────────────────────────────

  static Future<List<GlobalReminder>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => GlobalReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveAll(List<GlobalReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reminders.map((r) => r.toJson()).toList()),
    );
  }

  /// Add a new reminder. Returns the saved reminder.
  static Future<GlobalReminder> add(GlobalReminder reminder) async {
    final all = await getAll();
    all.add(reminder);
    await _saveAll(all);
    if (reminder.isEnabled) {
      await _scheduleReminder(reminder);
    }
    return reminder;
  }

  /// Update an existing reminder by id.
  static Future<void> update(GlobalReminder updated) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    // Cancel old schedule first
    await _cancelReminder(all[idx]);
    all[idx] = updated;
    await _saveAll(all);
    if (updated.isEnabled) {
      await _scheduleReminder(updated);
    }
  }

  /// Toggle enabled/disabled state.
  static Future<void> toggleEnabled(String id, bool enabled) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = all[idx].copyWith(isEnabled: enabled);
    await _cancelReminder(all[idx]);
    all[idx] = updated;
    await _saveAll(all);
    if (enabled) {
      await _scheduleReminder(updated);
    }
  }

  /// Delete a reminder by id.
  static Future<void> delete(String id) async {
    final all = await getAll();
    final target = all.where((r) => r.id == id).firstOrNull;
    if (target != null) await _cancelReminder(target);
    all.removeWhere((r) => r.id == id);
    await _saveAll(all);
  }

  /// Re-schedule all enabled global reminders (call after task list changes).
  static Future<void> rescheduleAll() async {
    final all = await getAll();
    for (final r in all) {
      await _cancelReminder(r);
      if (r.isEnabled) {
        await _scheduleReminder(r);
      }
    }
  }

  // ─── Scheduling ─────────────────────────────────────────────────────────────

  static Future<void> _scheduleReminder(GlobalReminder reminder) async {
    if (reminder.triggerMode == ReminderTriggerMode.daily) {
      // Schedule a repeating daily notification at the fixed time.
      final now = DateTime.now();
      var fire = DateTime(
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );
      if (fire.isBefore(now)) {
        fire = fire.add(const Duration(days: 1));
      }

      // Generate dynamic body focusing on tasks for the scheduled day.
      final body = await _generateTaskSummary(reminder, fire);

      await NotificationHelper.scheduleCustomReminder(
        id: reminder.notificationIdBase,
        title: _titleFor(reminder),
        body: body,
        priority: 'medium',
        scheduledDate: fire,
        payload: 'global_reminder_${reminder.id}',
      );
    } else {
      // beforeDeadline mode: schedule this reminder for every matching
      // uncompleted task that currently exists in local storage.
      await _scheduleBeforeDeadlineForAllTasks(reminder);
    }
  }

  /// Loops through all uncompleted tasks and schedules [reminder] for each
  /// matching one (respects taskType filter).
  static Future<void> _scheduleBeforeDeadlineForAllTasks(
    GlobalReminder reminder,
  ) async {
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) return;

      final repo = TaskRepository();
      final List<TaskLocal> allTasks = await repo.getAllTasks(email);

      for (final task in allTasks) {
        if (task.isCompleted || task.dueDate == null) continue;

        final bool isTeam = task.teamId != null;
        if (reminder.taskType == ReminderTaskType.individual && isTeam) continue;
        if (reminder.taskType == ReminderTaskType.team && !isTeam) continue;

        // Build precise deadline DateTime
        DateTime deadline = task.dueDate!;
        if (task.dueTime != null) {
          try {
            final parts = task.dueTime!.split(':');
            deadline = DateTime(
              task.dueDate!.year,
              task.dueDate!.month,
              task.dueDate!.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
              parts.length > 2 ? int.parse(parts[2]) : 0,
            );
          } catch (_) {}
        }

        await GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
          taskId: task.id,
          taskTitle: task.title,
          taskDescription: task.description,
          priority: task.priority,
          deadline: deadline,
          isTeam: isTeam,
        );
      }
    } catch (_) {}
  }

  /// Generates a bulleted list of tasks for the given reminder and date.
  static Future<String> _generateTaskSummary(GlobalReminder reminder, DateTime targetDate) async {
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) return _getDefaultBody(reminder.taskType);

      final repo = TaskRepository();
      final allTasks = await repo.getAllTasks(email);
      
      final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      final relevantTasks = allTasks.where((t) {
        if (t.isCompleted || t.dueDate == null) return false;
        final taskDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (!taskDay.isAtSameMomentAs(targetDay)) return false;
        
        return switch (reminder.taskType) {
          ReminderTaskType.individual => t.teamId == null,
          ReminderTaskType.team => t.teamId != null,
          ReminderTaskType.all => true,
        };
      }).toList();

    if (relevantTasks.isEmpty) return _getDefaultBody(reminder.taskType);

    final buffer = StringBuffer();
    buffer.writeln('📋 Tasks for today:');
    for (int i = 0; i < relevantTasks.length; i++) {
      buffer.write('${i + 1}. ${relevantTasks[i].title}');
        if (i < relevantTasks.length - 1) buffer.writeln();
      }
      return buffer.toString();
    } catch (_) {
      return _getDefaultBody(reminder.taskType);
    }
  }

  static Future<void> _cancelReminder(GlobalReminder reminder) async {
    if (reminder.triggerMode == ReminderTriggerMode.daily) {
      await NotificationHelper.cancelById(reminder.notificationIdBase);
    } else {
      // Cancel per-task notifications for this beforeDeadline reminder.
      try {
        final email = await SecureStorage.getEmail();
        if (email == null || email.isEmpty) return;
        final repo = TaskRepository();
        final List<TaskLocal> allTasks = await repo.getAllTasks(email);
        for (final task in allTasks) {
          final notifId = GlobalReminderScheduler.notifIdFor(reminder, task.id);
          await NotificationHelper.cancelById(notifId);
        }
      } catch (_) {
        // Fallback: at minimum cancel the base ID
        await NotificationHelper.cancelById(reminder.notificationIdBase);
      }
    }
  }

  static String _titleFor(GlobalReminder r) {
    switch (r.taskType) {
      case ReminderTaskType.individual:
        return '📋 Individual Task Reminder';
      case ReminderTaskType.team:
        return '👥 Team Task Reminder';
      default:
        return '🔔 System Reminder';
    }
  }

  static String _getDefaultBody(ReminderTaskType type) {
    switch (type) {
      case ReminderTaskType.individual:
        return 'Check your individual tasks for today!';
      case ReminderTaskType.team:
        return 'Check your team tasks for today!';
      case ReminderTaskType.all:
        return 'Cek semua task kamu hari ini!';
    }
  }

  /// Generate a simple unique ID.
  static String generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  /// Returns reminders grouped by [ReminderTaskType].
  static Map<ReminderTaskType, List<GlobalReminder>> groupByType(
    List<GlobalReminder> reminders,
  ) {
    final map = <ReminderTaskType, List<GlobalReminder>>{};
    for (final type in ReminderTaskType.values) {
      map[type] = reminders.where((r) => r.taskType == type).toList();
    }
    return map;
  }
}
