// lib/features/profile/services/notification_settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class NotificationSettingsService {
  static const String _keyReminderDays = 'reminder_days';
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyRemoteAlerts = 'remote_alerts';
  static const String _keyVibration = 'vibration_enabled';
  
  // Default to H-0 (Today), H-1, H-2, H-3
  static const List<int> defaultDays = [0, 1, 2, 3];
  static const int defaultHour = 9;
  static const int defaultMinute = 0;
  static const bool defaultRemoteAlerts = true;
  static const bool defaultVibration = true;

  static Future<List<int>> getReminderDays() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList(_keyReminderDays);
    if (stored == null) return defaultDays;
    return stored.map(int.parse).toList()..sort();
  }

  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final int hour = prefs.getInt(_keyReminderHour) ?? defaultHour;
    final int minute = prefs.getInt(_keyReminderMinute) ?? defaultMinute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<bool> isRemoteAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRemoteAlerts) ?? defaultRemoteAlerts;
  }

  static Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibration) ?? defaultVibration;
  }

  static Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibration, enabled);
    // ignore: unawaited_futures
    syncToBackend();
  }

  static Future<void> setRemoteAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemoteAlerts, enabled);
    // ignore: unawaited_futures
    syncToBackend();
  }

  static Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, time.hour);
    await prefs.setInt(_keyReminderMinute, time.minute);
    // ignore: unawaited_futures
    syncToBackend();
  }

  static Future<void> setReminderDays(List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyReminderDays,
      days.map((d) => d.toString()).toList(),
    );
    // ignore: unawaited_futures
    syncToBackend();
  }

  static Future<bool> isDayEnabled(int day) async {
    final days = await getReminderDays();
    return days.contains(day);
  }

  static Future<void> toggleDay(int day, bool enabled) async {
    final days = await getReminderDays();
    if (enabled) {
      if (!days.contains(day)) {
        days.add(day);
      }
    } else {
      days.remove(day);
    }
    await setReminderDays(days);
  }

  /// Sync local settings to the backend
  static Future<void> syncToBackend() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) return;

      final reminderDays = await getReminderDays();
      final reminderTime = await getReminderTime();
      final vibration = await isVibrationEnabled();
      final remoteAlerts = await isRemoteAlertsEnabled();

      final client = ApiClient();
      await client.post('/notification-settings', data: {
        'reminder_days': reminderDays,
        'reminder_time': '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
        'vibration': vibration,
        'remote_alerts': remoteAlerts,
      });
    } catch (e) {
      // Silently fail or use a more robust logging system in production
    }
  }

  /// Fetch settings from backend and update local cache
  static Future<void> fetchFromBackend() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) return;

      final client = ApiClient();
      final response = await client.get('/notification-settings');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final List<int> days = List<int>.from(data['reminder_days'] ?? []);
        final String timeStr = data['reminder_time'] ?? "09:00";
        final parts = timeStr.split(':');
        final TimeOfDay time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9, 
          minute: int.tryParse(parts[1]) ?? 0
        );
        final bool vibration = data['vibration'] ?? true;
        final bool remoteAlerts = data['remote_alerts'] ?? true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_keyReminderDays, days.map((d) => d.toString()).toList());
        await prefs.setInt(_keyReminderHour, time.hour);
        await prefs.setInt(_keyReminderMinute, time.minute);
        await prefs.setBool(_keyVibration, vibration);
        await prefs.setBool(_keyRemoteAlerts, remoteAlerts);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
