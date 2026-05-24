import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_local.dart';
import '../services/notification_service.dart';
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

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  final TaskRepository _taskRepository = TaskRepository();
  List<NotificationLocal> _notifications = [];
  List<TaskLocal> _tasks = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final email = await SecureStorage.getEmail();
    if (email != null) {
      final allTasks = await _taskRepository.getAllTasks(email);
      setState(() {
        _tasks =
            allTasks.where((t) => !t.isCompleted && t.dueDate != null).toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'invite':
        return Icons.group_add_outlined;
      case 'kick':
        return Icons.person_remove_outlined;
      case 'ban':
        return Icons.block_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'invite':
        return Colors.blue;
      case 'kick':
        return Colors.orange;
      case 'ban':
        return Colors.red;
      default:
        return AppColors.primary;
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildInboxTab(), _buildTaskAlertsTab()],
      ),
    );
  }

  Widget _buildInboxTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: _notifications.isEmpty
          ? _buildEmptyState(
              'No notifications yet',
              Icons.notifications_off_outlined,
            )
          : _buildNotificationList(),
    );
  }

  Widget _buildTaskAlertsTab() {
    if (_tasks.isEmpty) {
      return _buildEmptyState(
        'No task reminders scheduled',
        Icons.alarm_off_outlined,
      );
    }

    final List<Widget> alerts = [];
    for (var task in _tasks) {
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
      alerts.add(
        TaskAlertItem(
          task: task,
          scheduledTime: deadline,
          label: 'Deadline Ends',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView(padding: const EdgeInsets.all(16), children: alerts),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textTertiary)),
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
                color: isRead
                    ? Colors.white
                    : AppColors.primary.withValues(alpha: 0.05),
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
                    child: Icon(
                      _getIconForType(type),
                      color: _getColorForType(type),
                      size: 20,
                    ),
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
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, HH:mm').format(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
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
