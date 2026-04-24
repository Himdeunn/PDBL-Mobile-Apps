import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_service.dart';
import '../models/task_local.dart';
import '../services/task_repository.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../core/utils/time_utils.dart';
import 'create_task_page.dart';
import '../services/reminder_service.dart';

class TaskPage extends StatefulWidget {
  final AuthService? authService;
  final String? taskId; // Added for deep linking
  final DateTime? filterDate; // Added for today task filtering
  const TaskPage({super.key, this.authService, this.taskId, this.filterDate});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TaskRepository _repository = TaskRepository();
  List<TaskLocal> _tasks = [];
  bool _isLoading = true;
  bool _isOffline = false;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _connectivitySubscription = ConnectionService().isConnectedStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isOffline = !connected;
        });
        if (connected) {
          _loadTasks();
        }
      }
    });
    _loadTasks().then((_) {
      if (widget.taskId != null) {
        final task = _tasks.where((t) => t.id.toString() == widget.taskId).firstOrNull;
        if (task != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTaskDetails(task);
          });
        }
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final connected = await ConnectionService().isConnected();
    if (mounted) {
      setState(() {
        _isOffline = !connected;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    final tasks = widget.filterDate != null
        ? await _repository.getTasksForDate(widget.filterDate!, userEmail)
        : await _repository.getAllTasks(userEmail);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTask(TaskLocal task) async {
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';
    
    await _repository.toggleTaskStatus(task, userEmail);
    // Refresh the list to reflect changes
    setState(() {});
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repository.deleteTask(task);
    await ReminderService.deleteRemindersForTask(task.id);
    if (mounted) {
      ErrorHandler.showSuccessPopup('Task deleted successfully');
      _loadTasks();
    }
  }

  void _showTaskDetails(TaskLocal task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        onDelete: () {
          Navigator.pop(context);
          _deleteTask(task);
        },
        onEdit: () {
          Navigator.pop(context);
          _navigateToEdit(task);
        },
      ),
    );
  }

  Future<void> _navigateToEdit(TaskLocal task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateTaskPage(authService: widget.authService, task: task),
      ),
    );
    if (result == true) _loadTasks();
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskPage(authService: widget.authService),
      ),
    );
    if (result == true) _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    // Separate into uncompleted and completed
    final uncompletedTasks = _tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = _tasks.where((t) => t.isCompleted).toList();
    final sortedTasks = [...uncompletedTasks, ...completedTasks];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Today Task',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : sortedTasks.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: sortedTasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final task = sortedTasks[index];
                return _TodayTaskCard(
                  task: task,
                  onToggle: () {
                    if (_isOffline && task.teamId != null) return;
                    _toggleTask(task);
                  },
                  onTap: () {
                    if (_isOffline && task.teamId != null) return;
                    _showTaskDetails(task);
                  },
                  isOffline: _isOffline,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: AppColors.primaryDark,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 72,
            color: AppColors.calendarSelected.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to create your first task',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Task Card ──────────────────────────────────────────────────────────────────

class _TodayTaskCard extends StatefulWidget {
  final TaskLocal task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final bool isOffline;

  const _TodayTaskCard({
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.isOffline = false,
  });

  @override
  State<_TodayTaskCard> createState() => _TodayTaskCardState();
}

class _TodayTaskCardState extends State<_TodayTaskCard> {
  late bool _localCompleted;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _localCompleted = widget.task.isCompleted;
  }

  @override
  void didUpdateWidget(_TodayTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isToggling) {
      _localCompleted = widget.task.isCompleted;
    }
  }

  void _handleToggle() {
    if (_isToggling) return;
    _isToggling = true;
    setState(() => _localCompleted = !_localCompleted);
    widget.onToggle();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _isToggling = false;
    });
  }

  Color _getPriorityBgColor() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':
        return Colors.red[50]!;
      case 'medium':
        return Colors.yellow[50]!;
      case 'low':
        return Colors.green[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getPriorityTextColor() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':
        return Colors.red[700]!;
      case 'medium':
        return Colors.orange[700]!;
      case 'low':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildPriorityIcon() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':
        return Image.asset(
          'assets/images/icon high priority.png',
          width: 12,
          height: 12,
        );
      case 'low':
        return Image.asset(
          'assets/images/lowprio.png',
          width: 12,
          height: 12,
        );
      case 'medium':
        return Icon(
          Icons.warning_amber_rounded,
          size: 12,
          color: _getPriorityTextColor(),
        );
      default:
        return Icon(
          Icons.circle_outlined,
          size: 12,
          color: _getPriorityTextColor(),
        );
    }
  }

  String _getPriorityLabel() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return widget.task.priority;
    }
  }

  String _formatTime() {
    return AppTimeUtils.formatTo24h(widget.task.dueTime);
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeamOffline = widget.task.teamId != null && widget.isOffline;

    return AbsorbPointer(
      absorbing: isTeamOffline,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _localCompleted ? 0.55 : 1.0,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Checkbox ──
                    GestureDetector(
                      onTap: _handleToggle,
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.calendarSelected,
                            width: 2,
                          ),
                          color: _localCompleted
                              ? AppColors.calendarSelected
                              : Colors.transparent,
                        ),
                        child: _localCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ── Content ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _localCompleted
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              decoration: _localCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Priority badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPriorityBgColor(),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPriorityIcon(),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getPriorityLabel(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getPriorityTextColor(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Date if exists
                              if (widget.task.dueDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    DateFormat('d MMM yyyy')
                                        .format(widget.task.dueDate!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _localCompleted
                                          ? AppColors.textTertiary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              // Time
                              Text(
                                _formatTime(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _localCompleted
                                      ? AppColors.textTertiary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (widget.task.description != null &&
                              widget.task.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Description: ${widget.task.description}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _localCompleted
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isTeamOffline)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.1),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Connection Required",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail Bottom Sheet ────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final TaskLocal task;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskDetailSheet({
    required this.task,
    required this.onDelete,
    required this.onEdit,
  });

  Color _getPriorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityBgColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Colors.red[50]!;
      case 'medium':
        return Colors.orange[50]!;
      case 'low':
        return Colors.green[50]!;
      default:
        return Colors.grey[50]!;
    }
  }

  String _getPriorityLabel() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return task.priority;
    }
  }

  String _formatTime() {
    return AppTimeUtils.formatTo24h(task.dueTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Title ──
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // ── Priority Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPriorityBgColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded, size: 16, color: _getPriorityColor()),
                const SizedBox(width: 6),
                Text(
                  _getPriorityLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(),
                  ),
                ),
              ],
            ),
          ),
          // ── Date ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DUE DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy').format(task.dueDate ?? DateTime.now()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Time ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Description ──
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              task.description ?? 'No description provided.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Action Buttons ──
          Row(
            children: [
              // Delete Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Task'),
                        content: const Text('Are you sure you want to delete this task?'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              onDelete(); // Then perform original onDelete
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Edit Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
