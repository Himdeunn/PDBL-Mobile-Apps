import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:wudi/features/profile/services/notification_settings_service.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Multiplier to generate unique notification IDs per reminder day offset.
  static const int _idMultiplier = 10000;

  // Max reminder day offsets we support (H-0 through H-7)
  static const int _maxReminderDays = 8;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final dynamic locationInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName =
          locationInfo is String ? locationInfo : locationInfo.name;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Notification clicked
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel_v2',
      'Task Reminders',
      description: 'Important deadline and task reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  /// Listen for foreground messages and show them as local notifications
  static void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        showNotification(
          id: notification.hashCode,
          title: notification.title ?? 'System Alert',
          body: notification.body ?? 'Update received',
          priority: message.data['priority'] ?? 'medium',
          description: message.data['description'] ?? message.data['deskripsi'],
          payload: message.data.toString(),
        );
      }
    });
  }

  /// Helper to format a rich body string with priority and description
  static String _formatRichBody({
    required String baseBody,
    required String priority,
    String? description,
  }) {
    String priorityText;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityText = '🔴 High Priority';
        break;
      case 'medium':
        priorityText = '🟡 Medium Priority';
        break;
      case 'low':
        priorityText = '🟢 Low Priority';
        break;
      default:
        priorityText = '⚪ Priority: $priority';
    }

    final buffer = StringBuffer();
    buffer.writeln(priorityText);
    buffer.writeln('──────────────────');
    buffer.writeln(baseBody);
    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Detail:');
      buffer.write(description);
    }
    return buffer.toString();
  }

  /// Display a notification immediately
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String priority = 'medium',
    String? description,
    String? payload,
  }) async {
    final richBody = _formatRichBody(
      baseBody: body,
      priority: priority,
      description: description,
    );

    final bigTextStyle = BigTextStyleInformation(
      richBody,
      contentTitle: title,
      summaryText: 'Immediate Alert',
    );

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v2',
      'System Alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'launcher_icon',
      styleInformation: bigTextStyle,
      color: priority.toLowerCase() == 'high'
          ? const Color(0xFFC62828) // Urgent Red
          : const Color(0xFF6B4E31), // Premium Brown
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body, // Keep short body for preview
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /// Alias for showNotification
  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String priority = 'medium',
    String? description,
    String? payload,
  }) =>
      showNotification(
        id: id,
        title: title,
        body: body,
        priority: priority,
        description: description,
        payload: payload,
      );

  /// Schedule local reminders for a task based on user settings.
  static Future<void> scheduleDeadlineReminders({
    required int taskId,
    required String title,
    String? description,
    String priority = 'medium',
    bool isTeam = false,
    required DateTime deadline,
  }) async {
    final List<int> reminderDays =
        await NotificationSettingsService.getReminderDays();
    final TimeOfDay reminderTime =
        await NotificationSettingsService.getReminderTime();

    // 1. Cancel existing reminders for this task
    await cancelTaskReminders(taskId);

    // 2. Schedule "Exact Deadline" notification
    if (deadline.isAfter(DateTime.now())) {
      await _scheduleExactNotification(
        id: taskId,
        title: isTeam ? '📢 Team Deadline: $title' : '🎯 Deadline: $title',
        body: 'Your task is due now!',
        description: description,
        priority: priority,
        scheduledDate: deadline,
        payload: 'task_$taskId',
      );
    }

    // 3. Schedule "X Days Before" reminders
    for (int dayOffset in reminderDays) {
      final reminderDate = deadline.subtract(Duration(days: dayOffset));
      final scheduledDate = tz.TZDateTime(
        tz.local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      if (scheduledDate.isAfter(DateTime.now()) &&
          scheduledDate.isBefore(deadline)) {
        String label = dayOffset == 0 ? "today" : "$dayOffset days away";
        await _scheduleExactNotification(
          id: taskId + (dayOffset + 1) * _idMultiplier,
          title:
              isTeam ? '📢 Team Reminder: $title' : '⏳ Task Reminder: $title',
          body: 'The deadline is $label.',
          description: description,
          priority: priority,
          scheduledDate: scheduledDate,
          payload: 'task_$taskId',
        );
      }
    }
  }

  static Future<void> _scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    String? description,
    String priority = 'medium',
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final tz.TZDateTime tzDate = scheduledDate is tz.TZDateTime
        ? scheduledDate
        : tz.TZDateTime.from(scheduledDate, tz.local);

    final richBody = _formatRichBody(
      baseBody: body,
      priority: priority,
      description: description,
    );

    final bigTextStyle = BigTextStyleInformation(
      richBody,
      contentTitle: title,
      summaryText: 'Task Management',
    );

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v2',
      'Task Reminders',
      channelDescription: 'Important deadline and task reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'launcher_icon',
      styleInformation: bigTextStyle,
      color: priority.toLowerCase() == 'high'
          ? const Color(0xFFC62828) // Urgent Red
          : const Color(0xFF6B4E31), // Premium Brown
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body, // Keep short body for preview
      scheduledDate: tzDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Schedule a test notification 5 seconds from now.
  static Future<void> scheduleTestNotification() async {
    await _scheduleExactNotification(
      id: 99999,
      title: '🚀 Premium Test Notification',
      body: 'This is a test notification with high priority.',
      description: 'You can now see full task descriptions and priority labels directly in your notification tray! The formatting is designed to be sleek and professional.',
      priority: 'high',
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
    );
  }

  /// Cancel all scheduled reminders for a task.
  static Future<void> cancelTaskReminders(int taskId) async {
    await _notificationsPlugin.cancel(id: taskId);
    for (int i = 0; i < _maxReminderDays; i++) {
      await _notificationsPlugin.cancel(id: taskId + (i + 1) * _idMultiplier);
    }
  }
}
