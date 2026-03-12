import '../../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../../task/pages/create_task_page.dart';
import '../../group/pages/create_group_task_page.dart';
import '../../auth/pages/welcome_page.dart';

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
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
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
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => _PlusMenuOverlay(
        anim: _expandAnim,
        layerLink: _layerLink,
        onClose: _closePlusMenu,
        onTapItem: (index) async {
          _closePlusMenu();
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskPage(authService: widget.authService),
              ),
            );
          } else if (index == 1) {
            final user = await widget.authService?.getCurrentUser();
            if (user == null || user.isGuest) {
              if (context.mounted) {
                _showAuthRequiredDialog(context);
              }
              return;
            }

            if (context.mounted) {
              Navigator.push(
                context,
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

  void _showAuthRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
          'Creating team projects is only available for registered users. Would you like to log in or register now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
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
        _animController.reverse().then((_) => _hideOverlay());
      }
    });
  }

  void _closePlusMenu() {
    if (!_plusMenuOpen) return;
    setState(() {
      _plusMenuOpen = false;
      _animController.reverse().then((_) => _hideOverlay());
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
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32, top: 0),
        child: Container(
          height: 85, // Buffered height for rising icon
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: CurvedNavigationBar(
                    index: _internalIndex,
                    backgroundColor: Colors.transparent,
                    color: AppColors.primaryDark,
                    buttonBackgroundColor: AppColors.surface,
                    animationDuration: const Duration(milliseconds: 300),
                    height: 65, // Thin bar look
                    letIndexChange: (index) => true,
                    onTap: _onItemTap,
                    items: [
                      Icon(
                        Icons.home_rounded,
                        size: 28,
                        color: _internalIndex == 0
                            ? AppColors.primaryDark
                            : AppColors.surface,
                      ),
                      Icon(
                        Icons.add,
                        size: 28,
                        color: _internalIndex == 1
                            ? AppColors.primaryDark
                            : AppColors.surface,
                      ),
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 28,
                        color: _internalIndex == 2
                            ? AppColors.primaryDark
                            : AppColors.surface,
                      ),
                      Icon(
                        Icons.group_outlined,
                        size: 28,
                        color: _internalIndex == 3
                            ? AppColors.primaryDark
                            : AppColors.surface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    const radius = 48.0;
    final angles = [-150.0, -30.0];

    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, -75), // Perfectly above the plus button
              child: AnimatedBuilder(
                animation: anim,
                builder: (context, _) {
                  final progress = anim.value;
                  if (progress == 0) return const SizedBox.shrink();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final barWidth = constraints.maxWidth;
                      // Centering logic for 4 items: plus is centered at (Width / 4) * 1.5 approx? 
                      // Actually 4 items means centers are at 1/8, 3/8, 5/8, 7/8. 
                      // "Add" is index 1, so center is 3/8 = 0.375
                      final plusCenterX = barWidth * 0.375;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ...List.generate(
                            _WudiBottomBarState._plusSubItems.length,
                            (i) {
                              final rad = angles[i] * math.pi / 180;
                              final dx = radius * math.cos(rad) * progress;
                              final dy = radius * math.sin(rad) * progress;

                              final left =
                                  plusCenterX + dx - (subBtnSize + 80) / 2;
                              final top = 80.0 + dy - 60.0;

                              return Positioned(
                                left: left,
                                top: top,
                                width: subBtnSize + 80,
                                child: Transform.scale(
                                  scale: progress.clamp(0.0, 1.0),
                                  child: Opacity(
                                    opacity: progress.clamp(0.0, 1.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _WudiBottomBarState
                                              ._plusSubItems[i]
                                              .label,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () => onTapItem(i),
                                          child: Container(
                                            width: subBtnSize,
                                            height: subBtnSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.surface,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 12,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _WudiBottomBarState
                                                  ._plusSubItems[i]
                                                  .icon,
                                              color: AppColors.primary,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
