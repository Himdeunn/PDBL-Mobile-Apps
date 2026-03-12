import '../../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../task/models/task_local.dart';
import '../../task/pages/task_page.dart';
import '../../task/services/task_repository.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class DailyTaskList extends StatefulWidget {
  final List<TaskLocal> tasks;
  final VoidCallback onRefresh;
  final AuthService? authService;
  final bool isLoading;

  const DailyTaskList({
    super.key,
    required this.tasks,
    required this.onRefresh,
    this.authService,
    this.isLoading = false,
  });

  @override
  State<DailyTaskList> createState() => _DailyTaskListState();
}

class _DailyTaskListState extends State<DailyTaskList> {
  final TaskRepository _taskRepository = TaskRepository();

  Future<void> _toggleTask(TaskLocal task) async {
    // Rely on TaskRepository update + StreamBuilder reactive flow.
    // Manual setState here can conflict with background sync/watch refreshes.
    task.isCompleted = !task.isCompleted;

    // Don't await this, let it happen in the background
    // Repository handles sync with debouncing, locking, and versioning.
    _taskRepository.updateTask(task);
  }

  Future<void> _deleteTask(TaskLocal task) async {
    await _taskRepository.deleteTask(task);
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
                    builder: (context) =>
                        TaskPage(authService: widget.authService),
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

  const _TaskItem({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  Color _getPriorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Colors.red[100]!;
      case 'medium':
        return Colors.yellow[100]!;
      case 'low':
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getPriorityTextColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Colors.red[800]!;
      case 'medium':
        return Colors.orange[800]!;
      case 'low':
        return Colors.green[800]!;
      default:
        return Colors.grey[800]!;
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

  @override
  Widget build(BuildContext context) {
    return Slidable(
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
      child: Container(
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
                          color: _getPriorityColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPriorityLabel(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityTextColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.dueTime != null
                            ? (task.dueTime!.length > 5
                                  ? task.dueTime!.substring(0, 5)
                                  : task.dueTime!)
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
    );
  }
}
