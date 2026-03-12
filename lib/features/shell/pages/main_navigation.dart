import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/bottom_navbar.dart';
import '../../home/pages/home_page.dart';
import '../../task/pages/task_page.dart';
import '../../calendar/pages/calendar_page.dart';
import '../../group/pages/group_page.dart';
import '../../auth/pages/welcome_page.dart';

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

  void _onNavTap(int index) async {
    if (index == _currentIndex) return;

    if (index == 3) {
      final user = await widget.authService.getCurrentUser();
      if (user == null || user.isGuest) {
        if (mounted) {
          _showAuthRequiredDialog();
        }
        return;
      }
    }

    setState(() => _currentIndex = index);
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
          'Group features are only available for registered users. Would you like to log in or register now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login / Register'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Page content dengan SafeArea hanya di atas ──
          SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
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
            ),
          ),
          // ── Floating bottom navbar ──
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: ClipRect(
              clipBehavior: Clip.none,
              child: WudiBottomBar(
                currentIndex: _currentIndex,
                onTap: _onNavTap,
                authService: widget.authService,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
