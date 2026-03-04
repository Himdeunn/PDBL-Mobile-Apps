import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/bottom_navbar.dart';
import '../../home/pages/home_page.dart';
import '../../task/pages/task_page.dart';
import '../../calendar/pages/calendar_page.dart';
import '../../group/pages/group_page.dart';

class MainNavigation extends StatefulWidget {
  final AuthService authService;

  const MainNavigation({super.key, required this.authService});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(authService: widget.authService),
      TaskPage(authService: widget.authService),
      CalendarPage(authService: widget.authService),
      const GroupPage(),
    ];
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Let the background continue under the curved navbar
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: WudiBottomBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        authService: widget.authService,
      ),
    );
  }
}
