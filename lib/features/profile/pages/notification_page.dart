import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/notification_helper.dart';
import '../models/notification_local.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../task/models/task_local.dart';
import '../../task/services/task_repository.dart';
import '../widgets/task_alert_item.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  final TaskRepository _taskRepository = TaskRepository();
  List<NotificationLocal> _notifications = [];
  List<TaskLocal> _tasks = [];
  bool _isLoading = true;
  List<int> _activeReminderDays = [];
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _remoteAlertsEnabled = true;
  bool _vibrationEnabled = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    _loadTasks();
    _loadSettings();
  }

  Future<void> _loadTasks() async {
    final email = await SecureStorage.getEmail();
    if (email != null) {
      final allTasks = await _taskRepository.getAllTasks(email);
      setState(() {
        _tasks = allTasks.where((t) => !t.isCompleted && t.dueDate != null).toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isSyncing = true);
    // Initial fetch from backend if authenticated
    await NotificationSettingsService.fetchFromBackend();
    
    final days = await NotificationSettingsService.getReminderDays();
    final time = await NotificationSettingsService.getReminderTime();
    final remoteEnabled = await NotificationSettingsService.isRemoteAlertsEnabled();
    final vibrationEnabled = await NotificationSettingsService.isVibrationEnabled();
    
    if (mounted) {
      setState(() {
        _activeReminderDays = days;
        _reminderTime = time;
        _remoteAlertsEnabled = remoteEnabled;
        _vibrationEnabled = vibrationEnabled;
        _isSyncing = false;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _reminderTime) {
      setState(() => _reminderTime = picked);
      
      // Sync in background
      NotificationSettingsService.setReminderTime(picked);
      
      final email = await SecureStorage.getEmail();
      if (email != null) {
        // ignore: unawaited_futures
        _taskRepository.rescheduleAllVisibleTasks(email);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder time updated to ${picked.format(context)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleReminder(int day, bool value) async {
    setState(() {
      if (value) {
        if (!_activeReminderDays.contains(day)) _activeReminderDays.add(day);
      } else {
        _activeReminderDays.remove(day);
      }
    });

    // Sync in background
    NotificationSettingsService.toggleDay(day, value);
    
    // Trigger bulk re-schedule in background
    final email = await SecureStorage.getEmail();
    if (email != null) {
      // ignore: unawaited_futures
      _taskRepository.rescheduleAllVisibleTasks(email);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Reminder for $day days before enabled' 
            : 'Reminder for $day days before disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleRemoteAlerts(bool value) async {
    setState(() => _remoteAlertsEnabled = value);
    // ignore: unawaited_futures
    NotificationSettingsService.setRemoteAlertsEnabled(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Remote alerts enabled' 
            : 'Remote alerts disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() => _vibrationEnabled = value);
    // ignore: unawaited_futures
    NotificationSettingsService.setVibrationEnabled(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Vibration enabled' 
            : 'Vibration disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final email = await SecureStorage.getEmail();
    if (email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Show local data immediately (works offline)
    final local = await _notificationService.getLocalNotifications(email);
    if (mounted) {
      setState(() {
        _notifications = local;
        _isLoading = false;
      });
    }

    // 2. Try to sync from server in background (fails silently when offline)
    await _notificationService.syncFromServer();
    await _notificationService.syncPendingToServer();

    // 3. Refresh UI with updated data
    final updated = await _notificationService.getLocalNotifications(email);
    if (mounted) {
      setState(() => _notifications = updated);
    }
  }

  // ... (keep existing _markAsRead, _deleteNotification, _getIconForType, _getColorForType methods)
  Future<void> _markAsRead(int localId, int index) async {
    try {
      await _notificationService.markAsRead(localId);
      setState(() {
        _notifications[index] = NotificationLocal()
          ..id = _notifications[index].id
          ..apiId = _notifications[index].apiId
          ..message = _notifications[index].message
          ..type = _notifications[index].type
          ..isRead = true
          ..isSynced = _notifications[index].isSynced
          ..createdAt = _notifications[index].createdAt
          ..userEmail = _notifications[index].userEmail;
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(int localId, int index) async {
    try {
      await _notificationService.deleteNotification(localId);
      setState(() => _notifications.removeAt(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invite': return Icons.group_add_outlined;
      case 'kick': return Icons.person_remove_outlined;
      case 'ban': return Icons.block_outlined;
      default: return Icons.notifications_none_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'invite': return Colors.blue;
      case 'kick': return Colors.orange;
      case 'ban': return Colors.red;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_tabController.index == 0 && _notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: AppColors.primary),
              tooltip: 'Mark all as read',
              onPressed: () async {
                final email = await SecureStorage.getEmail();
                if (email != null) {
                  await _notificationService.markAllAsRead(email);
                  await _loadNotifications();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) _loadNotifications();
              if (_tabController.index == 1) _loadTasks();
              if (_tabController.index == 2) _loadSettings();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Inbox'),
            Tab(text: 'Task Alerts'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInboxTab(),
          _buildTaskAlertsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildInboxTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: _notifications.isEmpty
          ? _buildEmptyState('No notifications yet', Icons.notifications_off_outlined)
          : _buildNotificationList(),
    );
  }

  Widget _buildTaskAlertsTab() {
    // Filter tasks that have upcoming reminders based on _activeReminderDays
    final List<Widget> alerts = [];
    
    for (var task in _tasks) {
      // 1. Exact Deadline alert
      DateTime deadline = task.dueDate!;
      if (task.dueTime != null) {
        try {
          final timeParts = task.dueTime!.split(':');
          deadline = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        } catch (_) {}
      }

      alerts.add(TaskAlertItem(
        task: task,
        scheduledTime: deadline,
        label: 'Deadline Ends',
      ));

      // 2. Reminders (H-0 to H-7)
      for (int day in _activeReminderDays) {
        final reminderDate = deadline.subtract(Duration(days: day));
        final scheduledTime = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          _reminderTime.hour,
          _reminderTime.minute,
        );

        // Only show if it's in the future and after the task's (theoretical) creation
        if (scheduledTime.isBefore(deadline)) {
           alerts.add(TaskAlertItem(
             task: task,
             scheduledTime: scheduledTime,
             label: day == 0 ? 'Due Date Reminder' : 'Reminder $day Days Before',
           ));
        }
      }
    }

    if (alerts.isEmpty) {
      return _buildEmptyState('No task reminders scheduled', Icons.alarm_off_outlined);
    }

    // Sort all alerts by scheduled time
    return RefreshIndicator(
      onRefresh: () async {
        await _loadTasks();
        await _loadSettings();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: alerts,
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isSyncing) 
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2,
            ),
          ),
        _buildSectionHeader('Reminder Schedule'),
        const Text(
          'Choose how many days before and what time you want to be reminded.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
            leading: const Icon(Icons.access_time, color: AppColors.primary),
            title: const Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Notifications sent at ${_reminderTime.format(context)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectTime,
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(8, (index) { 
          final day = index;
          final isEnabled = _activeReminderDays.contains(day);
          String title = day == 0 ? 'Due Date (H-0)' : 'Reminder H-$day';
          String subtitle = day == 0 
            ? 'Send notification on the day of deadline'
            : 'Send notification $day days before deadline';
          
          return _buildSettingTile(
            title: title,
            subtitle: subtitle,
            value: isEnabled,
            onChanged: (val) => _toggleReminder(day, val),
          );
        }),
        const SizedBox(height: 32),
        _buildSectionHeader('Push Notifications'),
        _buildSettingTile(
          title: 'Remote Alerts',
          subtitle: 'Receive team invites and task updates in real-time',
          value: _remoteAlertsEnabled,
          onChanged: _toggleRemoteAlerts,
        ),
        _buildSettingTile(
          title: 'Vibrate',
          subtitle: 'Vibrate when receiving important notifications',
          value: _vibrationEnabled,
          onChanged: _toggleVibration,
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Debug'),
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
              title: const Text('Test Notification (5 detik)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Send test notification in 5 seconds'),
              trailing: const Icon(Icons.send),
              onTap: () async {
                await NotificationHelper.scheduleTestNotification();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification scheduled! Wait 5 seconds...'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ),
        ],
        const SizedBox(height: 80), // Deadzone
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final isRead = item.isRead;
        final type = item.type;

        return Dismissible(
          key: Key(item.id.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteNotification(item.id, index),
          child: GestureDetector(
            onTap: () {
              if (!isRead) _markAsRead(item.id, index);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead
                      ? AppColors.textTertiary.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getColorForType(type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconForType(type),
                        color: _getColorForType(type), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.message,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, HH:mm').format(item.createdAt),
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
