import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class WudiBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const WudiBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<WudiBottomBar> createState() => _WudiBottomBarState();
}

class _WudiBottomBarState extends State<WudiBottomBar>
    with SingleTickerProviderStateMixin {
  bool _plusMenuOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  static const _plusSubItems = [
    _NavItemData(icon: Icons.person_add_outlined, label: 'Add Person'),
    _NavItemData(icon: Icons.group_add_outlined, label: 'Add Group'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _togglePlusMenu() {
    setState(() {
      _plusMenuOpen = !_plusMenuOpen;
      _plusMenuOpen ? _animController.forward() : _animController.reverse();
    });
  }

  void _closePlusMenu() {
    if (!_plusMenuOpen) return;
    setState(() => _plusMenuOpen = false);
    _animController.reverse();
  }

  void _onItemTap(int index) {
    if (index == 1) {
      _togglePlusMenu();
      return;
    }
    _closePlusMenu();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final safeBottom = bottomPad > 0 ? bottomPad : 10.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Bottom bar ──
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(bottom: safeBottom, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                isSelected: widget.currentIndex == 0,
                onTap: () => _onItemTap(0),
              ),
              _PlusButton(isOpen: _plusMenuOpen, onTap: () => _onItemTap(1)),
              _NavBarItem(
                icon: Icons.calendar_month_rounded,
                isSelected: widget.currentIndex == 2,
                onTap: () => _onItemTap(2),
              ),
              _NavBarItem(
                icon: Icons.person_outline_rounded,
                isSelected: widget.currentIndex == 3,
                onTap: () => _onItemTap(3),
              ),
            ],
          ),
        ),

        // ── Arc sub-buttons ──
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          height: 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              // Plus is item index 1 of 4 in spaceAround
              // Center of item i = (2i+1) * width / (2*n)
              final plusCenterX = (3.0) * barWidth / 8.0;

              return AnimatedBuilder(
                animation: _expandAnim,
                builder: (context, _) {
                  final progress = _expandAnim.value;
                  if (progress == 0) return const SizedBox.shrink();

                  const subBtnSize = 44.0;
                  const radius = 45.0;
                  // -150° = upper-left, -30° = upper-right from center
                  final angles = [-150.0, -30.0];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(_plusSubItems.length, (i) {
                      final rad = angles[i] * math.pi / 180;
                      final dx = radius * math.cos(rad) * progress;
                      final dy = radius * math.sin(rad) * progress;

                      // Anchor at bottom-center of this box = top of bar = center of plus button
                      final left = plusCenterX + dx - subBtnSize / 2;
                      // "bottom: 0 + dy" since dy is negative (going up), top = 80 + dy
                      final top = 80.0 + dy - subBtnSize / 2;

                      return Positioned(
                        left: left,
                        top: top,
                        child: Transform.scale(
                          scale: progress.clamp(0.0, 1.0),
                          child: Opacity(
                            opacity: progress.clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: () => _closePlusMenu(),
                              child: Container(
                                width: subBtnSize,
                                height: subBtnSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _plusSubItems[i].icon,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Plus Button — outline/transparent by default, solid when open ────────────

class _PlusButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _PlusButton({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 🔑 Transparent when closed, solid dark when open
              color: isOpen ? AppColors.primary : Colors.transparent,
              boxShadow: isOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.add,
                // 🔑 Dark icon on transparent, white icon on dark bg
                color: isOpen ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Regular Nav Item ─────────────────────────────────────────────────────────

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: isSelected ? 46 : 40,
            height: isSelected ? 46 : 40,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textTertiary,
              size: isSelected ? 24 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}