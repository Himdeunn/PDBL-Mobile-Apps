import 'package:flutter/material.dart';
import '../services/team_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import 'package:intl/intl.dart';

class MemberDetailPage extends StatefulWidget {
  final int teamId;
  final dynamic member;
  final List<dynamic> memberTasks;
  final String? currentUserEmail;
  final VoidCallback? onToggle;
  final bool isOwner;

  const MemberDetailPage({
    super.key,
    required this.teamId,
    required this.member,
    required this.memberTasks, // Keep memberTasks as it is used in the build method
    this.currentUserEmail,
    this.onToggle,
    this.isOwner = false, // Changed to optional with default value
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
      builder: (context) =>
          _TaskDetailSheet(task: task, isOwner: widget.isOwner),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic progress calculation
    int totalTasks = _localTasks.length;
    int completedTasks =
        _localTasks.where((t) => t['is_completed'] == true).length;
    final int progress =
        totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
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
          'Detail Member',
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
              // Profile Section
              const CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFFF1E6D2),
                child: Icon(Icons.person, size: 60, color: Colors.grey),
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

              // Progress Section
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

              // Active Tasks Header
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

              // Member Tasks List
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
                    onToggle: () async {
                      try {
                        final int index = _localTasks.indexWhere((task) => task['id'] == t['id']);
                        if (index != -1) {
                          final bool oldStatus = _localTasks[index]['is_completed'] == true;
                          final bool newStatus = !oldStatus;

                          // Optimistic UI update
                          setState(() {
                            _localTasks[index]['is_completed'] = newStatus;
                          });

                          await TeamService().toggleTaskStatus(t['id'], newStatus);
                          
                          // Notify parent to refresh in background
                          widget.onToggle?.call();
                        }
                      } catch (e) {
                        // Notify parent to refresh and revert on error
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
  final VoidCallback? onToggle;

  const _MemberTaskCard({
    required this.task,
    required this.onTap,
    required this.isOwner,
    this.currentUserEmail,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Assuming task is an object with properties like apiId, isCompleted, userEmail
    // If task is a Map, you would need to adjust access like task['is_completed']
    final bool isCompleted = task['is_completed'] == true;
    final DateTime? dueDate = task['deadline'] != null
        ? DateTime.tryParse(task['deadline'])
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E3DD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task['judul'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : Colors.purple.withOpacity(0.1),
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
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(dueDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isCompleted ? '100%' : '0%',
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
                              value: isCompleted ? 1.0 : 0.0,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              color: isCompleted ? Colors.green : Colors.grey,
                              minHeight: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final String? taskUserEmail = task['user']?['email'] as String?;
                        final String? currentUserEmailNormalized = currentUserEmail?.toLowerCase().trim();
                        final String? taskUserEmailNormalized = taskUserEmail?.toLowerCase().trim();

                        if (isOwner ||
                            (currentUserEmailNormalized != null && taskUserEmailNormalized != null &&
                                currentUserEmailNormalized == taskUserEmailNormalized)) {
                          onToggle?.call();
                        } else {
                          ErrorHandler.showErrorPopup(
                              'Only the owner or assigned member can toggle this task');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? AppColors.primary : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: isCompleted ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

  const _TaskDetailSheet({required this.task, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final String time = task['due_time'] ?? '--:--';

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
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            task['judul'] ?? '',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
            const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
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
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              task['deskripsi'] ?? 'No description provided.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          if (isOwner)
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: const Text('Are you sure you want to delete this task?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          final TeamService teamService = TeamService();
                          await teamService.deleteTask(task['id']);
                          if (context.mounted) {
                            Navigator.pop(context, true); // Close sheet and indicate refresh
                            ErrorHandler.showSuccessPopup('Task deleted successfully');
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
                    onPressed: () {
                      final titleController = TextEditingController(text: task['judul']);
                      final descController = TextEditingController(text: task['deskripsi']);

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Edit Task'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(labelText: 'Title'),
                              ),
                              TextField(
                                controller: descController,
                                decoration: const InputDecoration(labelText: 'Description'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () async {
                                try {
                                  final TeamService teamService = TeamService();
                                  await teamService.updateTask(
                                    task['id'],
                                    titleController.text,
                                    descController.text,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                    ErrorHandler.showSuccessPopup('Task updated successfully');
                                  }
                                } catch (e) {
                                  ErrorHandler.handleApiError(e);
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
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
