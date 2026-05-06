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
import '../../../core/utils/notification_helper.dart';

class CalendarPage extends StatefulWidget {
  final AuthService? authService;
  const CalendarPage({super.key, this.authService});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with WidgetsBindingObserver {
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
  int _taskTab = 0; // 0 = Individu, 1 = Team
  int _prevTaskTab = 0;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription<void>? _teamEventSubscription;
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
    WidgetsBinding.instance.addObserver(this);
    _checkInitialConnection();
    _connectivitySubscription = ConnectionService().isConnectedStream.listen((connected) {
      if (mounted) setState(() => _isOffline = !connected);
    });
    _teamEventSubscription = NotificationHelper.onTeamEvent.listen((_) {
      _loadTasks(force: true);
    });
    _initTaskSubscription();
    _loadTasks(force: true);
  }

  Future<void> _checkInitialConnection() async {
    final connected = await ConnectionService().refresh();
    if (mounted) {
      setState(() {
        _isOffline = !connected;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialConnection();
      _loadTasks(force: true);
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
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _teamEventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks({bool force = false}) async {
    final auth = widget.authService ?? AuthService();
    if (await auth.isGuest()) return;

    final user = await auth.getCurrentUser();
    final userEmail = user?.email ?? 'guest';
    await _taskRepository.fetchTasksFromServer(userEmail, force: force);
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
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    setState(() {
      _isNext = false;
      _currentMonth = newMonth;
      _selectedDate = newMonth;
      _filterSelectedDayTasks();
    });
  }

  void _nextMonth() {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    setState(() {
      _isNext = true;
      _currentMonth = newMonth;
      _selectedDate = newMonth;
      _filterSelectedDayTasks();
    });
  }

  Future<void> _showMonthYearPicker() async {
    int pickerYear = _currentMonth.year;
    int pickerMonth = _currentMonth.month;

    // Generate years from 5 years ago to 10 years in the future
    final currentYear = DateTime.now().year;
    final List<int> years = List.generate(15, (i) => currentYear - 5 + i);

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year Dropdown instead of TextField
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.calendarBorder.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: pickerYear,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 300,
                      icon: const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            pickerYear = newValue;
                          });
                        }
                      },
                      items: years.map<DropdownMenuItem<int>>((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(12, (i) {
                    final selected = pickerMonth == i + 1;
                    return GestureDetector(
                      onTap: () => setDialogState(() => pickerMonth = i + 1),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _monthNames[i].substring(0, 3),
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, DateTime(pickerYear, pickerMonth, 1)),
              child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _isNext = result.isAfter(_currentMonth);
        _currentMonth = result;
        _selectedDate = result;
        _filterSelectedDayTasks();
      });
    }
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
        onRefresh: () => _loadTasks(force: true),
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Header & Calendar Grid
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(), // Now Header is outside the AnimatedSwitcher!
                  const SizedBox(height: 24),
                  _buildWeekDays(), // And Weekdays too (optional, but good for static feeling)
                  const SizedBox(height: 16),
                  GestureDetector(
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
                    child: _buildCalendarGrid(key: ValueKey<DateTime>(_currentMonth)),
                  ),
                ),
              ],
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
            
            // Individu / Team tab — sliding pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double pillH = 38.0;
                    const double padding = 4.0;
                    final double pillW = (constraints.maxWidth - padding * 2) / 2;
                    return Container(
                      height: pillH + padding * 2,
                      padding: const EdgeInsets.all(padding),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeInOut,
                            left: _taskTab == 0 ? 0 : pillW,
                            top: 0,
                            bottom: 0,
                            width: pillW,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              _buildTab('Individu', 0, pillW, pillH),
                              _buildTab('Team', 1, pillW, pillH),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            
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
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
                  ],
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

  Widget _buildCalendarGrid({Key? key}) {
    final days = _getDaysInMonth(_currentMonth);

    return Padding(
      key: key,
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

    final tabFilteredTasks = _taskTab == 0
        ? _selectedDayTasks.where((t) => t.teamId == null).toList()
        : _selectedDayTasks.where((t) => t.teamId != null).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) {
              final isForward = _taskTab >= _prevTaskTab;
              final begin = isForward
                  ? const Offset(1.0, 0.0)
                  : const Offset(-1.0, 0.0);

              return SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_taskTab),
              child: tabFilteredTasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: Color(0xFFB0A495),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _taskTab == 0
                                ? 'No individual tasks for this day'
                                : 'No team tasks for this day',
                            style: const TextStyle(
                              color: Color(0xFF8B7E6F),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: tabFilteredTasks.map((task) {
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
                      }).toList(),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, double width, double height) {
    final isActive = _taskTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _prevTaskTab = _taskTab;
        _taskTab = index;
      }),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
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

String _getFormattedTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return 'All day';
  try {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
  } catch (_) {}
  return timeStr;
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
        isOwner: task.teamId == null,
        currentUserEmail: currentUserEmail,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Priority badge + Time (for individual) OR just Time (for team)
                  Row(
                    children: [
                      _buildPriorityBadge(),
                      const SizedBox(width: 8),
                      Text(
                        _getFormattedTime(task.dueTime),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D544E),
                        ),
                      ),
                    ],
                  ),
                  // Assign to (team tasks only)
                  if (task.teamId != null && task.assignedEmails != null && task.assignedEmails!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Assign to: ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF5D544E)),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: task.assignedEmails!.split(',').map((email) {
                              final trimmedEmail = email.trim();
                              if (trimmedEmail.isEmpty) return const SizedBox.shrink();
                              final isCurrentUser = currentUserEmail != null &&
                                  trimmedEmail.toLowerCase() == currentUserEmail!.toLowerCase().trim();
                              final displayName = isCurrentUser
                                  ? 'You'
                                  : (trimmedEmail.contains('@') ? trimmedEmail.split('@').first : trimmedEmail);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D2633),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person, size: 10, color: Colors.white70),
                                    const SizedBox(width: 3),
                                    Text(
                                      displayName,
                                      style: const TextStyle(fontSize: 11, color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Description
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Color(0xFF5D544E), height: 1.4),
                        children: [
                          const TextSpan(
                            text: 'Description : ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: task.description!.length > 80
                                ? '${task.description!.substring(0, 80)}...'
                                : task.description,
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
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                              Text("Offline: Connection Required",
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildPriorityBadge() {
    Color bgColor;
    Color textColor;
    String label;
    switch (task.priority.toLowerCase()) {
      case 'high':
        bgColor = const Color(0xFFFFE5E5);
        textColor = const Color(0xFFCC0000);
        label = 'High Priority';
        break;
      case 'medium':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        label = 'Medium';
        break;
      default:
        bgColor = const Color(0xFFE5F5E5);
        textColor = const Color(0xFF155724);
        label = 'Low';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}

class _TaskDetailSheet extends StatelessWidget {
  final TaskLocal task;
  final String? currentUserEmail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOwner;

  const _TaskDetailSheet({
    required this.task,
    this.currentUserEmail,
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
    return _getFormattedTime(task.dueTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
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
                decoration: const BoxDecoration(
                  color: AppColors.surface,
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

          // ── Assign to (team tasks only) ──
          if (task.teamId != null && task.assignedEmails != null && task.assignedEmails!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Assigned To',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: task.assignedEmails!.split(',').map((email) {
                final trimmedEmail = email.trim();
                if (trimmedEmail.isEmpty) return const SizedBox.shrink();
                final isCurrentUser = currentUserEmail != null &&
                    trimmedEmail.toLowerCase() == currentUserEmail!.toLowerCase().trim();
                final displayName = isCurrentUser
                    ? 'You'
                    : (trimmedEmail.contains('@') ? trimmedEmail.split('@').first : trimmedEmail);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2633),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 10, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

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
              color: AppColors.surface,
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
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
