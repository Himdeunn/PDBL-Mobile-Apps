import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../services/team_service.dart';
import '../../auth/services/auth_service.dart';
import 'create_team_task_page.dart';
import 'member_detail_page.dart';

class TeamDetailPage extends StatefulWidget {
  final int teamId;
  final AuthService? authService;

  const TeamDetailPage({super.key, required this.teamId, this.authService});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TeamService _teamService = TeamService();
  bool _isLoading = true;
  Map<String, dynamic>? _teamData;
  List<dynamic> _members = [];
  List<dynamic> _tasks = [];
  int? _currentUserId;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final user = await widget.authService?.getCurrentUser();
      _currentUserId = user?.id;
      _currentUserEmail = user?.email;

      final data = await _teamService.getTeamDetails(widget.teamId);
      setState(() {
        _teamData = data['team'];
        _members = data['team']['members'] ?? [];
        _tasks = data['tasks'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading team: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _showMemberOptions(dynamic member) {
    final bool isOwner = _teamData?['created_by']?.toString() == _currentUserId?.toString();
    if (!isOwner || member['id']?.toString() == _currentUserId?.toString()) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text(
                'Kick Member',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleRemoveMember(member['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text(
                'Ban Member',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleBanMember(member['id']);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTeamDialog() async {
    final nameController = TextEditingController(text: _teamData?['name']);
    final descController = TextEditingController(
      text: _teamData?['description'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _teamService.updateTeam(
                  widget.teamId,
                  nameController.text,
                  descController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ErrorHandler.showSuccessPopup('Team updated successfully');
                  _loadData();
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
  }

  Future<void> _showAddMemberDialog() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'User Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _teamService.inviteToTeam(
                  widget.teamId,
                  emailController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ErrorHandler.showSuccessPopup('Invitation sent');
                  _loadData();
                }
              } catch (e) {
                ErrorHandler.handleApiError(e);
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRemoveMember(int userId) async {
    try {
      await _teamService.removeMember(widget.teamId, userId);
      _loadData();
      ErrorHandler.showSuccessPopup('Member removed successfully');
    } catch (e) {
      ErrorHandler.handleApiError(e);
    }
  }

  Future<void> _handleBanMember(int userId) async {
    try {
      await _teamService.banMember(widget.teamId, userId);
      _loadData();
      ErrorHandler.showSuccessPopup('Member banned successfully');
    } catch (e) {
      ErrorHandler.handleApiError(e);
    }
  }

  void _showTaskDetail(dynamic task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        isOwner: true, // All team members can now manage tasks
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String teamName = _teamData?['name'] ?? 'Team Detail';
    final String description = _teamData?['description'] ?? '';

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
          'Project Team',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Color(0xFFA855F7),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_teamData?['created_by']?.toString() == _currentUserId?.toString())
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showEditTeamDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Members Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Anggota Team',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_teamData?['created_by']?.toString() == _currentUserId?.toString())
                    _SmallButton(
                      label: 'Add New Member',
                      onTap: () => _showAddMemberDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ..._members.map(
                (m) => _MemberTile(
                  name: m['name'] ?? 'Member',
                  role: m['role'] ?? 'Member',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberDetailPage(
                          teamId: widget.teamId,
                          member: m,
                          memberTasks: _tasks
                              .where((t) => (t['user']?['email'] ?? '') == m['email'])
                              .toList(),
                          currentUserEmail: _currentUserEmail,
                          onToggle: _loadData,
                          isOwner: _teamData?['created_by']?.toString() == _currentUserId?.toString(),
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  onMore: () => _showMemberOptions(m),
                ),
              ),

              const SizedBox(height: 32),

              // Tasks Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Team',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  _SmallButton(
                    label: 'Add Task',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateTeamTaskPage(
                            teamId: widget.teamId,
                            members: _members,
                            userEmail: _teamData?['owner']?['email'] ?? '',
                          ),
                        ),
                      ).then((result) {
                        if (result == true) _loadData();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_tasks.isEmpty)
                const Center(
                  child: Text(
                    'No tasks created yet.',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                )
              else
                ..._tasks.map(
                  (t) => _TaskTile(
                    title: t['judul'] ?? '',
                    email: t['user']?['email'] ?? 'Unassigned',
                    isDone: t['is_completed'] == true,
                    onTap: () => _showTaskDetail(t),
                    onToggle: () async {
                      final bool isOwner = _teamData?['created_by']?.toString() == _currentUserId?.toString();
                      final String? assignedEmail = t['user']?['email'];
                      
                      final String? assignedEmailNormalized = assignedEmail?.toLowerCase().trim();
                      final String? currentUserEmailNormalized = _currentUserEmail?.toLowerCase().trim();

                      if (isOwner || (currentUserEmailNormalized != null && assignedEmailNormalized != null &&
                          currentUserEmailNormalized == assignedEmailNormalized)) {
                        try {
                          final int taskIndex = _tasks.indexWhere((task) => task['id'] == t['id']);
                          if (taskIndex == -1) return;

                          final oldStatus = _tasks[taskIndex]['is_completed'] == true;
                          final newStatus = !oldStatus;

                          // Optimistic UI: Update local state immediately
                          setState(() {
                            _tasks[taskIndex]['is_completed'] = newStatus;
                          });

                          await _teamService.toggleTaskStatus(t['id'], newStatus);
                          
                          // After success, sync with server without showing a loading spinner
                          _loadData(showLoading: false);
                        } catch (e) {
                          // Revert optimistic update on error
                          _loadData(showLoading: false);
                          ErrorHandler.handleApiError(e);
                        }
                      } else {
                        ErrorHandler.showErrorPopup(
                          'Only the owner or assigned member can toggle this task',
                        );
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

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _MemberTile({
    required this.name,
    required this.role,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E6D2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    role,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String title;
  final String email;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskTile({
    required this.title,
    required this.email,
    required this.isDone,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isDone,
              onChanged: (val) => onToggle(),
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
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

  const _TaskDetailSheet({required this.task, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final DateTime? deadline = task['deadline'] != null ? DateTime.tryParse(task['deadline']) : null;
    final String time = deadline != null ? DateFormat('HH:mm').format(deadline) : '--:--';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
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
          // Allow all members to manage group tasks
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
      ),
    );
  }
}
