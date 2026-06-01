import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/native_text_input.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_service.dart';
import '../../../../core/models/user.dart';
import '../models/task_local.dart';
import '../services/task_repository.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/utils/notification_helper.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../core/utils/time_utils.dart';
import 'create_task_page.dart';
import '../services/reminder_service.dart';
import '../widgets/priority_badge.dart';

class TaskPage extends StatefulWidget {
  final AuthService? authService;
  final String? taskId; // Added for deep linking
  final DateTime? filterDate; // Added for today task filtering
  const TaskPage({super.key, this.authService, this.taskId, this.filterDate});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _pageSize = 5;

  final TaskRepository _repository = TaskRepository();
  final TextEditingController _searchController = TextEditingController();
  List<TaskLocal> _tasks = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _isOffline = false;
  int _personalPage = 1;
  int _teamPage = 1;
  String _searchQuery = '';
  StreamSubscription? _connectivitySubscription;
  StreamSubscription<void>? _teamEventSubscription;
  StreamSubscription<List<TaskLocal>>? _tasksSubscription;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addObserver(this);
    _checkInitialConnection();
    _connectivitySubscription = ConnectionService().isConnectedStream.listen((
      connected,
    ) {
      if (mounted) {
        setState(() {
          _isOffline = !connected;
        });
        if (connected) {
          _loadTasks();
        }
      }
    });
    _teamEventSubscription = NotificationHelper.onTeamEvent.listen((_) {
      if (mounted && !_isOffline) _loadTasks(forceSync: true);
    });
    _loadTasks().then((_) {
      if (widget.taskId != null) {
        final task = _tasks
            .where((t) => t.id.toString() == widget.taskId)
            .firstOrNull;
        if (task != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTaskDetails(task);
          });
        }
      }
    });
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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _teamEventSubscription?.cancel();
    _tasksSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks({bool forceSync = false}) async {
    setState(() => _isLoading = true);
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';
    if (mounted) {
      setState(() => _currentUser = user);
    }

    await _tasksSubscription?.cancel();
    final taskStream = widget.filterDate != null
        ? _repository.watchTasksForDate(widget.filterDate!, userEmail)
        : _repository.watchAllTasks(userEmail);
    _tasksSubscription = taskStream.listen((tasks) {
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    });

    if (userEmail != 'guest') {
      await _repository.fetchTasksFromServer(userEmail, force: forceSync);
    }
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery == _searchQuery) return;
    setState(() {
      _searchQuery = nextQuery;
      _personalPage = 1;
      _teamPage = 1;
    });
  }

  bool get _isGuest => _currentUser?.isGuest ?? _currentUser?.email == null;

  bool get _isAllTasksPage => widget.filterDate == null;

  Future<void> _toggleTask(TaskLocal task) async {
    final user = await widget.authService?.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    await _repository.toggleTaskStatus(task, userEmail);
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task'),
        content: const Text('You want delete this tasks?'),
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
    final isTeam = task.teamId != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        currentUserEmail: _currentUser?.email ?? '',
        onDelete: isTeam
            ? null
            : () {
                Navigator.pop(context);
                _deleteTask(task);
              },
        onEdit: isTeam
            ? null
            : () {
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
    final filteredTasks = _filteredTasks(_tasks);
    final personalTasks = filteredTasks.where((t) => t.teamId == null).toList();
    final teamTasks = filteredTasks.where((t) => t.teamId != null).toList();

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
        title: Text(
          _isAllTasksPage ? 'All Task' : 'Today Task',
          style: const TextStyle(
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
          : Column(
              children: [
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const double pillH = 38.0;
                          const double padding = 4.0;
                          final double pillW =
                              (constraints.maxWidth - padding * 2) / 2;
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
                                  left: _tabController.index == 0 ? 0 : pillW,
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
                                    _buildPillTab('Individu', 0, pillW, pillH),
                                    _buildPillTab('Team', 1, pillW, pillH),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                if (_isAllTasksPage)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                          Expanded(
                            child: NativeTextInput(
                              controller: _searchController,
                              hintText: 'Search tasks',
                              height: 46,
                              borderWidth: 0,
                              borderColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              textInputAction: TextInputAction.search,
                              fallbackBuilder: (context) => TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search tasks',
                                  hintStyle: TextStyle(
                                    color: AppColors.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: _searchController.clear,
                            )
                          else
                            const SizedBox(width: 14),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(personalTasks, isTeamTab: false),
                      _isGuest
                          ? _buildLoginRequiredState()
                          : _buildTaskList(teamTasks, isTeamTab: true),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: AppColors.primaryDark,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  List<TaskLocal> _filteredTasks(List<TaskLocal> tasks) {
    if (_searchQuery.isEmpty) return tasks;
    return tasks.where((task) {
      final haystack = [
        task.title,
        task.description ?? '',
        task.priority,
        task.dueTime ?? '',
        task.assignedEmails ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  Widget _buildPillTab(String label, int index, double width, double height) {
    final isActive = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
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

  Widget _buildTaskList(List<TaskLocal> tasks, {required bool isTeamTab}) {
    if (isTeamTab && _isOffline) {
      return _buildConnectionRequiredState();
    }

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    final uncompleted = tasks.where((t) => !t.isCompleted).toList();
    final completed = tasks.where((t) => t.isCompleted).toList();
    final sortedTasks = [...uncompleted, ...completed];
    final totalPages = (sortedTasks.length / _pageSize).ceil().clamp(1, 999999);
    final currentPage = isTeamTab ? _teamPage : _personalPage;
    final safePage = currentPage.clamp(1, totalPages).toInt();
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, sortedTasks.length);
    final pageTasks = sortedTasks.sublist(startIndex, endIndex);

    if (safePage != currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (isTeamTab) {
            _teamPage = safePage;
          } else {
            _personalPage = safePage;
          }
        });
      });
    }

    final showPagination = _isAllTasksPage && totalPages > 1;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: pageTasks.length + (showPagination ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (showPagination && index == pageTasks.length) {
          return _TaskPagination(
            currentPage: safePage,
            totalPages: totalPages,
            onPageChanged: (page) {
              setState(() {
                if (isTeamTab) {
                  _teamPage = page;
                } else {
                  _personalPage = page;
                }
              });
            },
          );
        }

        final task = pageTasks[index];
        return _TodayTaskCard(
          task: task,
          onToggle: () {
            if (_isOffline) return;
            _toggleTask(task);
          },
          onTap: () {
            if (_isOffline) return;
            _showTaskDetails(task);
          },
          isOffline: _isOffline,
        );
      },
    );
  }

  Widget _buildConnectionRequiredState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Connection Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please connect to the internet to use this feature.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequiredState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 72,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'You Need To Login To use This Feature',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
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
  bool _teamCompletionLocked = false;

  @override
  void initState() {
    super.initState();
    _localCompleted = widget.task.isCompleted;
    _teamCompletionLocked =
        widget.task.teamId != null && widget.task.isCompleted;
  }

  @override
  void didUpdateWidget(_TodayTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _teamCompletionLocked =
          widget.task.teamId != null && widget.task.isCompleted;
    } else if (widget.task.teamId != null && widget.task.isCompleted) {
      _teamCompletionLocked = true;
    }
    if (!_isToggling) {
      _localCompleted = _teamCompletionLocked || widget.task.isCompleted;
    }
  }

  void _handleToggle() {
    if (_isToggling) return;
    final isTeamTask = widget.task.teamId != null;
    if (isTeamTask && _teamCompletionLocked) {
      ErrorHandler.showErrorPopup(
        'This team task is locked. Ask the team leader to reopen it from Team Task.',
        title: 'Team Task Locked',
      );
      return;
    }
    _isToggling = true;
    setState(() {
      if (isTeamTask) {
        _localCompleted = true;
        _teamCompletionLocked = true;
      } else {
        _localCompleted = !_localCompleted;
      }
    });
    widget.onToggle();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _isToggling = false;
    });
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
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
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
                              TaskPriorityBadge(priority: widget.task.priority),
                              const SizedBox(width: 10),
                              // Date if exists
                              if (widget.task.dueDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    DateFormat(
                                      'd MMM yyyy',
                                    ).format(widget.task.dueDate!),
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

class _TaskPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _TaskPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navButton(
                  '<<',
                  currentPage > 1 ? () => onPageChanged(1) : null,
                ),
                _navButton(
                  '<',
                  currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                ),
                for (final page in pages)
                  page == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '..',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : _pageButton(page),
                _navButton(
                  '>',
                  currentPage < totalPages
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                ),
                _navButton(
                  '>>',
                  currentPage < totalPages
                      ? () => onPageChanged(totalPages)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<int?> _visiblePages() {
    if (totalPages <= 5) {
      return [for (var page = 1; page <= totalPages; page++) page];
    }

    final start = (currentPage - 2).clamp(1, totalPages - 4).toInt();
    final pages = [for (var page = start; page < start + 5; page++) page];
    if (pages.last < totalPages) return [...pages, null];
    return pages;
  }

  Widget _pageButton(int page) {
    final isActive = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isActive ? null : () => onPageChanged(page),
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          height: 30,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null ? AppColors.textTertiary : AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail Bottom Sheet ────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final TaskLocal task;
  final String currentUserEmail;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _TaskDetailSheet({
    required this.task,
    required this.currentUserEmail,
    this.onDelete,
    this.onEdit,
  });

  String _formatTime() {
    return AppTimeUtils.formatTo24h(task.dueTime);
  }

  List<String> _assignedEmails(TaskLocal task) {
    return (task.assignedEmails ?? '')
        .split(',')
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Drag handle ───
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // ── Priority Badge ──
              TaskPriorityBadge(
                priority: task.priority,
                iconSize: 16,
                fontSize: 13,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 20),

              // ── Date ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
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
                        DateFormat(
                          'MMM dd, yyyy',
                        ).format(task.dueDate ?? DateTime.now()),
                        style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (task.teamId != null) ...[
                const Text(
                  'Assign To',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      (_assignedEmails(task).isEmpty
                              ? ['No assignee']
                              : _assignedEmails(task))
                          .map((email) {
                            final isPlaceholder = email == 'No assignee';
                            final isMe =
                                !isPlaceholder &&
                                currentUserEmail.isNotEmpty &&
                                email.toLowerCase() ==
                                    currentUserEmail.toLowerCase();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isMe)
                                    const Text('You')
                                  else
                                    Icon(
                                      isPlaceholder
                                          ? Icons.person_off
                                          : Icons.person,
                                      size: 12,
                                    ),
                                  if (!isMe) const SizedBox(width: 4),
                                  if (!isMe)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                ),
                const SizedBox(height: 20),
              ],

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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  task.description ?? 'No description provided.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Action Buttons ──
              if (onDelete != null || onEdit != null)
                Row(
                  children: [
                    if (onDelete != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.background,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  'Delete Task',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: const Text(
                                  'You want to delete this task?',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: AppColors.textTertiary),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onDelete?.call();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[400],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
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
                    if (onDelete != null && onEdit != null)
                      const SizedBox(width: 14),
                    if (onEdit != null)
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
        ),
      ),
    );
  }
}
