import 'dart:async';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/time_utils.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/user.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/pages/welcome_page.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/register_page.dart';
import '../widgets/home_header.dart';
import '../widgets/search_bar.dart';
import '../widgets/week_strip.dart';
import '../widgets/daily_task_list.dart';
import '../../task/models/task_local.dart';
import '../../task/pages/task_page.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../profile/pages/profile_page.dart';
import '../../profile/pages/notification_page.dart';

class HomePage extends StatefulWidget {
  final AuthService authService;
  final VoidCallback? onProfileClick;

  const HomePage({
    super.key,
    required this.authService,
    this.onProfileClick,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  User? _user;
  int _selectedDayIndex = 30;
  DateTime _selectedDate = DateTime.now();
  final TaskRepository _taskRepository = TaskRepository();
  final _searchDebouncer = Debouncer(milliseconds: 300);

  Stream<List<TaskLocal>>? _tasksStream;
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isOffline = false;
  int _taskTab = 0; // 0 = Individu, 1 = Team
  int _prevTaskTab = 0;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription<void>? _teamEventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set user synchronously from in-memory cache so first frame shows correct data
    _user = widget.authService.currentCachedUser;
    _checkInitialConnection();
    _connectivitySubscription = ConnectionService().isConnectedStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isOffline = !connected;
        });
        if (connected) {
          _loadData();
        }
      }
    });
    _teamEventSubscription = NotificationHelper.onTeamEvent.listen((_) {
      _loadData(_selectedDate, true);
    });
    _loadData(_selectedDate);
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
      _loadData(_selectedDate, true);
    }
  }

  Future<void> _loadData([DateTime? targetDate, bool forceSync = false]) async {
    final dateToLoad = targetDate ?? _selectedDate;

    // Show cached user immediately for fast first frame
    final cachedUser = await widget.authService.getCachedUser();
    if (cachedUser != null && mounted) {
      setState(() => _user = cachedUser);
    }

    final user = await widget.authService.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    if (mounted) {
      setState(() {
        if (user != null) _user = user;
        _isLoading = true;
        _tasksStream = _taskRepository.watchTasksForDate(dateToLoad, userEmail);
      });
    }

    if (userEmail == 'guest') {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // fetchTasksFromServer respects a 2-minute cooldown unless force=true (pull-to-refresh)
    _taskRepository.fetchTasksFromServer(userEmail, force: forceSync).then((_) {
      if (mounted) setState(() => _isLoading = false);
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onDaySelected(DateTime date) {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 30));
    final diff = date.difference(start).inDays;

    setState(() {
      _selectedDate = date;
      _selectedDayIndex = diff;
    });
    _loadData(date);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    await widget.authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  void _goToProfile() async {
    if (widget.onProfileClick != null) {
      widget.onProfileClick!();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(authService: widget.authService)),
      );
      // Re-subscribe stream in case user changed, but don't force a server sync
      _loadData(_selectedDate, false);
    }
  }

  void _goToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _teamEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'Guest';
    final isGuest = _user?.isGuest ?? true;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 900
        ? screenWidth * 0.15
        : screenWidth > 600
        ? screenWidth * 0.08
        : 20.0;

    return RefreshIndicator(
      onRefresh: () => _loadData(_selectedDate, true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          MediaQuery.of(context).padding.top + 16.0,
          horizontalPadding,
          120 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeHeader(
              displayName: displayName,
              avatarUrl: _user?.avatarUrl,
              isGuest: isGuest,
              todayTarget: _user?.todayTarget ?? 0,
              onNotificationTap: _goToNotifications,
              onProfileTap: _goToProfile,
            ),
            const SizedBox(height: 16),
            WudiSearchBar(
              onChanged: (value) {
                _searchDebouncer.run(() {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                    });
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            WeekStrip(
              selectedIndex: _selectedDayIndex,
              onDaySelected: _onDaySelected,
            ),
            const SizedBox(height: 32),
            StreamBuilder<List<TaskLocal>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];

                final filteredTasks = _searchQuery.isEmpty
                    ? tasks
                    : tasks.where((task) {
                        return task.title.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (task.description?.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false);
                      }).toList();

                int getWeight(String p) {
                  switch (p.toLowerCase()) {
                    case 'high': return 3;
                    case 'medium': return 2;
                    case 'low': return 1;
                    default: return 0;
                  }
                }

                List<TaskLocal> sortUncompleted(List<TaskLocal> list) {
                  final sorted = list.where((t) => !t.isCompleted).toList();
                  sorted.sort((a, b) {
                    if (a.dueTime != null && b.dueTime != null) {
                      final c = a.dueTime!.compareTo(b.dueTime!);
                      if (c != 0) return c;
                    } else if (a.dueTime != null) {
                      return -1;
                    } else if (b.dueTime != null) {
                      return 1;
                    }
                    return getWeight(b.priority).compareTo(getWeight(a.priority));
                  });
                  return sorted;
                }

                final uncompletedPersonal = sortUncompleted(tasks.where((t) => t.teamId == null).toList());
                final uncompletedTeam    = sortUncompleted(tasks.where((t) => t.teamId != null).toList());

                // Focus Today: based on selected tab, auto-fallback to other if tab is empty
                TaskLocal? focusTask;
                if (_taskTab == 0) {
                  focusTask = uncompletedPersonal.firstOrNull ?? uncompletedTeam.firstOrNull;
                } else {
                  focusTask = uncompletedTeam.firstOrNull ?? uncompletedPersonal.firstOrNull;
                }

                // Tab filter: individu = no teamId, team = has teamId
final tabFilteredTasks = _taskTab == 0
? filteredTasks.where((t) => t.teamId == null).toList()
: filteredTasks.where((t) => t.teamId != null).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Today',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width > 400
                            ? 18
                            : 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading && focusTask == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (focusTask != null)
                      _buildFocusCard(focusTask)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
child: Center(
child: Text(
'No focus for today yet.',
style: TextStyle(
color: AppColors.textSecondary,
fontSize: 14,
),
),
                        ),
                      ),
const SizedBox(height: 32),
                    // Today Task header + SEE ALL
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskPage(
                                authService: widget.authService,
                                filterDate: _selectedDate,
                              ),
                            ),
                          ),
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
                    const SizedBox(height: 12),
                    // Individu / Team tab — sliding pill
                    LayoutBuilder(
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
                              // Sliding active pill
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
                              // Labels
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
                    const SizedBox(height: 16),
                    ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) {
                          final isForward = _taskTab >= _prevTaskTab;
                          final begin = isForward
                              ? const Offset(1.0, 0.0)
                              : const Offset(-1.0, 0.0);
                          final slide = Tween<Offset>(
                                  begin: begin, end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic));
                          return SlideTransition(
                            position: slide,
                            child: FadeTransition(
                                opacity: animation, child: child),
                          );
                        },
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey<int>(_taskTab),
                          child: DailyTaskList(
                            tasks: tabFilteredTasks,
                            onRefresh: _loadData,
                            authService: widget.authService,
                            isLoading: _isLoading,
                            filterDate: _selectedDate,
                            isOffline: _isOffline,
                            showHeader: false,
                          ),
                        ),
                      ),
                    ),
],
);
              },
            ),
          ],
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

  Widget _buildFocusCard(TaskLocal task) {
    final priorityColor = _getPriorityColor(task.priority);
    final priorityBgColor = _getPriorityBgColor(task.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getPriorityLabel(task.priority),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (task.teamId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Team',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                task.dueTime != null
                    ? AppTimeUtils.formatTo24h(task.dueTime!)
                    : '08:00 - 10:00',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return '${priority.substring(0, 1).toUpperCase()}${priority.substring(1)} Priority';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFE24B4A);
      case 'medium':
        return const Color(0xFFBA7517);
      case 'low':
        return const Color(0xFF3B6D11);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Color _getPriorityBgColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFE24B4A).withValues(alpha: 0.25);
      case 'medium':
        return const Color(0xFFBA7517).withValues(alpha: 0.25);
      case 'low':
        return const Color(0xFF3B6D11).withValues(alpha: 0.15);
      default:
        return _getPriorityColor(priority).withValues(alpha: 0.15);
    }
  }

}
