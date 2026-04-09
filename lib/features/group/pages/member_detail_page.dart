import 'package:flutter/material.dart';
import 'edit_team_task_page.dart';
import '../services/team_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_utils.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/time_utils.dart';

class MemberDetailPage extends StatefulWidget {
  final int teamId;
  final dynamic member;
  final List<dynamic> memberTasks;
  final List<dynamic> teamMembers;
  final String? currentUserEmail;
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
    this.onToggle,
    this.isOwner = false,
    this.isOffline = false,
  });

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late List<dynamic> _localTasks;

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

  @override
  Widget build(BuildContext context) {
    final String memberEmail =
        (widget.member['email'] as String?)?.toLowerCase().trim() ?? '';
    int totalTasks = _localTasks.length;
    int completedTasks = _localTasks.where((t) {
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
    final String role = widget.member['role'] ?? 'Member';

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
        title: const Text(
          'Member Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFF1E6D2),
                backgroundImage:
                    widget.member['avatar'] != null &&
                        widget.member['avatar'].toString().isNotEmpty
                    ? NetworkImage(
                        ImageUtils.getAvatarUrl(widget.member['avatar']),
                      )
                    : null,
                child:
                    widget.member['avatar'] == null ||
                        widget.member['avatar'].toString().isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
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
                    currentUserEmail: widget.currentUserEmail,
                    isOffline: widget.isOffline,
                    onToggle: () async {
                      if (widget.isOffline) return;
                      final taskIndex = _localTasks.indexOf(t);
                      if (taskIndex == -1) return;

                      setState(() {
                        final task = Map<String, dynamic>.from(
                          _localTasks[taskIndex],
                        );
                        final dynamic completedByRaw = task['completed_by'];
                        final List<String> completedBy = completedByRaw is List
                            ? List<String>.from(completedByRaw)
                            : (completedByRaw is Map
                                ? List<String>.from(completedByRaw.values)
                                : []);

                        final String? currentUserEmailNormalized =
                            widget.currentUserEmail?.toLowerCase().trim();

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

                        final List<String> assignedEmails =
                            (task['assigned_emails'] as List<dynamic>?)
                                ?.cast<String>() ??
                            [];
                        final int totalAssigned = assignedEmails.isNotEmpty
                            ? assignedEmails.length
                            : 1;
                        task['is_completed'] =
                            completedBy.length >= totalAssigned;

                        _localTasks[taskIndex] = task;
                      });

                      try {
                        await TeamService().toggleMemberTaskStatus(t['id']);
                        widget.onToggle?.call();
                      } catch (e) {
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

class _MemberTaskCard extends StatelessWidget {
  final dynamic task;
  final VoidCallback onTap;
  final bool isOwner;
  final String? currentUserEmail;
  final bool isOffline;
  final VoidCallback? onToggle;

  const _MemberTaskCard({
    required this.task,
    required this.onTap,
    required this.isOwner,
    this.currentUserEmail,
    required this.isOffline,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = task['is_completed'] == true;
    final String priority = task['prioritas']?.toString() ?? 'low';
    final DateTime? dueDate = task['deadline'] != null
        ? DateTime.tryParse(task['deadline'])
        : null;
    
    final dynamic assignedRaw = task['assigned_emails'];
    final List<String> assignedEmails = assignedRaw is List
        ? assignedRaw.cast<String>()
        : (assignedRaw is Map ? assignedRaw.values.cast<String>().toList() : []);

    final dynamic completedByRaw = task['completed_by'];
    final List<String> completedBy = completedByRaw is List
        ? completedByRaw.cast<String>()
        : (completedByRaw is Map ? completedByRaw.values.cast<String>().toList() : []);

    final int totalAssigned = assignedEmails.isNotEmpty ? assignedEmails.length : 1;
    final int totalCompleted = completedBy.length;
    final double progress = totalAssigned > 0 ? totalCompleted / totalAssigned : 0;
    final int progressPercent = (progress * 100).round();
    
    final bool currentUserChecked = currentUserEmail != null &&
        completedBy.any((e) => e.toLowerCase().trim() == currentUserEmail!.toLowerCase().trim());

    return AbsorbPointer(
      absorbing: isOffline,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E3DD),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['judul'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPriorityBgColor(priority),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPriorityIcon(priority),
                                    size: 10,
                                    color: _getPriorityColor(priority),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPriorityLabel(priority),
                                    style: TextStyle(
                                      color: _getPriorityColor(priority),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETED' : 'IN PROGRESS',
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.purple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (dueDate != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(dueDate),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        if (task['due_time'] != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            AppTimeUtils.formatTo24h(task['due_time']) != '--:--'
                                ? AppTimeUtils.formatTo24h(task['due_time'])
                                : AppTimeUtils.extractTimeFromDeadline(task['deadline']?.toString()),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ]
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              color: isCompleted ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                color: isCompleted ? Colors.green : Colors.blue,
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalCompleted/$totalAssigned checked',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          if (isOffline) return;
                          final emailNormalized = currentUserEmail?.toLowerCase().trim();
                          final bool isAssigned = emailNormalized != null &&
                              assignedEmails.any((e) => e.toLowerCase().trim() == emailNormalized);
                          if (isOwner || isAssigned) {
                            onToggle?.call();
                          } else {
                            ErrorHandler.showErrorPopup('Only the owner or assigned member can toggle this task');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: currentUserChecked ? AppColors.primary : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: currentUserChecked ? AppColors.primary : Colors.grey,
                                width: 2),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: currentUserChecked ? Colors.white : Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isOffline)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
    final String priority = task['prioritas']?.toString() ?? 'low';

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
      return const Color(0xFFD4EA0C).withValues(alpha: 0.15); // Light Yellow/Lime Tint
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
