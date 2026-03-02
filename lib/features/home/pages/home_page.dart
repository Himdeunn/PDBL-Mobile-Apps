import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/user.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/home_header.dart';
import '../widgets/search_bar.dart';
import '../widgets/week_strip.dart';
import '../widgets/daily_task_list.dart';

class HomePage extends StatefulWidget {
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  int _selectedDayIndex = 0;

  // Empty tasks since there is no database yet
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadUser();

    // Set initial selected day to today (if today is on weekend, default to 0/Monday or clamped to 4/Friday)
    final int weekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun
    _selectedDayIndex = (weekday >= 1 && weekday <= 5) ? weekday - 1 : 0;
  }

  Future<void> _loadUser() async {
    final user = await widget.authService.getCurrentUser();
    if (mounted) setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'Firas';
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.1 : 20.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            HomeHeader(displayName: displayName),
            const SizedBox(height: 24),
            const WudiSearchBar(),
            const SizedBox(height: 24),
            WeekStrip(
              selectedIndex: _selectedDayIndex,
              onDaySelected: (index) =>
                  setState(() => _selectedDayIndex = index),
            ),
            const SizedBox(height: 32),
            const Text(
              'Fokus Hari Ini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Empty placeholder for focus card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'Belum ada fokus hari ini.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Pass empty tasks list
            DailyTaskList(tasks: _tasks),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
