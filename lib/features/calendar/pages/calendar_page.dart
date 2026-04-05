import 'package:flutter/material.dart';
import '../../task/services/task_repository.dart';
import '../../task/pages/create_task_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../task/models/task_local.dart';
import 'dart:async';
import 'dart:ui';
import '../../../core/utils/error_handler.dart';
import '../../../core/services/connection_service.dart';

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
  bool _isNext = true; // Track direction for animation
  String? _currentUserEmail;
  StreamSubscription<List<TaskLocal>>? _tasksSubscription;
  bool _isOffline = false;
  StreamSubscription? _connectivitySubscription;

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
    _initTaskSubscription();
  }

  Future<void> _checkInitialConnection() async {
    final connected = await ConnectionService().isConnected();
    if (mounted) {
      setState(() {
        _isOffline = !connected;
      });
    }
  }

  Future<void> _initTaskSubscription() async {
    final auth = widget.authService ?? AuthService();
    final user = await auth.getCurrentUser();
    _currentUserEmail = user?.email ?? 'guest';

    _tasksSubscription?.cancel();
    _tasksSubscription = _taskRepository
        .watchAllTasks(_currentUserEmail!)
        .listen((tasks) {
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
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final auth = widget.authService ?? AuthService();
    if (await auth.isGuest()) return;

    final user = await auth.getCurrentUser();
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
      _isNext = false;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _isNext = true;
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
      child: RefreshIndicator(
        onRefresh: _loadTasks,
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Header & Calendar Grid
            SliverToBoxAdapter(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _previousMonth();
                  } else if (details.primaryVelocity! < 0) {
                    _nextMonth();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final isIncoming = child.key == ValueKey<DateTime>(_currentMonth);
                    final slideOffset = _isNext 
                        ? (isIncoming ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0))
                        : (isIncoming ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0));

                    return SlideTransition(
                      position: animation.drive(Tween<Offset>(
                        begin: slideOffset,
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic))),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey<DateTime>(_currentMonth),
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildWeekDays(),
                      const SizedBox(height: 16),
                      _buildCalendarGrid(),
                    ],
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            
            // Todo List Section
            _buildSliverTodoList(),
            
            // Bottom Spacing
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.calendarBorder, width: 1.2),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
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
                color: isSelected ? AppColors.calendarSelected : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                      color: () {
                        if (!isCurrentMonth) return AppColors.calendarOtherMonth;
                        if (isSelected) return Colors.white;
                        return AppColors.textPrimary;
                      }(),
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

  Widget _buildSliverTodoList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedDayTasks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: Color(0xFFB0A495),
              ),
              const SizedBox(height: 16),
              const Text(
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
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = _selectedDayTasks[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskTile(
                task: task,
                currentUserEmail: _currentUserEmail,
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateTaskPage(
                        task: task,
                        authService: widget.authService,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadTasks();
                  }
                },
                onDelete: () => _deleteTask(task),
                isOffline: _isOffline,
              ),
            );
          },
          childCount: _selectedDayTasks.length,
        ),
      ),
    );
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
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
      ErrorHandler.showSuccessPopup('Task deleted successfully');
      _loadTasks();
    }
  }
}

class _TaskTile extends StatelessWidget {
  final TaskLocal task;
  final String? currentUserEmail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOffline;

  const _TaskTile({
    required this.task,
    this.currentUserEmail,
    required this.onEdit,
    required this.onDelete,
    this.isOffline = false,
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

  void _showTaskDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        onEdit: () {
          Navigator.pop(context); // Close sheet
          onEdit();
        },
        onDelete: () {
          Navigator.pop(context); // Close sheet
          onDelete();
        },
        isOwner: task.userEmail == currentUserEmail || task.teamId == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: task.teamId != null && isOffline,
      child: GestureDetector(
        onTap: () => _showTaskDetail(context),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
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
                      if (task.teamId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Team',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
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
            ),
            if (task.teamId != null && isOffline)
              Positioned.fill(
                bottom: 12, // Match margin
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off, color: Colors.white, size: 16),
                              SizedBox(width: 10),
                              Text(
                                "Offline: Connection Required",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
}

class _TaskDetailSheet extends StatelessWidget {
  final TaskLocal task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOwner;

  const _TaskDetailSheet({
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.isOwner,
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
    if (task.dueTime == null) return 'No time set';
    try {
      final parts = task.dueTime!.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (_) {}
    return task.dueTime!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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

          // ── Action Buttons (Only for Owner) ──
          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
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
          ] else ...[
            // Status tag for team tasks where user isn't owner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text(
                    'View-only: This task belongs to the team.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
