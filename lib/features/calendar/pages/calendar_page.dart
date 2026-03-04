import 'package:flutter/material.dart';
import '../../task/services/task_repository.dart';
import '../../task/pages/create_task_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../task/models/task_local.dart';
import 'dart:async';

class CalendarPage extends StatefulWidget {
  final AuthService? authService;
  const CalendarPage({super.key, this.authService});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final TaskRepository _taskRepository = TaskRepository();
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  List<TaskLocal> _allTasks = [];
  List<TaskLocal> _selectedDayTasks = [];
  bool _isLoading = true;
  StreamSubscription<List<TaskLocal>>? _tasksSubscription;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _initTaskSubscription();
  }

  Future<void> _initTaskSubscription() async {
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    _tasksSubscription?.cancel();
    _tasksSubscription = _taskRepository.watchAllTasks(userEmail).listen((
      tasks,
    ) {
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _filterSelectedDayTasks();
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    // This is still useful for manual refresh/pull-to-refresh
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';
    await _taskRepository.fetchTasksFromServer(userEmail);
  }

  void _filterSelectedDayTasks() {
    _selectedDayTasks = _allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.year == _selectedDate.year &&
          task.dueDate!.month == _selectedDate.month &&
          task.dueDate!.day == _selectedDate.day;
    }).toList();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    int firstWeekday = firstDayOfMonth.weekday == 7
        ? 0
        : firstDayOfMonth.weekday;

    final days = <DateTime>[];

    for (int i = firstWeekday - 1; i >= 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i + 1)));
    }

    for (int i = 0; i < lastDayOfMonth.day; i++) {
      days.add(firstDayOfMonth.add(Duration(days: i)));
    }

    while (days.length < 42) {
      days.add(days.last.add(const Duration(days: 1)));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildHeader(),
          const SizedBox(height: 24),
          _buildWeekDays(),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child: _buildTodoList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(Icons.chevron_left_rounded, _previousMonth),
          Column(
            children: [
              Text(
                _monthNames[_currentMonth.month - 1],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          _buildNavButton(Icons.chevron_right_rounded, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.calendarBorder, width: 1.2),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }

  Widget _buildWeekDays() {
    const days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days
            .map(
              (day) => SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final days = _getDaysInMonth(_currentMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final date = days[index];
          final isCurrentMonth = date.month == _currentMonth.month;
          final isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          // Get tasks for this date to show dots
          final dayTasks = _allTasks.where((task) {
            if (task.dueDate == null) return false;
            return task.dueDate!.year == date.year &&
                task.dueDate!.month == date.month &&
                task.dueDate!.day == date.day;
          }).toList();

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _filterSelectedDayTasks();
                if (!isCurrentMonth) {
                  _currentMonth = DateTime(date.year, date.month, 1);
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.calendarSelected
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w400,
                      color: !isCurrentMonth
                          ? AppColors.calendarOtherMonth
                          : isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (dayTasks.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildPriorityDots(dayTasks, isSelected),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPriorityDots(List<TaskLocal> tasks, bool isSelected) {
    // Collect unique colors
    final priorities = tasks.map((t) => t.priority.toLowerCase()).toSet();
    final List<Color> dotColors = [];

    if (priorities.contains('high')) {
      dotColors.add(isSelected ? const Color(0xFFE57373) : Colors.red);
    }
    if (priorities.contains('medium')) {
      dotColors.add(isSelected ? const Color(0xFFFFD54F) : Colors.orange);
    }
    if (priorities.contains('low')) {
      dotColors.add(isSelected ? const Color(0xFF81C784) : Colors.green);
    }

    return List.generate(dotColors.length, (index) {
      return Align(
        widthFactor: 0.6, // This creates the overlap effect
        child: _buildDot(dotColors[index]),
      );
    });
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }

  Widget _buildTodoList() {
    return Column(
      children: [
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_selectedDayTasks.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: Color(0xFFB0A495),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tasks for this day',
                    style: TextStyle(
                      color: Color(0xFF8B7E6F),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedDayTasks.length,
              itemBuilder: (context, index) {
                final task = _selectedDayTasks[index];
                return _TaskTile(
                  task: task,
                  onEdit: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateTaskPage(task: task),
                      ),
                    );
                    if (result == true) {
                      _loadTasks();
                    }
                  },
                  onDelete: () => _deleteTask(task),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _taskRepository.deleteTask(task);
      _loadTasks();
    }
  }
}

class _TaskTile extends StatelessWidget {
  final TaskLocal task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getPriorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFD32F2F);
      case 'medium':
        return const Color(0xFFFBC02D);
      case 'low':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF1976D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5), // Subtle transparent background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _getPriorityColor(), width: 2.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                task.dueTime ?? 'All day',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5D544E),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF5D544E),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B6159),
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: task.description!.length > 60
                        ? '${task.description!.substring(0, 60)}...'
                        : task.description,
                  ),
                  if (task.description!.length > 60)
                    const TextSpan(
                      text: ' view more',
                      style: TextStyle(
                        color: Color(0xFF7B5BED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
