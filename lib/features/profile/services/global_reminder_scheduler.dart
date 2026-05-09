import '../../../core/utils/notification_helper.dart';
import 'global_reminder_service.dart';

/// Handles scheduling/cancelling beforeDeadline global reminder notifications
/// for individual tasks. Kept separate from [GlobalReminderService] to avoid
/// a circular import with TaskRepository.
class GlobalReminderScheduler {
  /// Schedule all enabled beforeDeadline global reminders for a specific task.
  /// Call this whenever a task is created, updated, or fetched.
  static Future<void> scheduleBeforeDeadlineForTask({
    required int taskId,
    required String taskTitle,
    String? taskDescription,
    required String priority,
    required DateTime deadline,
    required bool isTeam,
  }) async {
    final reminders = await GlobalReminderService.getAll();
    final enabled = reminders.where(
      (r) =>
          r.isEnabled &&
          r.triggerMode == ReminderTriggerMode.beforeDeadline,
    );

    for (final reminder in enabled) {
      // Filter by task type
      if (reminder.taskType == ReminderTaskType.individual && isTeam) continue;
      if (reminder.taskType == ReminderTaskType.team && !isTeam) continue;

      await _scheduleSingle(
        reminder: reminder,
        taskId: taskId,
        taskTitle: taskTitle,
        taskDescription: taskDescription,
        priority: priority,
        deadline: deadline,
        isTeam: isTeam,
      );
    }
  }

  /// Cancel all beforeDeadline global reminder notifications for a task.
  /// Call this when a task is deleted or its deadline is removed.
  static Future<void> cancelBeforeDeadlineForTask(int taskId) async {
    final reminders = await GlobalReminderService.getAll();
    for (final reminder in reminders) {
      if (reminder.triggerMode != ReminderTriggerMode.beforeDeadline) continue;
      final notifId = notifIdFor(reminder, taskId);
      await NotificationHelper.cancelById(notifId);
    }
  }

  /// Compute a unique notification ID for a (reminder, task) pair.
  static int notifIdFor(GlobalReminder reminder, int taskId) {
    // Keep well within Android's int32 limit (2^31 - 1 = 2147483647)
    return (reminder.notificationIdBase * 1000 + taskId.abs()) % 2000000000;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<void> _scheduleSingle({
    required GlobalReminder reminder,
    required int taskId,
    required String taskTitle,
    String? taskDescription,
    required String priority,
    required DateTime deadline,
    required bool isTeam,
  }) async {
    // Convert intervalUnit to a Duration
    final Duration interval = switch (reminder.intervalUnit) {
      'H' => Duration(hours: reminder.intervalAmount),
      'W' => Duration(days: reminder.intervalAmount * 7),
      _ => Duration(days: reminder.intervalAmount), // 'D' default
    };

    // Trigger date = deadline minus interval, at the user-chosen time-of-day
    final triggerBase = deadline.subtract(interval);
    final scheduled = DateTime(
      triggerBase.year,
      triggerBase.month,
      triggerBase.day,
      reminder.hour,
      reminder.minute,
    );

    // Only schedule if it's still in the future and before the deadline
    if (scheduled.isAfter(DateTime.now()) && scheduled.isBefore(deadline)) {
      final notifId = notifIdFor(reminder, taskId);
      final label = _intervalLabel(reminder);

      await NotificationHelper.scheduleCustomReminder(
        id: notifId,
        title: isTeam
            ? '📢 Team Reminder: $taskTitle'
            : '⏳ Task Reminder: $taskTitle',
        body: '$label before deadline.',
        description: taskDescription,
        priority: priority,
        scheduledDate: scheduled,
        payload: 'task_$taskId',
      );
    }
  }

  static String _intervalLabel(GlobalReminder r) {
    final n = r.intervalAmount;
    return switch (r.intervalUnit) {
      'H' => n == 1 ? '1 hour' : '$n hours',
      'W' => n == 1 ? '1 week' : '$n weeks',
      _ => n == 1 ? '1 day' : '$n days',
    };
  }
}
