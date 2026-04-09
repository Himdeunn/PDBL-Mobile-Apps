import 'dart:async';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/utils/image_utils.dart';
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
import '../../task/services/task_repository.dart';
import '../../../../core/services/connection_service.dart';
import '../../profile/pages/profile_page.dart';
import '../../profile/pages/notification_page.dart';

class HomePage extends StatefulWidget {
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  int _selectedDayIndex = 30;
  DateTime _selectedDate = DateTime.now();
  final TaskRepository _taskRepository = TaskRepository();
  final _searchDebouncer = Debouncer(milliseconds: 300);

  Stream<List<TaskLocal>>? _tasksStream;
  bool _isLoading = true;
  String _searchQuery = '';
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
          _loadData();
        }
      }
    });
    _loadData(_selectedDate);
  }

  Future<void> _checkInitialConnection() async {
    final connected = await ConnectionService().isConnected();
    if (mounted) {
      setState(() {
        _isOffline = !connected;
      });
    }
  }

  Future<void> _loadData([DateTime? targetDate]) async {
    final dateToLoad = targetDate ?? _selectedDate;
    
    // 1. Get cached user immediately for fast UI response
    final cachedUser = await widget.authService.getCachedUser();
    if (cachedUser != null && mounted) {
      setState(() {
        _user = cachedUser;
      });
    }

    // 2. Perform regular fetch (now faster due to AuthService caching)
    final user = await widget.authService.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = true;
        _tasksStream = _taskRepository.watchTasksForDate(dateToLoad, userEmail);
      });
    }

    if (userEmail == 'guest') {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _taskRepository.fetchTasksFromServer(userEmail).then((_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(authService: widget.authService)),
    );
    _loadData();
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
    _connectivitySubscription?.cancel();
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
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          MediaQuery.of(context).padding.top + 16.0,
          horizontalPadding,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeHeader(
              displayName: displayName,
              avatarUrl: _user?.avatarUrl,
              isGuest: isGuest,
              todayTarget: _user?.todayTarget ?? 0,
              onAvatarTap: _goToProfile,
              onNotificationTap: _goToNotifications,
              onLogoutTap: _logout,
              onLoginTap: _goToLogin,
              onRegisterTap: _goToRegister,
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

                final uncompletedTasks = tasks
                    .where((t) => !t.isCompleted)
                    .toList();

                uncompletedTasks.sort((a, b) {
                  if (a.dueTime != null && b.dueTime != null) {
                    final timeCompare = a.dueTime!.compareTo(b.dueTime!);
                    if (timeCompare != 0) return timeCompare;
                  } else if (a.dueTime != null) {
                    return -1;
                  } else if (b.dueTime != null) {
                    return 1;
                  }

                  int getWeight(String p) {
                    switch (p.toLowerCase()) {
                      case 'high':
                        return 3;
                      case 'medium':
                        return 2;
                      case 'low':
                        return 1;
                      default:
                        return 0;
                    }
                  }

                  final weightA = getWeight(a.priority);
                  final weightB = getWeight(b.priority);
                  return weightB.compareTo(weightA);
                });

                final focusTask = uncompletedTasks.firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Focus',
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
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'No focus for today yet.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    DailyTaskList(
                      tasks: filteredTasks,
                      onRefresh: _loadData,
                      authService: widget.authService,
                      isLoading: _isLoading,
                      filterDate: _selectedDate,
                      isOffline: _isOffline,
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

  Widget _buildFocusCard(TaskLocal task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEADBC8).withValues(alpha: 0.75),
            const Color(0xFF2F2235).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getPriorityBgColor(task.priority),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getPriorityLabel(task.priority),
                  style: TextStyle(
                    color: _getPriorityColor(task.priority),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4A453C), width: 1.5),
                ),
                child: _user?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          ImageUtils.getAvatarUrl(_user!.avatarUrl!),
                          key: ValueKey(_user!.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, __) {
                            return const Icon(Icons.person, size: 24, color: Color(0xFF4A453C));
                          },
                        ),
                      )
                    : CircleAvatar(
                        key: const ValueKey('default_avatar'),
                        backgroundColor: const Color(0xFFC4D7D6),
                        child: const Icon(Icons.person, size: 24, color: Colors.black54),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: const TextStyle(
              color: Color(0xFF4A453C),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (task.description != null && task.description!.isNotEmpty)
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6D685E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4A453C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  task.dueTime != null
                      ? AppTimeUtils.formatTo24h(task.dueTime!)
                      : '08:00 - 10:00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
        return priority.substring(0, 1).toUpperCase() + priority.substring(1) + ' Priority';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF0000); // Pure Red
      case 'medium':
        return const Color(0xFFA49C00); // Dark Olive (Text)
      case 'low':
        return const Color(0xFF16A34A); // Forest Green
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Color _getPriorityBgColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'medium':
        return const Color(0xFFD4EA0C).withValues(alpha: 0.15); // Lime/Yellow Tint
      default:
        return _getPriorityColor(priority).withValues(alpha: 0.15);
    }
  }

  String _formatTime(String timeStr, BuildContext context) {
    return AppTimeUtils.formatTo24h(timeStr);
  }
}
