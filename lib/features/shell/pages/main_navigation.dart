import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/navigator_service.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../../../core/utils/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../auth/services/auth_service.dart';
import '../../chat/pages/chat_room_page.dart';
import '../../chat/services/chat_service.dart';
import '../widgets/bottom_navbar.dart';
import '../../home/pages/home_page.dart';
import '../../calendar/pages/calendar_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../group/pages/group_page.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/widgets/maintenance_dialog.dart';
import '../../../../core/widgets/update_dialog.dart';

class MainNavigation extends StatefulWidget {
  final AuthService authService;
  final Uri? initialWidgetUri;
  const MainNavigation({
    super.key,
    required this.authService,
    this.initialWidgetUri,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Bar indices: 0=Home, 1=Task, 2=FAB, 3=Group, 4=Calendar, 5=Profile
  int _currentIndex = 0;
  late final List<Widget> _pages;
  StreamSubscription<void>? _rcSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSub;
  StreamSubscription<void>? _widgetDashboardSub;
  StreamSubscription<void>? _teamEventSub;

  // Maps bar index → _pages index (index 2 / FAB handled separately)
  static int _pageIndex(int barIndex) {
    switch (barIndex) {
      case 1:
        return 1; // Calendar
      case 3:
        return 2; // Project Team
      case 4:
        return 3; // Profile
      default:
        return 0; // Home
    }
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        authService: widget.authService,
        onProfileClick: () => _onNavTap(4),
      ),
      CalendarPage(authService: widget.authService),
      GroupPage(authService: widget.authService),
      ProfilePage(authService: widget.authService),
    ];

    // Real-time remote config: listen for server-pushed changes
    _rcSubscription = RemoteConfigService.onUpdated.listen((_) {
      if (mounted) _handleRemoteConfigUpdate();
    });

    // Background/foreground notification tap → switch to correct tab
    _notificationTapSub = NotificationHelper.onNotificationTap.listen((data) {
      NotificationHelper.claimInitialTap(); // consume pending so postFrameCallback skips it
      if (mounted) _handleNotificationTap(data);
    });

    _teamEventSub = NotificationHelper.onTeamEvent.listen((_) {
      _refreshTeamTasksFromServer();
    });

    _widgetDashboardSub = WidgetService.dashboardRequested.listen((_) {
      if (mounted) _onNavTap(0);
    });

    // Terminated-state notification tap → claim after first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialWidgetUri != null && mounted) {
        WidgetService.handleWidgetClick(widget.initialWidgetUri);
      }

      final data = NotificationHelper.claimInitialTap();
      if (data != null && mounted) _handleNotificationTap(data);
    });
  }

  /// Maps FCM/local notification type to a bottom-bar index and switches tab.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').toLowerCase();
    final conversationId = int.tryParse(
      (data['conversation_id'] ?? '').toString(),
    );
    final int barIndex;
    switch (type) {
      case 'chat':
        barIndex = 3;
        break;
      case 'invite':
      case 'kick':
      case 'ban':
      case 'team':
        barIndex = 3; // Group tab
        break;
      case 'new_task':
      case 'task_update':
      case 'todo_reminder':
      case 'update':
        barIndex = 0; // Home tab
        break;
      default:
        return; // Unknown type — don't navigate
    }
    if (conversationId != null) {
      _openChatNotification(conversationId);
      return;
    }
    _onNavTap(barIndex);
  }

  Future<void> _openChatNotification(int conversationId) async {
    _onNavTap(3);
    final currentUser = await widget.authService.getCachedUser();
    if (!mounted || currentUser == null || currentUser.isGuest) return;

    try {
      final conversation = await ChatService().getConversation(conversationId);
      if (!mounted) return;
      if (conversation == null) {
        ErrorHandler.showErrorPopup(
          'Could not open this chat. Please try again.',
        );
        return;
      }

      await NotificationHelper.cancelChatNotification(conversation.id);
      await NavigatorService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            conversation: conversation,
            currentUser: currentUser,
            authService: widget.authService,
          ),
        ),
      );
    } catch (error) {
      ErrorHandler.handleApiError(error);
    }
  }

  Future<void> _refreshTeamTasksFromServer() async {
    final user = await widget.authService.getCurrentUser();
    final userEmail = user?.email;
    if (user == null || user.isGuest || userEmail == null) return;

    await TaskRepository().fetchTasksFromServer(userEmail, force: true);
  }

  Future<void> _handleRemoteConfigUpdate() async {
    if (!mounted) return;

    // ── Maintenance (highest priority, blocking) ─────────────────────────────
    if (RemoteConfigService.maintenanceEnabled) {
      await MaintenanceDialog.show(
        context,
        title: RemoteConfigService.maintenanceTitle,
        message: RemoteConfigService.maintenanceMessage,
        estimatedEnd: RemoteConfigService.maintenanceEstimatedEnd,
      );
      return;
    }

    // ── Force update only (critical, blocking) ───────────────────────────────
    // Optional updates are intentionally NOT shown from the real-time listener
    // to avoid popping up every time any config value changes (e.g. turning
    // maintenance OFF). Optional updates are already shown at app launch.
    if (RemoteConfigService.forceUpdateEnabled) {
      final packageInfo = await PackageInfo.fromPlatform();
      final isBelowMin =
          RemoteConfigService.compareVersions(
            packageInfo.version,
            RemoteConfigService.minVersion,
          ) <
          0;
      if (!mounted) return;
      if (isBelowMin) {
        await UpdateDialog.show(
          context,
          title: RemoteConfigService.updateTitle,
          message: RemoteConfigService.updateMessage,
          changelog: RemoteConfigService.updateChangelog,
          updateUrl: RemoteConfigService.updateUrlAndroid,
          isForced: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _rcSubscription?.cancel();
    _notificationTapSub?.cancel();
    _widgetDashboardSub?.cancel();
    _teamEventSub?.cancel();
    super.dispose();
  }

  void _onNavTap(int barIndex) {
    if (barIndex == _currentIndex) return;
    setState(() => _currentIndex = barIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Page content
          SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 68 + MediaQuery.of(context).padding.bottom,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: IndexedStack(
                    key: ValueKey<int>(_currentIndex),
                    index: _pageIndex(_currentIndex),
                    children: _pages,
                  ),
                ),
              ),
            ),
          ),

          // Navbar nempel di bawah (tidak mengambang)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? -150 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
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
