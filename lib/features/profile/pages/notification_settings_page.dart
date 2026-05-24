import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/notification_settings_service.dart';
import '../services/global_reminder_service.dart';
import '../services/global_reminder_scheduler.dart';
import '../widgets/global_reminder_card.dart';
import '../widgets/global_reminder_sheet.dart';
import '../../../core/utils/notification_helper.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _remoteAlertsEnabled = true;
  bool _vibrationEnabled = true;
  List<GlobalReminder> _globalReminders = [];

  @override
  void initState() {
    super.initState();
    _loadRemoteSettings();
    _loadGlobalReminders();
  }

  Future<void> _loadRemoteSettings() async {
    final remoteEnabled =
        await NotificationSettingsService.isRemoteAlertsEnabled();
    final vibrationEnabled =
        await NotificationSettingsService.isVibrationEnabled();
    if (mounted) {
      setState(() {
        _remoteAlertsEnabled = remoteEnabled;
        _vibrationEnabled = vibrationEnabled;
      });
    }
  }

  Future<void> _loadGlobalReminders() async {
    final reminders = await GlobalReminderService.getAll();
    if (mounted) setState(() => _globalReminders = reminders);
  }

  Future<void> _openAddReminderSheet({GlobalReminder? existing}) async {
    final result = await showModalBottomSheet<GlobalReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlobalReminderSheet(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await GlobalReminderService.add(result);
    } else {
      await GlobalReminderService.update(result);
    }
    await _loadGlobalReminders();
  }

  Future<void> _deleteReminder(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Reminder?'),
        content: const Text('This reminder will be deleted permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GlobalReminderService.delete(id);
    await _loadGlobalReminders();
  }

  Future<void> _toggleReminderEnabled(String id, bool enabled) async {
    await GlobalReminderService.toggleEnabled(id, enabled);
    await _loadGlobalReminders();
  }

  Future<void> _toggleRemoteAlerts(bool value) async {
    setState(() => _remoteAlertsEnabled = value);
    NotificationSettingsService.setRemoteAlertsEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Remote alerts enabled' : 'Remote alerts disabled',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() => _vibrationEnabled = value);
    NotificationSettingsService.setVibrationEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Vibration enabled' : 'Vibration disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  List<Widget> _buildGroupedReminders() {
    final grouped = GlobalReminderService.groupByType(_globalReminders);
    final widgets = <Widget>[];

    for (final type in ReminderTaskType.values) {
      final list = grouped[type]!;
      if (list.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(
            children: [
              Icon(type.icon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );

      for (final reminder in list) {
        widgets.add(
          GlobalReminderCard(
            reminder: reminder,
            onEdit: () => _openAddReminderSheet(existing: reminder),
            onDelete: () => _deleteReminder(reminder.id),
            onToggle: (val) => _toggleReminderEnabled(reminder.id, val),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Global Reminders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddReminderSheet(),
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Global notifications to remind all tasks, individuals, or teams.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_globalReminders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'There are no global reminders yet. Tap "Add".',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._buildGroupedReminders(),

            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Push Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Remote Alerts',
              subtitle: 'Receive team invites and task updates in real-time',
              value: _remoteAlertsEnabled,
              onChanged: _toggleRemoteAlerts,
            ),
            _buildSwitchTile(
              title: 'Vibrate',
              subtitle: 'Vibrate when receiving important notifications',
              value: _vibrationEnabled,
              onChanged: _toggleVibration,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Debug',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text(
                    'Test Notification (5 detik)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Send test notification in 5 seconds'),
                  trailing: const Icon(Icons.send),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await NotificationHelper.scheduleTestNotification();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Test notification scheduled! Wait 5 seconds...',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              // ── Test: Before Deadline Global Reminder ────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.alarm_on, color: Colors.purple),
                  title: const Text(
                    'Test Before Deadline Reminder',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Simulate task deadline in 2 hours.\n'
                    'Notifications will appear according to the active Global Reminder interval.',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.send),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    // Fake task: deadline 2 jam dari sekarang
                    final fakeDeadline = DateTime.now().add(
                      const Duration(hours: 2),
                    );
                    const fakeTaskId = 999998;

                    await GlobalReminderScheduler.scheduleBeforeDeadlineForTask(
                      taskId: fakeTaskId,
                      taskTitle: '[TEST] Fake Task',
                      taskDescription:
                          'Ini adalah task simulasi untuk testing global reminder.',
                      priority: 'high',
                      deadline: fakeDeadline,
                      isTeam: false,
                    );

                    // Hitung berapa reminder yang terjadwal
                    final reminders = await GlobalReminderService.getAll();
                    final beforeDeadlineCount = reminders
                        .where(
                          (r) =>
                              r.isEnabled &&
                              r.triggerMode ==
                                  ReminderTriggerMode.beforeDeadline,
                        )
                        .length;

                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            beforeDeadlineCount == 0
                                ? '⚠️ There are no active "Before Deadline" Global Reminders. Add one now!'
                                : '✅ $beforeDeadlineCount before-deadline reminder scheduled for fake task (deadline: ${fakeDeadline.hour}:${fakeDeadline.minute.toString().padLeft(2, "0")})',
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
