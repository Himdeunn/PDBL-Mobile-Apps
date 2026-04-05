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
      GroupPage(authService: widget.authService),
    ];
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false, // Prevents navbar from following keyboard
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Page content dengan SafeArea hanya di atas ──
          SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100), // Adjusted for slimmer navbar
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: IndexedStack(
                    key: ValueKey<int>(_currentIndex),
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ),
            ),
          ),
          // ── Floating bottom navbar ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: 8,
            right: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                ? -100 // Fully hide below screen when keyboard is up
                : MediaQuery.of(context).padding.bottom + 12,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 1,
              child: ClipRect(
                clipBehavior: Clip.none,
                child: WudiBottomBar(
                  currentIndex: _currentIndex,
                  onTap: _onNavTap,
                  authService: widget.authService,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
