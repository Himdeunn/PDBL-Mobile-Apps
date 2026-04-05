import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_required_dialog.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../task/pages/create_task_page.dart';
import '../../group/pages/create_group_task_page.dart';

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

class _WudiBottomBarState extends State<WudiBottomBar>
    with SingleTickerProviderStateMixin {
  bool _plusMenuOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;
  late int _internalIndex;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  static const _plusSubItems = [
    _NavItemData(
      icon: Icons.person_add_outlined,
      label: 'Create Personal To-Do',
    ),
    _NavItemData(icon: Icons.group_add_outlined, label: 'Create Team Project'),
  ];

  @override
  void initState() {
    super.initState();
    _internalIndex = widget.currentIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant WudiBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      if (!_plusMenuOpen || widget.currentIndex != 1) {
        setState(() {
          _internalIndex = widget.currentIndex;
        });
      }
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _showOverlay() {
    final navigator = Navigator.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _PlusMenuOverlay(
        anim: _expandAnim,
        layerLink: _layerLink,
        onClose: _closePlusMenu,
        onTapItem: (index) async {
          _closePlusMenu();
          if (index == 0) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => CreateTaskPage(authService: widget.authService),
              ),
            );
          } else if (index == 1) {
            if (widget.authService?.currentCachedUser?.isGuest ?? true) {
              AuthRequiredDialog.show(context);
              return;
            }
            if (navigator.context.mounted) {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateGroupTaskPage(authService: widget.authService),
                ),
              );
            }
          }
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _togglePlusMenu() {
    setState(() {
      _plusMenuOpen = !_plusMenuOpen;
      if (_plusMenuOpen) {
        _animController.forward();
        _showOverlay();
      } else {
        _animController.reverse().then((_) {
          if (mounted) _hideOverlay();
        });
      }
    });
  }

  void _closePlusMenu() {
    if (!_plusMenuOpen) return;
    setState(() {
      _plusMenuOpen = false;
      _animController.reverse().then((_) {
        if (mounted) _hideOverlay();
      });
    });
  }

  void _onItemTap(int index) {
    setState(() {
      _internalIndex = index;
    });

    if (index == 1) {
      _togglePlusMenu();
      return;
    }
    _closePlusMenu();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double itemWidth = totalWidth / 4;
              
              // We calculate the center of the active item
              // For index i, the center is at itemWidth * i + itemWidth / 2
              // The indicator's left position (48px wide) would be:
              // center - 24
              final double indicatorLeft = (itemWidth * _internalIndex) + (itemWidth / 2) - 24;

              return Stack(
                children: [
                  // ── Moving Indicator ──
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    left: indicatorLeft,
                    top: (60 - 48) / 2, // Centered vertically in 60px height
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // ── Icons ──
                  Row(
                    children: [
                      Expanded(child: _BottomNavItem(index: 0, icon: Icons.home_rounded)),
                      Expanded(child: _BottomNavItem(index: 1, icon: Icons.add_rounded)),
                      Expanded(child: _BottomNavItem(index: 2, icon: Icons.calendar_month_rounded)),
                      Expanded(child: _BottomNavItem(index: 3, icon: Icons.group_rounded)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final int index;
  final IconData icon;

  const _BottomNavItem({
    required this.index,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // We access the state using findAncestorStateOfType for simplicity or just pass the logic.
    // However, since WudiBottomBar is a StatefulWidget, we can just keep the logic in the parent
    // but the user wants "performa agak cepat", so extracting to a separate widget is good.
    // For this specific implementation, it's easier to keep it as a method or a local widget.
    
    final state = context.findAncestorStateOfType<_WudiBottomBarState>()!;
    final bool isActive = state._internalIndex == index;

    return GestureDetector(
      onTap: () => state._onItemTap(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isActive ? 1.1 : 1.0,
          child: Icon(
            icon,
            size: 28,
            color: isActive ? AppColors.primaryDark : AppColors.surface,
          ),
        ),
      ),
    );
  }
}

// ── Overlay Widget ────────────────────────────────────────────────────────────

class _PlusMenuOverlay extends StatelessWidget {
  final Animation<double> anim;
  final LayerLink layerLink;
  final VoidCallback onClose;
  final Function(int) onTapItem;

  const _PlusMenuOverlay({
    required this.anim,
    required this.layerLink,
    required this.onClose,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    const subBtnSize = 44.0;
    const radius = 38.0; // Brought closer (was 48)
    final angles = [-150.0, -30.0];

    return Stack(
      children: [
        // Backdrop to close menu
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -115), // Adjusted for 60px height bar
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final progress = anim.value;
              if (progress == 0) return const SizedBox.shrink();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  final plusCenterX = barWidth * 0.375;
                  
                  // The container for sub-buttons
                  return SizedBox(
                    width: barWidth,
                    height: 120, // Tall enough to contain the buttons
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(
                        _WudiBottomBarState._plusSubItems.length,
                        (i) {
                          final rad = angles[i] * math.pi / 180;
                          final dx = radius * math.cos(rad) * progress;
                          final dy = radius * math.sin(rad) * progress;

                          // The plus icon center is roughly at the bottom of this 120h box
                          // So we add 110 to dy to position it relative to the top of the box
                          return Positioned(
                            left: plusCenterX + dx - subBtnSize / 2,
                            top: 110 + dy - subBtnSize / 2, 
                            child: Transform.scale(
                              scale: progress.clamp(0.0, 1.0),
                              child: Opacity(
                                opacity: progress.clamp(0.0, 1.0),
                                child: GestureDetector(
                                  onTap: () => onTapItem(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: subBtnSize,
                                    height: subBtnSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.surface,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _WudiBottomBarState._plusSubItems[i].icon,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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

// ─── Data ─────────────────────────────────────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}