import '../../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../task/models/task_local.dart';
import '../../task/pages/task_page.dart';
import '../../task/services/task_repository.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/utils/error_handler.dart';
import 'dart:ui';

class DailyTaskList extends StatefulWidget {
  final List<TaskLocal> tasks;
  final VoidCallback onRefresh;
  final AuthService? authService;
  final bool isLoading;
  final DateTime? filterDate;

  const DailyTaskList({
    super.key,
    required this.tasks,
    required this.onRefresh,
    this.authService,
    this.isLoading = false,
    this.filterDate,
    this.isOffline = false,
  });

  final bool isOffline;

  @override
  State<DailyTaskList> createState() => _DailyTaskListState();
}

class _DailyTaskListState extends State<DailyTaskList> {
  final TaskRepository _taskRepository = TaskRepository();

  Future<void> _toggleTask(TaskLocal task) async {
    final email = widget.authService?.currentCachedUser?.email ?? 'guest';
    
    // Use specialized toggle logic that handles team task individual progress
    _taskRepository.toggleTaskStatus(task, email);
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _taskRepository.deleteTask(task);
    ErrorHandler.showSuccessPopup('Task deleted successfully');
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskPage(
                      authService: widget.authService,
                      filterDate: widget.filterDate ?? DateTime.now(),
                    ),
                  ),
                );
              },
              child: const Text(
                'SEE ALL',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.isLoading && widget.tasks.isEmpty)
          Column(
            children: List.generate(3, (index) => const _SkeletonTaskItem()),
          )
        else if (widget.tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No tasks for today.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.isLoading
                ? widget.tasks.length + 1
                : widget.tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (widget.isLoading && index == widget.tasks.length) {
                return const _SkeletonTaskItem();
              }
              final task = widget.tasks[index];
              return _TaskItem(
                task: task,
                onToggle: () => _toggleTask(task),
                onDelete: () => _deleteTask(task),
                isOffline: widget.isOffline,
              );
            },
          ),
      ],
    );
  }
}

class _SkeletonTaskItem extends StatefulWidget {
  const _SkeletonTaskItem();

  @override
  State<_SkeletonTaskItem> createState() => _SkeletonTaskItemState();
}

class _SkeletonTaskItemState extends State<_SkeletonTaskItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final TaskLocal task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isOffline;

  const _TaskItem({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.isOffline = false,
  });

  Color _getPriorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF0000); // Pure Red
      case 'medium':
        return const Color(0xFFA49C00); // Deep Olive/Yellow (Text)
      case 'low':
        return const Color(0xFF16A34A); // Forest Green
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Color _getPriorityBgColor() {
    switch (task.priority.toLowerCase()) {
      case 'medium':
        return const Color(0xFFD4EA0C).withValues(alpha: 0.15); // Light Yellow/Lime Tint
      default:
        return _getPriorityColor().withValues(alpha: 0.15);
    }
  }

  Color _getPriorityTextColor() {
    return _getPriorityColor();
  }

  String _getPriorityLabel() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return task.priority;
    }
  }

  IconData _getPriorityIcon() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.priority_high;
      case 'low':
        return Icons.low_priority;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: task.teamId != null && isOffline,
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? AppColors.surface.withValues(alpha: 0.5)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: task.isCompleted
                              ? AppColors.calendarSelected
                              : AppColors.calendarSelected,
                          width: 2,
                        ),
                        color: task.isCompleted
                            ? AppColors.calendarSelected
                            : Colors.transparent,
                      ),
                      child: task.isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityBgColor(),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPriorityIcon(),
                                    size: 12,
                                    color: _getPriorityTextColor(),
                                  ),
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
                            const SizedBox(width: 8),
                            Text(
                              task.dueTime != null
                                  ? _formatTime(task.dueTime!, context)
                                  : 'No time',
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isCompleted
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (task.teamId != null && isOffline)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off, color: Colors.white, size: 14),
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
    );
  }

  String _formatTime(String timeStr, BuildContext context) {
    try {
      final parts = timeStr.split(':');
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return timeStr;
    }
  }
}
