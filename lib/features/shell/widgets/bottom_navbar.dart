import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/services/auth_service.dart';
import '../../task/pages/create_task_page.dart';

// #2F2235 navbar bg | #5F4D67 FAB (border #2F2235) | #5F4D67 indicator | #EADBC8 icons/labels
const _kNavBg = Color(0xFF2F2235);
const _kCream = Color(0xFFEADBC8);
const _kPurple = Color(0xFF5F4D67); // FAB circle & active indicator

class WudiBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AuthService? authService;

  const WudiBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.authService,
  });

  @override
  State<WudiBottomBar> createState() => _WudiBottomBarState();
}

class _WudiBottomBarState extends State<WudiBottomBar> {
  late int _internalIndex;

  static const double _barHeight = 68;
  static const double _fabSize = 54;
  static const double _fabOverlap = 22; // seberapa tinggi FAB di atas bar

  @override
  void initState() {
    super.initState();
    _internalIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant WudiBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      setState(() => _internalIndex = widget.currentIndex);
    }
  }

  void _onItemTap(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateTaskPage(authService: widget.authService),
        ),
      );
      return;
    }
    setState(() => _internalIndex = index);
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _fabOverlap + _barHeight + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ── Bar nempel bawah, rounded hanya di atas ──────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: _barHeight + bottomPad,
              decoration: const BoxDecoration(
                color: _kNavBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(bottom: bottomPad),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double itemWidth =
                      totalWidth / 5; // 4 Items + 1 FAB slot
                  final bool showIndicator = _internalIndex != 2;
                  final double indicatorW = itemWidth - 10;
                  final double indicatorLeft = showIndicator
                      ? (itemWidth * _internalIndex) + 5
                      : 0;

                  return Stack(
                    children: [
                      if (showIndicator)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          left: indicatorLeft,
                          top: 8,
                          child: Container(
                            width: indicatorW,
                            height: _barHeight - 16,
                            decoration: BoxDecoration(
                              color: _kPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          _NavItem(
                            index: 0,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                          ),
                          _NavItem(
                            index: 1,
                            icon: Icons.calendar_month_outlined,
                            activeIcon: Icons.calendar_month_rounded,
                            label: 'Calendar',
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _onItemTap(2),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Center(
                                  child: Text(
                                    'Create Task\nIndividu',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: _kCream,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _NavItem(
                            index: 3,
                            icon: Icons.groups_outlined,
                            activeIcon: Icons.groups_rounded,
                            label: 'Project Team',
                          ),
                          _NavItem(
                            index: 4,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profile',
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── FAB circle — lingkaran di atas bar ───────────────────────
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () => _onItemTap(2),
              child: Container(
                width: _fabSize,
                height: _fabSize,
                decoration: BoxDecoration(
                  color: _kPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kNavBg, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x50000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/add_plus_icon.png',
                    width: 24,
                    height: 24,
                    color: _kCream,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_WudiBottomBarState>()!;
    final bool isActive = state._internalIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => state._onItemTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isActive ? 1.1 : 1.0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 22,
                  color: _kCream,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: _kCream,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
