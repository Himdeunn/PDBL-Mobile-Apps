import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:wudi/features/profile/services/notification_settings_service.dart';

/// Notification types that should trigger a group/team page refresh.
const _kTeamEventTypes = {
  'invite',
  'kick',
  'ban',
  'new_task',
  'task_update',
  'team',
};

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _isTimezoneInitialized = false;

  /// Broadcasts whenever a foreground FCM message related to teams/invites arrives.
  static final _teamEventController = StreamController<void>.broadcast();
  static Stream<void> get onTeamEvent => _teamEventController.stream;

  /// Broadcasts notification tap data so MainNavigation can switch tabs.
  static final _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _tapController.stream;

  /// Stores the tap data when the app was launched from a killed state.
  /// MainNavigation claims this in its first frame via [claimInitialTap].
  static Map<String, dynamic>? _pendingInitialTap;
  static int? _activeChatConversationId;

  /// Store tap from a terminated-state launch (no live subscribers yet).
  static void setInitialTap(Map<String, dynamic> data) {
    _pendingInitialTap = data;
  }

  /// Emit a notification tap to live subscribers AND store as pending fallback.
  static void emitTap(Map<String, dynamic> data) {
    _pendingInitialTap = data;
    _tapController.add(data);
  }

  static void setActiveChatConversationId(int? conversationId) {
    _activeChatConversationId = conversationId;
  }

  static int chatNotificationId(int conversationId) {
    return 700000 + conversationId;
  }

  static Future<void> cancelChatNotification(int conversationId) async {
    await _notificationsPlugin.cancel(id: chatNotificationId(conversationId));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('unread_chat_$conversationId');
    } catch (_) {}
  }

  /// Claim and clear the pending initial tap. Returns null if already consumed.
  static Map<String, dynamic>? claimInitialTap() {
    final data = _pendingInitialTap;
    _pendingInitialTap = null;
    return data;
  }

  // Multiplier to generate unique notification IDs per reminder day offset.
  static const int _idMultiplier = 10000;

  // Max reminder day offsets we support (H-0 through H-7)
  static const int _maxReminderDays = 8;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    await _ensureTimezoneInitialized();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        if (payload.isNotEmpty) {
          final data = <String, dynamic>{'type': 'update', 'payload': payload};
          try {
            final parsed = payload.startsWith('{')
                ? Map<String, dynamic>.from(jsonDecode(payload) as Map)
                : <String, dynamic>{};
            data.addAll(parsed);
          } catch (_) {}
          emitTap(data);
        }
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

  static Future<void> _ensureTimezoneInitialized() async {
    if (_isTimezoneInitialized) return;

    tz.initializeTimeZones();
    try {
      final dynamic locationInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = locationInfo is String
          ? locationInfo
          : locationInfo.name;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }
    _isTimezoneInitialized = true;
  }

  /// Listen for foreground messages and show them as local notifications
  static void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        final type = (message.data['type'] as String? ?? '').toLowerCase();
        final conversationId = int.tryParse(
          (message.data['conversation_id'] ?? '').toString(),
        );
        if (type == 'chat' &&
            conversationId != null &&
            _activeChatConversationId == conversationId) {
          return;
        }
        showNotification(
          id: type == 'chat' && conversationId != null
              ? chatNotificationId(conversationId)
              : notification.hashCode,
          title: notification.title ?? 'System Alert',
          body: notification.body ?? 'Update received',
          priority: message.data['priority'] ?? 'medium',
          description: message.data['description'] ?? message.data['deskripsi'],
          payload: jsonEncode(message.data),
        );
      }

      final type = (message.data['type'] as String? ?? '').toLowerCase();
      if (_kTeamEventTypes.contains(type)) {
        _teamEventController.add(null);
      }
    });
  }

  /// Helper to format a rich body string with priority and description
  static String _formatRichBody({
    required String baseBody,
    required String priority,
    String? description,
  }) {
    final buffer = StringBuffer();
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
    final type = _payloadType(payload);
    final isChat = type == 'chat';

    StyleInformation? styleInformation;
    String notificationTitle = title;

    if (isChat && payload != null) {
      try {
        final decoded = jsonDecode(payload);
        final conversationId = decoded['conversation_id']?.toString() ?? '';
        final senderName = decoded['sender_name']?.toString() ?? 'Unknown';
        final conversationName =
            decoded['conversation_name']?.toString() ?? title;
        final chatType = decoded['chat_type']?.toString() ?? 'personal';
        final chatBody = chatType == 'team'
            ? _stripSenderPrefix(body, senderName)
            : body;

        if (conversationId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final key = 'unread_chat_$conversationId';
          final unread = prefs.getStringList(key) ?? [];

          final msgData = {
            'sender': senderName,
            'body': chatBody,
            'time': DateTime.now().millisecondsSinceEpoch,
          };
          unread.add(jsonEncode(msgData));
          await prefs.setStringList(key, unread);

          final titleWithTime = _chatTitleWithTime(conversationName);

          if (chatType == 'team') {
            body = '$senderName: $chatBody';
            styleInformation = BigTextStyleInformation(
              _groupTeamChatMessages(unread),
              contentTitle: titleWithTime,
              summaryText: 'Group Chat',
            );
          } else {
            final messages = unread.map((e) {
              try {
                final map = jsonDecode(e);
                return Message(
                  map['body']?.toString() ?? '',
                  DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
                  Person(name: map['sender']?.toString()),
                );
              } catch (_) {
                return Message(e, DateTime.now(), null);
              }
            }).toList();

            styleInformation = MessagingStyleInformation(
              const Person(name: 'Me'),
              conversationTitle: conversationName,
              groupConversation: false,
              messages: messages,
            );
          }
          notificationTitle = titleWithTime;
        }
      } catch (_) {}
    }

    if (styleInformation == null) {
      final richBody = _formatRichBody(
        baseBody: body,
        priority: priority,
        description: description,
      );

      styleInformation = BigTextStyleInformation(
        richBody,
        contentTitle: isChat ? _chatTitleWithTime(title) : title,
        summaryText: isChat ? 'Chat' : 'Task Management',
      );
      if (isChat) notificationTitle = _chatTitleWithTime(title);
    }

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v2',
      isChat ? 'Chat Notifications' : 'Task Reminders',
      channelDescription: isChat
          ? 'Messages from personal and group chats'
          : 'Important deadline and task reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'launcher_icon',
      styleInformation: styleInformation,
      color: priority.toLowerCase() == 'high'
          ? const Color(0xFFC62828) // Urgent Red
          : const Color(0xFF6B4E31), // Premium Brown
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: notificationTitle,
      body: body, // Keep short body for preview
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  static String _chatTitleWithTime(String title) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$title • $hour:$minute';
  }

  static String _stripSenderPrefix(String body, String senderName) {
    final trimmedBody = body.trimLeft();
    final trimmedSender = senderName.trim();
    if (trimmedSender.isEmpty) return body;

    final prefix = '$trimmedSender:';
    if (!trimmedBody.toLowerCase().startsWith(prefix.toLowerCase())) {
      return body;
    }

    return trimmedBody.substring(prefix.length).trimLeft();
  }

  static String _groupTeamChatMessages(List<String> unread) {
    final groupedBlocks = <List<String>>[];
    String? currentSender;

    for (final raw in unread) {
      String sender = 'Unknown User';
      String message = raw;

      try {
        final map = jsonDecode(raw);
        sender = (map['sender']?.toString().trim().isNotEmpty ?? false)
            ? map['sender'].toString().trim()
            : 'Unknown User';
        message = map['body']?.toString().trim() ?? '';
      } catch (_) {}

      if (message.isEmpty) continue;

      if (currentSender != sender) {
        currentSender = sender;
        groupedBlocks.add([sender, message]);
      } else {
        groupedBlocks.last.add(message);
      }
    }

    return groupedBlocks.map((block) => block.join('\n')).join('\n\n');
  }

  static String _payloadType(String? payload) {
    if (payload == null || payload.isEmpty) return '';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return (decoded['type'] ?? '').toString().toLowerCase();
      }
    } catch (_) {}
    return payload.startsWith('task_') ? 'task' : '';
  }

  /// Alias for showNotification
  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String priority = 'medium',
    String? description,
    String? payload,
  }) => showNotification(
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
    await _ensureTimezoneInitialized();

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
          title: isTeam
              ? '📢 Team Reminder: $title'
              : '⏳ Task Reminder: $title',
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
    await _ensureTimezoneInitialized();

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
      description:
          'You can now see full task descriptions and priority labels directly in your notification tray! The formatting is designed to be sleek and professional.',
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

  /// Cancel a notification by its exact ID (used by ReminderService).
  static Future<void> cancelById(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Schedule a custom per-task reminder (used by ReminderService).
  static Future<void> scheduleCustomReminder({
    required int id,
    required String title,
    required String body,
    String? description,
    String priority = 'medium',
    required DateTime scheduledDate,
    String? payload,
  }) => _scheduleExactNotification(
    id: id,
    title: title,
    body: body,
    description: description,
    priority: priority,
    scheduledDate: scheduledDate,
    payload: payload,
  );
}
