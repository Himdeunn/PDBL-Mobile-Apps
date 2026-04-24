import '../../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../task/models/task_local.dart';
import '../../task/pages/task_page.dart';
import '../../task/pages/create_task_page.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/time_utils.dart';
import 'dart:ui';

class DailyTaskList extends StatefulWidget {
  final List<TaskLocal> tasks;
  final VoidCallback onRefresh;
  final AuthService? authService;
  final bool isLoading;
  final DateTime? filterDate;
  final bool isOffline;
  final bool showHeader;

  const DailyTaskList({
    super.key,
    required this.tasks,
    required this.onRefresh,
    this.authService,
    this.isLoading = false,
    this.filterDate,
    this.isOffline = false,
    this.showHeader = true,
  });

  @override
  State<DailyTaskList> createState() => _DailyTaskListState();
}

class _DailyTaskListState extends State<DailyTaskList> {
  final TaskRepository _taskRepository = TaskRepository();

  String get _currentUserEmail =>
      widget.authService?.currentCachedUser?.email ?? '';

  Future<void> _toggleTask(TaskLocal task) async {
    final email = _currentUserEmail.isEmpty ? 'guest' : _currentUserEmail;
    _taskRepository.toggleTaskStatus(task, email);
  }

  Future<void> _deleteTask(TaskLocal task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await _taskRepository.deleteTask(task);
    ErrorHandler.showSuccessPopup('Task deleted successfully');
    widget.onRefresh();
  }

  Future<void> _navigateToEdit(TaskLocal task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateTaskPage(authService: widget.authService, task: task),
      ),
    );
    if (result == true) widget.onRefresh();
  }

  void _showTaskDetail(TaskLocal task) {
    final isTeam = task.teamId != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HomeTaskDetailSheet(
        task: task,
        currentUserEmail: _currentUserEmail,
        onDelete: isTeam
            ? null
            : () async {
                Navigator.pop(ctx);
                await _deleteTask(task);
              },
        onEdit: isTeam
            ? null
            : () {
                Navigator.pop(ctx);
                _navigateToEdit(task);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today Task',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskPage(
                      authService: widget.authService,
                      filterDate: widget.filterDate ?? DateTime.now(),
                    ),
                  ),
                ),
                child: const Text(
                  'SEE ALL',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (widget.isLoading && widget.tasks.isEmpty)
          Column(children: List.generate(3, (_) => const _SkeletonTaskItem()))
        else if (widget.tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No tasks for today.',
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.isLoading
                ? widget.tasks.length + 1
                : widget.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (widget.isLoading && index == widget.tasks.length) {
                return const _SkeletonTaskItem();
              }
              final task = widget.tasks[index];
              return _TaskItem(
                task: task,
                currentUserEmail: _currentUserEmail,
                onToggle: () => _toggleTask(task),
                onShowDetail: () => _showTaskDetail(task),
                isOffline: widget.isOffline,
              );
            },
          ),
      ],
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonTaskItem extends StatefulWidget {
  const _SkeletonTaskItem();

  @override
  State<_SkeletonTaskItem> createState() => _SkeletonTaskItemState();
}

class _SkeletonTaskItemState extends State<_SkeletonTaskItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
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
    );
  }
}

// ─── Task Item ────────────────────────────────────────────────────────────────

class _TaskItem extends StatefulWidget {
  final TaskLocal task;
  final String currentUserEmail;
  final VoidCallback onToggle;
  final VoidCallback onShowDetail;
  final bool isOffline;

  const _TaskItem({
    required this.task,
    required this.currentUserEmail,
    required this.onToggle,
    required this.onShowDetail,
    this.isOffline = false,
  });

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  late bool _localCompleted;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _localCompleted = widget.task.isCompleted;
  }

  @override
  void didUpdateWidget(_TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isToggling) _localCompleted = widget.task.isCompleted;
  }

  void _handleToggle() {
    if (_isToggling) return;
    _isToggling = true;
    setState(() => _localCompleted = !_localCompleted);
    widget.onToggle();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _isToggling = false;
    });
  }

  Color _getPriorityColor() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':   return const Color(0xFFE24B4A);
      case 'medium': return const Color(0xFFBA7517);
      case 'low':    return const Color(0xFF3B6D11);
      default:       return const Color(0xFF8E8E93);
    }
  }

  Color _getPriorityBgColor() {
    switch (widget.task.priority.toLowerCase()) {
      case 'low':    return const Color(0xFF3B6D11).withValues(alpha: 0.15);
      case 'medium': return const Color(0xFFBA7517).withValues(alpha: 0.25);
      case 'high':   return const Color(0xFFE24B4A).withValues(alpha: 0.25);
      default:       return _getPriorityColor().withValues(alpha: 0.15);
    }
  }

  String _getPriorityLabel() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':   return 'High Priority';
      case 'medium': return 'Medium';
      case 'low':    return 'Low';
      default:       return widget.task.priority;
    }
  }

  Widget _buildPriorityIcon() {
    switch (widget.task.priority.toLowerCase()) {
      case 'high':
        return Image.asset('assets/images/icon high priority.png',
            width: 10, height: 10);
      case 'low':
        return Image.asset('assets/images/lowprio.png',
            width: 10, height: 10);
      default:
        return Icon(Icons.priority_high_rounded,
            size: 10, color: _getPriorityColor());
    }
  }

  // Username chips: show "You" + other usernames (truncated), with +N overflow
  Widget _buildUsernameChips() {
    final rawEmails = widget.task.assignedEmails ?? '';
    final rawUsernames = widget.task.assignedUsernames ?? '';
    final emails = rawEmails
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (emails.isEmpty) return const SizedBox.shrink();

    // Build parallel username list, fall back to email-prefix if missing
    final usernames = rawUsernames.isNotEmpty
        ? rawUsernames
            .split(',')
            .map((u) => u.trim())
            .where((u) => u.isNotEmpty)
            .toList()
        : emails
            .map((e) => e.contains('@') ? e.split('@').first : e)
            .toList();

    final me = widget.currentUserEmail.toLowerCase().trim();
    final bool hasMe = emails.any((e) => e.toLowerCase().trim() == me);

    // Pairs of (email, displayName) for non-me members
    final otherPairs = <MapEntry<String, String>>[];
    for (int i = 0; i < emails.length; i++) {
      if (emails[i].toLowerCase().trim() != me) {
        final name = i < usernames.length ? usernames[i] : emails[i];
        otherPairs.add(MapEntry(emails[i], name));
      }
    }

    const int maxOthersInline = 1;
    final inlineOthers = otherPairs.take(maxOthersInline).toList();
    final int extra = otherPairs.length - inlineOthers.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (hasMe) _MemberChip(label: 'You', isMe: true),
        for (final pair in inlineOthers)
          _MemberChip(label: pair.value, isMe: false),
        if (extra > 0)
          GestureDetector(
            onTap: () => _showAllMembers(emails, usernames, me),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2631).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+$extra',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAllMembers(List<String> emails, List<String> usernames, String meEmail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Assigned Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(emails.length, (i) {
            final email = emails[i];
            final name = i < usernames.length ? usernames[i] : email;
            final isMe = email.toLowerCase().trim() == meEmail;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMe ? '$name (You)' : name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeam = widget.task.teamId != null;
    // Compute leaderChecked from persisted fields (leaderChecked field is @ignore)
    final bool leaderChecked = isTeam &&
        widget.task.isCompleted &&
        widget.currentUserEmail.isNotEmpty &&
        !(widget.task.completedBy ?? '')
            .split(',')
            .any((e) => e.trim() == widget.currentUserEmail.toLowerCase().trim());
    return AbsorbPointer(
      absorbing: isTeam && widget.isOffline,
      child: GestureDetector(
        onTap: widget.onShowDetail,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _localCompleted
                    ? AppColors.surface.withValues(alpha: 0.5)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox — disabled for ALL team tasks once is_completed=true
                  GestureDetector(
                    onTap: (isTeam && widget.task.isCompleted)
                        ? () {
                            if (leaderChecked) {
                              ErrorHandler.showErrorPopup(
                                'This task has been completed by the leader.',
                                title: 'Completed by Leader',
                              );
                            } else {
                              ErrorHandler.showErrorPopup(
                                'This task is already fully completed.',
                                title: 'Task Completed',
                              );
                            }
                          }
                        : _handleToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Opacity(
                      opacity: (isTeam && widget.task.isCompleted) ? 0.55 : 1.0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: leaderChecked
                                ? const Color(0xFF6A5ACD)
                                : AppColors.calendarSelected,
                            width: 2,
                          ),
                          color: _localCompleted
                              ? (leaderChecked
                                  ? const Color(0xFF6A5ACD)
                                  : AppColors.calendarSelected)
                              : Colors.transparent,
                        ),
                        child: _localCompleted
                            ? Icon(
                                (isTeam && widget.task.isCompleted && !leaderChecked)
                                    ? Icons.lock_rounded
                                    : Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: _localCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: _localCompleted
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.task.dueTime != null
                              ? 'Time : ${AppTimeUtils.formatTo24h(widget.task.dueTime!)}'
                              : 'No time set',
                          style: TextStyle(
                            fontSize: 12,
                            color: _localCompleted
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                        ),
                        // Leader-checked tag + username chips for team tasks
                        if (isTeam) ...[
                          if (leaderChecked) ...[
                            const SizedBox(height: 5),
                            _LeaderCheckedTag(),
                          ],
                          const SizedBox(height: 6),
                          _buildUsernameChips(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Priority badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityBgColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPriorityIcon(),
                        const SizedBox(width: 4),
                        Text(
                          _getPriorityLabel(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isTeam && widget.isOffline)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 8),
                              Text(
                                "Connection Required",
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
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Member Chip (username, truncated) ────────────────────────────────────────

class _MemberChip extends StatelessWidget {
  final String label;
  final bool isMe;
  const _MemberChip({required this.label, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Truncate long names to 12 chars with ellipsis
    final display = label.length > 12 ? '${label.substring(0, 11)}…' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF2D2631).withValues(alpha: 0.12)
            : const Color(0xFF2D2631).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: 11,
            color: isMe ? AppColors.textPrimary : Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            display,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMe ? AppColors.textPrimary : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leader Checked Tag ────────────────────────────────────────────────────────

class _LeaderCheckedTag extends StatelessWidget {
  const _LeaderCheckedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF6A5ACD).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6A5ACD).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: Color(0xFF6A5ACD)),
          SizedBox(width: 4),
          Text(
            'Checked By Leader',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6A5ACD),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home Task Detail Sheet ───────────────────────────────────────────────────

class _HomeTaskDetailSheet extends StatelessWidget {
  final TaskLocal task;
  final String currentUserEmail;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _HomeTaskDetailSheet({
    required this.task,
    required this.currentUserEmail,
    this.onDelete,
    this.onEdit,
  });

  Color _priorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':   return Colors.red;
      case 'medium': return Colors.orange;
      case 'low':    return Colors.green;
      default:       return Colors.grey;
    }
  }

  Color _priorityBg() {
    switch (task.priority.toLowerCase()) {
      case 'high':   return Colors.red[50]!;
      case 'medium': return Colors.orange[50]!;
      case 'low':    return Colors.green[50]!;
      default:       return Colors.grey[50]!;
    }
  }

  String _priorityLabel() {
    switch (task.priority.toLowerCase()) {
      case 'high':   return 'High Priority';
      case 'medium': return 'Medium';
      case 'low':    return 'Low';
      default:       return task.priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = task.dueTime != null
        ? AppTimeUtils.formatTo24h(task.dueTime!)
        : 'No time set';

    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFFF3EDE6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Priority badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _priorityBg(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded,
                    size: 14, color: _priorityColor()),
                const SizedBox(width: 6),
                Text(
                  _priorityLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _priorityColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // TIME row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Assigned members (team tasks) — show username (email-prefix fallback)
          if (task.teamId != null && (task.assignedEmails ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Assigned To',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final emails = task.assignedEmails!
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final rawUsernames = task.assignedUsernames ?? '';
              final usernames = rawUsernames.isNotEmpty
                  ? rawUsernames.split(',').map((u) => u.trim()).toList()
                  : emails
                      .map((e) => e.contains('@') ? e.split('@').first : e)
                      .toList();
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(emails.length, (i) {
                  final email = emails[i];
                  final name = i < usernames.length ? usernames[i] : email;
                  final isMe = email.toLowerCase().trim() ==
                      currentUserEmail.toLowerCase().trim();
                  return _MemberChip(label: isMe ? 'You' : name, isMe: isMe);
                }),
              );
            }),
          ],

          // Description
          if (task.description != null &&
              task.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8DDD0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                task.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Delete + Edit buttons — individual tasks only
          if (onDelete != null && onEdit != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2631),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
