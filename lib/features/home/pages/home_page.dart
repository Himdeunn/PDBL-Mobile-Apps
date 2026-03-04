import '../../../../core/theme/app_theme.dart';
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

class HomePage extends StatefulWidget {
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  int _selectedDayIndex = 30; // Default to today (index 30 in our 45-day list)
  DateTime _selectedDate = DateTime.now();
  final TaskRepository _taskRepository = TaskRepository();

  Stream<List<TaskLocal>>? _tasksStream;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData(_selectedDate);
  }

  Future<void> _loadData([DateTime? targetDate]) async {
    final dateToLoad = targetDate ?? _selectedDate;
    final user = await widget.authService.getCurrentUser();
    final userEmail = user?.email ?? 'guest';

    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = true;
        _tasksStream = _taskRepository.watchTasksForDate(dateToLoad, userEmail);
      });
    }

    // Pull from server in background
    _taskRepository.fetchTasksFromServer(userEmail).then((_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _onDaySelected(DateTime date) {
    // Find index in the 45-day strip (30 days ago to 14 days future)
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

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'Guest';
    final isGuest = _user?.isGuest ?? true;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.1 : 20.0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              HomeHeader(
                displayName: displayName,
                isGuest: isGuest,
                onLogoutTap: _logout,
                onLoginTap: _goToLogin,
                onRegisterTap: _goToRegister,
              ),
              const SizedBox(height: 24),
              WudiSearchBar(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
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

                  // Apply search filtering
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

                  // Calculate focus task
                  final focusTask =
                      tasks
                          .where((t) => !t.isCompleted && t.priority == 'high')
                          .firstOrNull ??
                      tasks.where((t) => !t.isCompleted).firstOrNull;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fokus Hari Ini',
                        style: TextStyle(
                          fontSize: 18,
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
                            vertical: 40,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada fokus hari ini.',
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
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusCard(TaskLocal task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          if (task.description != null && task.description!.isNotEmpty)
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                task.dueTime ?? 'Whole Day',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
