import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_utils.dart';

import '../services/team_service.dart';
import '../../auth/services/auth_service.dart';
import 'create_team_task_page.dart';
import 'edit_team_task_page.dart';
import 'member_detail_page.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/services/connection_service.dart';

class TeamDetailPage extends StatefulWidget {
  final int teamId;
  final AuthService? authService;
  final String? taskId; // Added for deep linking

  const TeamDetailPage({
    super.key,
    required this.teamId,
    this.authService,
    this.taskId,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TeamService _teamService = TeamService();
  final TaskRepository _taskRepository = TaskRepository();
  bool _isLoading = true;
  Map<String, dynamic>? _teamData;
  List<dynamic> _members = [];
  List<dynamic> _tasks = [];
  final ConnectionService _connectionService = ConnectionService();
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isOffline = false;
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      if (widget.taskId != null) {
        final task = _tasks
            .where((t) => t['id']?.toString() == widget.taskId)
            .firstOrNull;
        if (task != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTaskDetail(task);
          });
        }
      }
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    
    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
        ErrorHandler.showErrorPopup(
          "Sorry, you don't have internet. Please connect to internet to create or see the team.",
          title: "No Internet Connection",
        );
      }
      return;
    }

    try {
      final user = await widget.authService?.getCurrentUser();
      _currentUserId = user?.id;
      _currentUserEmail = user?.email;

      final rawData = await _teamService.getTeamDetails(widget.teamId);
      if (mounted) {
        setState(() {
          _isOffline = false;
          // Robust parsing for the top-level object
          if (rawData is Map) {
            _teamData = rawData['team'] is Map ? rawData['team'] : null;
            
            // Robust parsing for members
            final membersPart = _teamData?['members'];
            if (membersPart is List) {
              _members = membersPart;
            } else if (membersPart is Map) {
              _members = membersPart.values.toList();
            } else {
              _members = [];
            }
            
            // Robust parsing for tasks
            final tasksPart = rawData['tasks'];
            if (tasksPart is List) {
              _tasks = tasksPart;
            } else if (tasksPart is Map) {
              _tasks = tasksPart.values.toList();
            } else {
              _tasks = [];
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleApiError(e);
      }
      setState(() => _isLoading = false);
    }
  }

  void _showMemberOptions(dynamic member) {
    final String? teamOwnerId = _teamData?['created_by']?.toString();
    final String? currentUserIdStr = _currentUserId?.toString();
    final bool isOwner = teamOwnerId != null && 
                         currentUserIdStr != null && 
                         teamOwnerId == currentUserIdStr;

    if (!isOwner || member['id']?.toString() == currentUserIdStr) {
      return;
    }

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
        backgroundColor: AppColors.surface,
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
              final isOnline = await _connectionService.isConnected();
              if (!isOnline) {
                ErrorHandler.showErrorPopup(
                  "Sorry, you don't have internet. Please connect to internet to create or see the team.",
                  title: "No Internet Connection"
                );
                return;
              }
              try {
                await _teamService.updateTeam(
                  widget.teamId,
                  nameController.text,
                  descController.text,
                );
                if (context.mounted) {
                  ErrorHandler.showSuccessPopup('Team updated successfully');
                  Navigator.pop(context);
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
      barrierDismissible: !_isInviting,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Invite Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the email address of the person you want to invite to this project.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                enabled: !_isInviting,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isInviting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isInviting
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        ErrorHandler.showErrorPopup('Please enter an email address');
                        return;
                      }

                      final isOnline = await _connectionService.isConnected();
                      if (!isOnline) {
                        ErrorHandler.showErrorPopup(
                          "No internet connection. Please check your connection.",
                          title: "Offline",
                        );
                        return;
                      }

                      setDialogState(() => _isInviting = true);
                      try {
                        await _teamService.inviteToTeam(widget.teamId, email);
                        if (context.mounted) {
                          ErrorHandler.showSuccessPopup('Invitation successfully sent to $email');
                          Navigator.pop(context);
                          // Small delay to let dialog finish closing before refresh
                          Future.delayed(const Duration(milliseconds: 300), () => _loadData());
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ErrorHandler.handleApiError(e);
                        }
                      } finally {
                        setDialogState(() => _isInviting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isInviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRemoveMember(int userId) async {
    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      ErrorHandler.showErrorPopup(
        "Sorry, you don't have internet. Please connect to internet to create or see the team.",
        title: "No Internet Connection"
      );
      return;
    }
    try {
      await _teamService.removeMember(widget.teamId, userId);
      _loadData();
      ErrorHandler.showSuccessPopup('Member removed successfully');
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
        isOwner: true,
        teamMembers: _members,
        onDelete: () async {
          try {
            // Optimistic UI: Remove task immediately
            setState(() {
              _tasks.removeWhere((t) => t['id'] == task['id']);
            });
            await _teamService.deleteTask(task['id']);
            // Sync with server quietly
            _loadData(showLoading: false);
            ErrorHandler.showSuccessPopup('Task deleted successfully');
          } catch (e) {
            // Revert or show error
            _loadData(showLoading: false);
            ErrorHandler.handleApiError(e);
          }
        },
        onEditComplete: () => _loadData(showLoading: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isOffline && _teamData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('No Internet Connection', style: TextStyle(color: AppColors.textPrimary)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              const Text(
                "You're Offline",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Sorry, you don't have internet. Please connect to internet to create or see the team.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _loadData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
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
                  if (_teamData?['created_by'] != null && 
                      _currentUserId != null &&
                      _teamData?['created_by'].toString() == _currentUserId.toString())
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
                    'Team Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_teamData?['created_by']?.toString() ==
                      _currentUserId?.toString())
                    _SmallButton(
                      label: 'Add New Member',
                      onTap: () => _showAddMemberDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ..._members.map(
                (m) {
                  final String? ownerId = _teamData?['created_by']?.toString();
                  final String? myId = _currentUserId?.toString();
                  final bool isOwner = ownerId != null && myId != null && ownerId == myId;
                  
                  final bool isMe = m['email']?.toString().toLowerCase().trim() ==
                      _currentUserEmail?.toLowerCase().trim();

                  return _MemberTile(
                    name: m['name'] ?? '',
                    role: m['role'] ?? 'Member',
                    avatarUrl: ImageUtils.getAvatarUrl(m['avatar']),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberDetailPage(
                            teamId: widget.teamId,
                            member: m,
                            memberTasks: _tasks.where((t) {
                              final assignedEmails =
                                  (t['assigned_emails'] as List<dynamic>?)
                                      ?.cast<String>() ??
                                  [];
                              final memberEmail = m['email']
                                  ?.toString()
                                  .toLowerCase()
                                  .trim();
                              return memberEmail != null &&
                                  assignedEmails.any(
                                    (e) =>
                                        e.toLowerCase().trim() == memberEmail,
                                  );
                            }).toList(),
                            currentUserEmail: _currentUserEmail,
                            isOwner: isOwner,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                    onMore: (isOwner && !isMe) ? () => _showMemberOptions(m) : null,
                  );
                },
              ),

              const SizedBox(height: 32),

              // Tasks Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Team Tasks',
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
                    assignedEmails:
                        (t['assigned_emails'] as List<dynamic>?)
                            ?.cast<String>() ??
                        [t['user']?['email'] ?? 'Unassigned'],
                    completedBy:
                        (t['completed_by'] as List<dynamic>?)?.cast<String>() ??
                        [],
                    isDone: t['is_completed'] == true,
                    currentUserEmail: _currentUserEmail,
                    isOffline: _isOffline,
                    onTap: () => _showTaskDetail(t),
                    onToggle: () async {
                      if (_isOffline) return;
                      final bool isOwner =
                          _teamData?['created_by']?.toString() ==
                          _currentUserId?.toString();
                      final List<String> assignedEmails =
                          (t['assigned_emails'] as List<dynamic>?)
                              ?.cast<String>() ??
                          [];
                      final String? currentUserEmailNormalized =
                          _currentUserEmail?.toLowerCase().trim();

                      final bool isAssigned =
                          currentUserEmailNormalized != null &&
                          assignedEmails.any(
                            (e) =>
                                e.toLowerCase().trim() ==
                                currentUserEmailNormalized,
                          );

                      if (isOwner || isAssigned) {
                        final taskIndex = _tasks.indexOf(t);
                        if (taskIndex != -1) {
                          setState(() {
                            final task = Map<String, dynamic>.from(
                              _tasks[taskIndex],
                            );
                            final List<String> completedBy =
                                (task['completed_by'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                [];

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
                                completedBy.add(_currentUserEmail!);
                              }
                            }

                            task['completed_by'] = completedBy;
                            final int totalAssigned = assignedEmails.isNotEmpty
                                ? assignedEmails.length
                                : 1;
                            task['is_completed'] =
                                completedBy.length >= totalAssigned;
                            _tasks[taskIndex] = task;
                          });
                        }

                        try {
                          await _teamService.toggleMemberTaskStatus(t['id']);
                          // Logic for sync with today's focus (Dashboard sync)
                          if (_currentUserEmail != null) {
                            _taskRepository.fetchTasksFromServer(_currentUserEmail!);
                          }
                          _loadData(showLoading: false);
                        } catch (e) {
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
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const _MemberTile({
    required this.name,
    required this.role,
    this.avatarUrl,
    required this.onTap,
    this.onMore,
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
            CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
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
            if (onMore != null)
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_vert, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String title;
  final List<String> assignedEmails;
  final List<String> completedBy;
  final bool isDone;
  final String? currentUserEmail;
  final bool isOffline;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskTile({
    required this.title,
    required this.assignedEmails,
    required this.completedBy,
    required this.isDone,
    this.currentUserEmail,
    required this.isOffline,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final int totalAssigned = assignedEmails.length;
    final int totalCompleted = completedBy.length;
    final double progress = totalAssigned > 0
        ? totalCompleted / totalAssigned
        : 0;
    final bool currentUserChecked =
        currentUserEmail != null &&
        completedBy.any(
          (e) =>
              e.toLowerCase().trim() == currentUserEmail!.toLowerCase().trim(),
        );

    return AbsorbPointer(
      absorbing: isOffline,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
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
                        const SizedBox(height: 4),
                        ...assignedEmails.map((email) {
                          final bool memberChecked = completedBy.any(
                            (e) =>
                                e.toLowerCase().trim() == email.toLowerCase().trim(),
                          );
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                memberChecked
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: memberChecked ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    color: memberChecked ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                                  color: isDone ? Colors.green : Colors.blue,
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$totalCompleted/$totalAssigned',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: currentUserChecked,
                    onChanged: (val) => onToggle(),
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            if (isOffline)
              Positioned.fill(
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
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

class _TaskDetailSheet extends StatelessWidget {
  final dynamic task;
  final bool isOwner;
  final List<dynamic> teamMembers;
  final VoidCallback onDelete;
  final VoidCallback onEditComplete;

  const _TaskDetailSheet({
    required this.task,
    required this.isOwner,
    required this.teamMembers,
    required this.onDelete,
    required this.onEditComplete,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime? deadline = task['deadline'] != null
        ? DateTime.tryParse(task['deadline'])
        : null;
    final String time = deadline != null
        ? DateFormat('HH:mm').format(deadline)
        : '--:--';

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
            // Allow all members to manage group tasks
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

                      if (confirm == true && context.mounted) {
                        Navigator.pop(context); // Close sheet immediately
                        onDelete();
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
                        Navigator.pop(context); // Close sheet
                        onEditComplete();
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
      ),
    );
  }
}
