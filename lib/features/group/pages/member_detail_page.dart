import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/image_cache_manager.dart';
import '../../../../core/utils/network_utils.dart';
import 'package:flutter/material.dart';
import '../../chat/pages/chat_room_page.dart';
import '../../chat/services/chat_service.dart';
import '../../auth/services/auth_service.dart';
import '../../../../core/utils/notification_helper.dart';
import 'edit_team_task_page.dart';
import '../services/team_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/time_utils.dart';

class MemberDetailPage extends StatefulWidget {
  final int teamId;
  final dynamic member;
  final List<dynamic> memberTasks;
  final List<dynamic> teamMembers;
  final String? currentUserEmail;
  final String? teamLeaderId;
  final String? teamLeaderEmail;
  final VoidCallback? onToggle;
  final bool isOwner;
  final bool isOffline;

  const MemberDetailPage({
    super.key,
    required this.teamId,
    required this.member,
    required this.memberTasks,
    this.teamMembers = const [],
    this.currentUserEmail,
    this.teamLeaderId,
    this.teamLeaderEmail,
    this.onToggle,
    this.isOwner = false,
    this.isOffline = false,
  });

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late List<dynamic> _localTasks;

  String _readMemberRole(Map<dynamic, dynamic> member) {
    if (member['is_leader'] == true || member['isLeader'] == true) {
      return 'Team Leader';
    }
    final memberUser = member['user'];
    final memberId = (member['id'] ??
            member['user_id'] ??
            member['userId'] ??
            (memberUser is Map ? memberUser['id'] : null))
        ?.toString();
    if (memberId != null &&
        widget.teamLeaderId != null &&
        memberId == widget.teamLeaderId) {
      return 'Team Leader';
    }

    final memberEmail = (member['email'] ??
            (memberUser is Map ? memberUser['email'] : null))
        ?.toString()
        .toLowerCase()
        .trim();
    final leaderEmail = widget.teamLeaderEmail?.toLowerCase().trim();
    if (memberEmail != null &&
        memberEmail.isNotEmpty &&
        leaderEmail != null &&
        memberEmail == leaderEmail) {
      return 'Team Leader';
    }

    final role = member['role']?.toString();
    if (role == null || role.isEmpty) return 'Member';
    final normalized = role.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized == 'leader' ||
        normalized == 'team leader' ||
        normalized == 'team owner' ||
        normalized == 'owner' ||
        normalized == 'admin') {
      return 'Team Leader';
    }
    if (normalized == 'member') return 'Member';
    return role;
  }

  @override
  void initState() {
    super.initState();
    _localTasks = List.from(widget.memberTasks);
  }

  @override
  void didUpdateWidget(MemberDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memberTasks != oldWidget.memberTasks) {
      _localTasks = List.from(widget.memberTasks);
    }
  }

  Future<void> _syncMemberTasks() async {
    if (widget.isOffline) return;

    final rawData = await TeamService().getTeamDetails(widget.teamId);
    if (rawData is! Map) return;

    final tasksPart = rawData['tasks'];
    final List<dynamic> tasks = tasksPart is List
        ? tasksPart
        : (tasksPart is Map ? tasksPart.values.toList() : []);
    final String memberEmail =
        (widget.member['email'] as String?)?.toLowerCase().trim() ?? '';

    final memberTasks = tasks.where((task) {
      final assignedEmails =
          (task['assigned_emails'] as List<dynamic>?)?.cast<String>() ?? [];
      return memberEmail.isNotEmpty &&
          assignedEmails.any(
            (email) => email.toLowerCase().trim() == memberEmail,
          );
    }).toList();

    if (mounted) {
      setState(() => _localTasks = memberTasks);
    }
  }

  void _showTaskDetail(dynamic task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        isOwner: widget.isOwner,
        teamMembers: widget.teamMembers,
      ),
    ).then((value) {
      if (value == true) widget.onToggle?.call();
    });
  }

  Future<void> _openPrivateChat(BuildContext context) async {
    try {
      final authService = AuthService();
      final currentUser = await authService.getCachedUser();
      if (!context.mounted || currentUser == null) return;
      final currentUserId = currentUser.id;
      if (currentUserId == null) return;
      final memberId = (widget.member['id'] as num).toInt();
      if (memberId == currentUserId) return;

      final chatService = ChatService();
      final privateChat = await chatService.startPrivateChat(memberId);

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            conversation: privateChat,
            currentUser: currentUser,
            authService: authService,
          ),
        ),
      );

      if (privateChat.id != 0) {
        await NotificationHelper.cancelChatNotification(privateChat.id);
        await chatService.markConversationRead(privateChat.id);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.handleApiError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String memberEmail =
        (widget.member['email'] as String?)?.toLowerCase().trim() ?? '';
    int totalTasks = _localTasks.length;
    int completedTasks = _localTasks.where((t) {
      // Task counts as complete for this member if fully done OR their email is in completedBy
      if (t['is_completed'] == true) return true;
      final dynamic completedByRaw = t['completed_by'];
      final List<String> completedBy = completedByRaw is List
          ? completedByRaw.cast<String>()
          : (completedByRaw is Map
                ? completedByRaw.values.cast<String>().toList()
                : []);
      return completedBy.any((e) => e.toLowerCase().trim() == memberEmail);
    }).length;

    final int progress = totalTasks > 0
        ? ((completedTasks / totalTasks) * 100).round()
        : 0;
    final String role = _readMemberRole(widget.member as Map<dynamic, dynamic>);
    final String? currentUserEmailNormalized = widget.currentUserEmail
        ?.toLowerCase()
        .trim();
    final bool isOwnMemberDetail =
        currentUserEmailNormalized != null &&
        currentUserEmailNormalized == memberEmail;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: AppColors.textPrimary,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Member Details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: isOwnMemberDetail
            ? null
            : [
                IconButton(
                  icon: const Icon(
                    Icons.chat_outlined,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () => _openPrivateChat(context),
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1E6D2),
                ),
                child: ClipOval(
                  child:
                      widget.member['avatar_url'] != null ||
                          (widget.member['avatar'] != null &&
                              widget.member['avatar'].toString().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: ImageUtils.getAvatarUrl(
                            widget.member['avatar_url'] ??
                                widget.member['avatar'],
                          ),
                          fit: BoxFit.cover,
                          httpHeaders: getNetworkImageHeaders(
                            ImageUtils.getAvatarUrl(
                              widget.member['avatar_url'] ??
                                  widget.member['avatar'],
                            ),
                          ),
                          cacheManager: WudiCacheManager(),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(Icons.person, size: 60, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.member['name'] ?? 'No Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                role,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const Text(
                'COMPLETE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_localTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'No active tasks.',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                )
              else
                ..._localTasks.map(
                  (t) => _MemberTaskCard(
                    task: t,
                    onTap: () => _showTaskDetail(t),
                    isOwner: widget.isOwner,
                    memberEmail: memberEmail,
                    currentUserEmail: widget.currentUserEmail,
                    isOffline: widget.isOffline,
                    onToggle: () async {
                      if (widget.isOffline) return;
                      final taskIndex = _localTasks.indexOf(t);
                      if (taskIndex == -1) return;

                      final List<String> assignedEmails =
                          (t['assigned_emails'] as List<dynamic>?)
                              ?.cast<String>() ??
                          [];
                      final String? currentUserEmailNormalized = widget
                          .currentUserEmail
                          ?.toLowerCase()
                          .trim();
                      final bool isOwnMemberDetail =
                          currentUserEmailNormalized != null &&
                          currentUserEmailNormalized == memberEmail;

                      if (!widget.isOwner && !isOwnMemberDetail) {
                        ErrorHandler.showErrorPopup(
                          'You can only check tasks from your own member detail or the team task list',
                        );
                        return;
                      }

                      // Block non-owner from toggling a fully completed task
                      if (t['is_completed'] == true && !widget.isOwner) {
                        ErrorHandler.showErrorPopup(
                          'Task has been completed by the leader and cannot be modified',
                        );
                        return;
                      }

                      setState(() {
                        final task = Map<String, dynamic>.from(
                          _localTasks[taskIndex],
                        );
                        final detailMemberEmail = memberEmail;

                        if (widget.isOwner) {
                          // From member detail, owner toggles only this viewed member.
                          final dynamic completedByRaw = task['completed_by'];
                          final List<String> completedBy =
                              completedByRaw is List
                              ? List<String>.from(completedByRaw)
                              : (completedByRaw is Map
                                    ? List<String>.from(completedByRaw.values)
                                    : []);
                          if (completedBy.any(
                            (e) => e.toLowerCase().trim() == detailMemberEmail,
                          )) {
                            completedBy.removeWhere(
                              (e) =>
                                  e.toLowerCase().trim() == detailMemberEmail,
                            );
                          } else {
                            completedBy.add(detailMemberEmail);
                          }
                          task['completed_by'] = completedBy;
                          final int totalAssigned = assignedEmails.isNotEmpty
                              ? assignedEmails.length
                              : 1;
                          task['is_completed'] =
                              completedBy
                                  .where(
                                    (e) => assignedEmails.any(
                                      (a) =>
                                          a.toLowerCase().trim() ==
                                          e.toLowerCase().trim(),
                                    ),
                                  )
                                  .length >=
                              totalAssigned;
                        } else {
                          // Regular member toggles own entry only
                          final dynamic completedByRaw = task['completed_by'];
                          final List<String> completedBy =
                              completedByRaw is List
                              ? List<String>.from(completedByRaw)
                              : (completedByRaw is Map
                                    ? List<String>.from(completedByRaw.values)
                                    : []);
                          if (currentUserEmailNormalized != null) {
                            if (completedBy.any(
                              (e) =>
                                  e.toLowerCase().trim() ==
                                  currentUserEmailNormalized,
                            )) {
                              completedBy.removeWhere(
                                (e) =>
                                    e.toLowerCase().trim() ==
                                    currentUserEmailNormalized,
                              );
                            } else {
                              completedBy.add(widget.currentUserEmail!);
                            }
                          }
                          task['completed_by'] = completedBy;
                          final int totalAssigned = assignedEmails.isNotEmpty
                              ? assignedEmails.length
                              : 1;
                          task['is_completed'] =
                              completedBy
                                  .where(
                                    (e) => assignedEmails.any(
                                      (a) =>
                                          a.toLowerCase().trim() ==
                                          e.toLowerCase().trim(),
                                    ),
                                  )
                                  .length >=
                              totalAssigned;
                        }

                        _localTasks[taskIndex] = task;
                      });

                      try {
                        final response = await TeamService()
                            .toggleMemberTaskStatus(
                              t['id'],
                              targetEmail: widget.isOwner ? memberEmail : null,
                            );
                        final updatedTask = response['todo'];
                        if (updatedTask is Map && mounted) {
                          setState(() {
                            final index = _localTasks.indexWhere(
                              (localTask) =>
                                  localTask['id'] == updatedTask['id'],
                            );
                            if (index != -1) {
                              _localTasks[index] = Map<String, dynamic>.from(
                                updatedTask,
                              );
                            }
                          });
                        }
                        await _syncMemberTasks();
                        widget.onToggle?.call();
                      } catch (e) {
                        await _syncMemberTasks();
                        widget.onToggle?.call();
                        ErrorHandler.handleApiError(e);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTaskCard extends StatefulWidget {
  final dynamic task;
  final VoidCallback onTap;
  final bool isOwner;
  final String memberEmail;
  final String? currentUserEmail;
  final bool isOffline;
  final VoidCallback? onToggle;

  const _MemberTaskCard({
    required this.task,
    required this.onTap,
    required this.isOwner,
    required this.memberEmail,
    this.currentUserEmail,
    required this.isOffline,
    this.onToggle,
  });

  @override
  State<_MemberTaskCard> createState() => _MemberTaskCardState();
}

class _MemberTaskCardState extends State<_MemberTaskCard> {
  bool _isToggling = false;

  void _handleToggle() {
    if (_isToggling) return;
    _isToggling = true;
    widget.onToggle?.call();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _isToggling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = widget.task['is_completed'] == true;
    final String priority = widget.task['priority']?.toString() ?? 'low';
    final DateTime? dueDate = widget.task['deadline'] != null
        ? DateTime.tryParse(widget.task['deadline'])
        : null;

    final dynamic assignedRaw = widget.task['assigned_emails'];
    final List<String> assignedEmails = assignedRaw is List
        ? assignedRaw.cast<String>()
        : (assignedRaw is Map
              ? assignedRaw.values.cast<String>().toList()
              : []);

    final dynamic completedByRaw = widget.task['completed_by'];
    final List<String> completedBy = completedByRaw is List
        ? completedByRaw.cast<String>()
        : (completedByRaw is Map
              ? completedByRaw.values.cast<String>().toList()
              : []);

    final int totalAssigned = assignedEmails.isNotEmpty
        ? assignedEmails.length
        : 1;
    final int totalCompleted = isCompleted
        ? totalAssigned
        : completedBy
              .where(
                (e) => assignedEmails.any(
                  (a) => a.toLowerCase().trim() == e.toLowerCase().trim(),
                ),
              )
              .length;
    final double progress = totalAssigned > 0
        ? totalCompleted / totalAssigned
        : 0;

    final bool detailMemberChecked =
        isCompleted ||
        completedBy.any((e) => e.toLowerCase().trim() == widget.memberEmail);

    final String? emailNorm = widget.currentUserEmail?.toLowerCase().trim();
    final bool isOwnMemberDetail =
        emailNorm != null && emailNorm == widget.memberEmail;
    final bool canToggle =
        widget.isOwner ||
        (isOwnMemberDetail &&
            assignedEmails.any((e) => e.toLowerCase().trim() == emailNorm));
    final bool checkboxLocked = isCompleted && !widget.isOwner;

    // Format time display
    String timeDisplay = '';
    if (dueDate != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final dateStr = '${dueDate.day} ${months[dueDate.month - 1]}';
      final timeStr =
          AppTimeUtils.formatTo24h(widget.task['due_time']) != '--:--'
          ? AppTimeUtils.formatTo24h(widget.task['due_time'])
          : AppTimeUtils.extractTimeFromDeadline(
              widget.task['deadline']?.toString(),
            );
      timeDisplay = '$dateStr | $timeStr';
    }

    return AbsorbPointer(
      absorbing: widget.isOffline,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E6D2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox on the left
                  GestureDetector(
                    onTap: () {
                      if (widget.isOffline) return;
                      if (checkboxLocked) {
                        ErrorHandler.showErrorPopup(
                          'Task has been completed and cannot be modified',
                        );
                        return;
                      }
                      if (canToggle) {
                        _handleToggle();
                      } else {
                        ErrorHandler.showErrorPopup(
                          'Only the owner or assigned member can toggle this task',
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 3, right: 12),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: detailMemberChecked
                              ? Colors.black87
                              : Colors.black38,
                          width: 1.8,
                        ),
                      ),
                      child: detailMemberChecked
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.black87,
                            )
                          : null,
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.task['judul'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Priority badge
                        _buildPriorityBadge(priority),
                        const SizedBox(height: 6),
                        // Time
                        if (timeDisplay.isNotEmpty) ...[
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Time : ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(text: timeDisplay),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Progress bar + Checked counter
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.black12,
                                  color: Colors.black87,
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$totalCompleted/$totalAssigned Checked',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isOffline)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 14),
                            SizedBox(width: 8),
                            Text(
                              "Offline",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;
    switch (priority.toLowerCase()) {
      case 'high':
        bgColor = const Color(0xFFFFE5E5);
        textColor = const Color(0xFFCC0000);
        icon = Icons.error;
        label = 'High Priority';
        break;
      case 'medium':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        icon = Icons.priority_high;
        label = 'Medium';
        break;
      default:
        bgColor = const Color(0xFFE5F5E5);
        textColor = const Color(0xFF155724);
        icon = Icons.low_priority;
        label = 'Low';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailSheet extends StatelessWidget {
  final dynamic task;
  final bool isOwner;
  final List<dynamic> teamMembers;

  const _TaskDetailSheet({
    required this.task,
    required this.isOwner,
    required this.teamMembers,
  });

  @override
  Widget build(BuildContext context) {
    final String time = AppTimeUtils.formatTo24h(task['due_time']) != '--:--'
        ? AppTimeUtils.formatTo24h(task['due_time'])
        : AppTimeUtils.extractTimeFromDeadline(task['deadline']?.toString());
    final String priority = task['priority']?.toString() ?? 'low';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            task['judul'] ?? '',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPriorityBgColor(priority),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPriorityIcon(priority),
                  size: 16,
                  color: _getPriorityColor(priority),
                ),
                const SizedBox(width: 8),
                Text(
                  _getPriorityLabel(priority),
                  style: TextStyle(
                    color: _getPriorityColor(priority),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.access_time, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TIME',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              task['deskripsi'] ?? 'No description provided.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Delete Task'),
                          content: const Text(
                            'Are you sure you want to delete this task?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          final TeamService teamService = TeamService();
                          await teamService.deleteTask(task['id']);
                          if (context.mounted) {
                            ErrorHandler.showSuccessPopup(
                              'Task deleted successfully',
                            );
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          ErrorHandler.handleApiError(e);
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1E6D2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditTeamTaskPage(
                            teamId: task['team_id'],
                            task: task,
                            members: teamMembers,
                          ),
                        ),
                      );

                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    label: const Text(
                      'Edit',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2633),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

Color _getPriorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'high':
      return const Color(0xFFFF0000); // Pure Red
    case 'medium':
      return const Color(0xFFA49C00); // Deep Olive
    case 'low':
      return const Color(0xFF16A34A); // Forest Green
    default:
      return const Color(0xFF8E8E93);
  }
}

Color _getPriorityBgColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'medium':
      return const Color(
        0xFFD4EA0C,
      ).withValues(alpha: 0.15); // Light Yellow/Lime Tint
    default:
      return _getPriorityColor(priority).withValues(alpha: 0.15);
  }
}

String _getPriorityLabel(String priority) {
  switch (priority.toLowerCase()) {
    case 'high':
      return 'High Priority';
    case 'medium':
      return 'Medium Priority';
    case 'low':
      return 'Low Priority';
    default:
      return priority.substring(0, 1).toUpperCase() + priority.substring(1);
  }
}

IconData _getPriorityIcon(String priority) {
  switch (priority.toLowerCase()) {
    case 'high':
      return Icons.error;
    case 'medium':
      return Icons.priority_high;
    case 'low':
      return Icons.low_priority;
    default:
      return Icons.info_outline;
  }
}
