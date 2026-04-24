import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/image_cache_manager.dart';
import '../../../../core/utils/network_utils.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/time_utils.dart';

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
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isUpdatingAvatar = false;
  bool _isPickingImage = false;
  Map<String, dynamic>? _teamData;
  List<dynamic> _members = [];
  List<dynamic> _tasks = [];
  final ConnectionService _connectionService = ConnectionService();
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isOffline = false;
  bool _isInviting = false;
  Timer? _refreshTimer;

  // Members search + pagination
  final TextEditingController _memberSearchController = TextEditingController();
  String _memberSearchQuery = '';
  int _memberPage = 0;
  static const int _membersPerPage = 5;

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
    // Auto-refresh every 5 seconds so all members see updated task states promptly
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isOffline) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _memberSearchController.dispose();
    super.dispose();
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
            final List<dynamic> memberList = [];
            final membersPart = rawData['members'] ?? _teamData?['members'];
            if (membersPart is List) {
              memberList.addAll(membersPart);
            } else if (membersPart is Map) {
              memberList.addAll(membersPart.values);
            }

            // Ensure owner/leader is in the members list
            final owner = rawData['owner'] ?? _teamData?['owner'];
            if (owner is Map) {
              final ownerEmail = owner['email']?.toString().toLowerCase();
              if (ownerEmail != null) {
                final exists = memberList.any((m) => 
                  m is Map && m['email']?.toString().toLowerCase() == ownerEmail
                );
                if (!exists) {
                  memberList.insert(0, owner);
                }
              }
            }

            _members = memberList.map((m) {
              if (m is Map) return m;
              return {'name': m.toString(), 'email': m.toString()};
            }).toList();
            
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
          // Reset to first page if filtered results no longer cover current page
          _memberPage = 0;
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

  Future<void> _pickTeamAvatar() async {
    if (_isPickingImage) return;
    final bool isOwner = _teamData?['created_by']?.toString() == _currentUserId?.toString();
    if (!isOwner) return;

    setState(() => _isPickingImage = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text('Change Team Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.camera_alt, color: Color(0xFFA855F7))),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.photo_library, color: Color(0xFFA855F7))),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: source == ImageSource.camera ? 80 : null,
      );
      if (image == null) return;

      final file = File(image.path);
      final int sizeInBytes = await file.length();
      final bool isGif = image.path.toLowerCase().endsWith('.gif');
      final int maxSize = isGif ? 2 * 1024 * 1024 : 1 * 1024 * 1024;

      if (sizeInBytes > maxSize) {
        ErrorHandler.showErrorPopup('File too large (Image max 1MB, GIF max 2MB)');
        return;
      }

      setState(() => _isUpdatingAvatar = true);
      try {
        await _teamService.uploadTeamAvatar(
          widget.teamId,
          image.path,
          oldAvatarUrl: _teamData?['avatar_url'] as String?,
        );
        await _loadData(showLoading: false);
        if (mounted) ErrorHandler.showSuccessPopup('Team photo updated!');
      } catch (e) {
        ErrorHandler.handleApiError(e);
      } finally {
        if (mounted) setState(() => _isUpdatingAvatar = false);
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _showEditTeamDialog() async {
    final nameController = TextEditingController(text: _teamData?['name']);
    final descController = TextEditingController(text: _teamData?['description']);
    final maxMembersController = TextEditingController(
      text: (_teamData?['max_members'] ?? 100).toString(),
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
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: maxMembersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Members (1–100)',
                hintText: '100',
              ),
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
              final maxMembers = int.tryParse(maxMembersController.text.trim());
              if (maxMembers == null || maxMembers < 1 || maxMembers > 100) {
                ErrorHandler.showErrorPopup('Max members must be between 1 and 100');
                return;
              }
              // Prevent reducing below current member count
              final currentCount = _members.length;
              if (maxMembers < currentCount) {
                ErrorHandler.showErrorPopup(
                  'Cannot set max members below current member count ($currentCount)',
                );
                return;
              }
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
                  maxMembers: maxMembers,
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


  List<String> _getAssignedUsernames(List<String> emails) {
    return emails.map((email) {
      final member = _members.firstWhere(
        (m) => m is Map &&
            m['email']?.toString().toLowerCase().trim() ==
                email.toLowerCase().trim(),
        orElse: () => <String, dynamic>{},
      );
      if (member is Map &&
          member['name'] != null &&
          (member['name'] as String).isNotEmpty) {
        return member['name'] as String;
      }
      return email.contains('@') ? email.split('@').first : email;
    }).toList();
  }

  void _showTaskDetail(dynamic task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailSheet(
        task: task,
        isOwner: _teamData?['created_by']?.toString() == _currentUserId?.toString(),
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

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Project Team',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBox(200, 28),
              const SizedBox(height: 8),
              _skeletonBox(140, 16),
              const SizedBox(height: 24),
              _skeletonBox(double.infinity, 80),
              const SizedBox(height: 24),
              Row(
                children: [
                  _skeletonBox(40, 40, circle: true),
                  const SizedBox(width: 10),
                  _skeletonBox(40, 40, circle: true),
                  const SizedBox(width: 10),
                  _skeletonBox(40, 40, circle: true),
                ],
              ),
              const SizedBox(height: 24),
              _skeletonBox(100, 20),
              const SizedBox(height: 12),
              _skeletonBox(double.infinity, 72),
              const SizedBox(height: 12),
              _skeletonBox(double.infinity, 72),
              const SizedBox(height: 12),
              _skeletonBox(double.infinity, 72),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height, {bool circle = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3252),
        borderRadius: circle ? BorderRadius.circular(height / 2) : BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton();
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
                  GestureDetector(
                    onTap: (_teamData?['created_by']?.toString() == _currentUserId?.toString())
                        ? _pickTeamAvatar
                        : null,
                    child: Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isUpdatingAvatar
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : (_teamData?['avatar_url'] != null && (_teamData!['avatar_url'] as String).isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: _teamData!['avatar_url'] as String,
                                        fit: BoxFit.cover,
                                        httpHeaders: getNetworkImageHeaders(_teamData!['avatar_url'] as String),
                                        cacheManager: WudiCacheManager(),
                                        errorWidget: (_, _, _) => const Icon(Icons.palette_rounded, color: Color(0xFFA855F7), size: 32),
                                      ),
                                    )
                                  : const Icon(Icons.palette_rounded, color: Color(0xFFA855F7), size: 32),
                        ),
                        if (_teamData?['created_by']?.toString() == _currentUserId?.toString())
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
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
                  Text(
                    'Team Members (${_members.length}/${_teamData?['max_members'] ?? 100})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_teamData?['created_by']?.toString() ==
                      _currentUserId?.toString())
                    _SmallButton(
                      label: 'Add New Member',
                      onTap: () => _showAddMemberDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              TextField(
                controller: _memberSearchController,
                onChanged: (v) => setState(() {
                  _memberSearchQuery = v.trim().toLowerCase();
                  _memberPage = 0;
                }),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _memberSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          onPressed: () => setState(() {
                            _memberSearchController.clear();
                            _memberSearchQuery = '';
                            _memberPage = 0;
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final String? ownerId = _teamData?['created_by']?.toString();
                final String? myId = _currentUserId?.toString();
                final bool isOwner = ownerId != null && myId != null && ownerId == myId;

                // Filter by search
                final filtered = _memberSearchQuery.isEmpty
                    ? _members
                    : _members.where((m) {
                        final name = (m['name'] ?? '').toString().toLowerCase();
                        final email = (m['email'] ?? '').toString().toLowerCase();
                        return name.contains(_memberSearchQuery) || email.contains(_memberSearchQuery);
                      }).toList();

                final totalPages = (filtered.length / _membersPerPage).ceil();
                final clampedPage = _memberPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                final pageMembers = filtered.skip(clampedPage * _membersPerPage).take(_membersPerPage).toList();

                return Column(
                  children: [
                    ...pageMembers.map((m) {
                      final bool isMe = m['email']?.toString().toLowerCase().trim() ==
                          _currentUserEmail?.toLowerCase().trim();

                      return _MemberTile(
                        name: m['name'] ?? '',
                        role: m['role'] ?? 'Member',
                        avatarUrl: ImageUtils.getAvatarUrl(m['avatar_url'] ?? m['avatar']),
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
                                        (e) => e.toLowerCase().trim() == memberEmail,
                                      );
                                }).toList(),
                                teamMembers: _members,
                                currentUserEmail: _currentUserEmail,
                                isOwner: isOwner,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                        onMore: (isOwner && !isMe) ? () => _showMemberOptions(m) : null,
                      );
                    }),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: clampedPage > 0
                                ? () => setState(() => _memberPage = clampedPage - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            color: clampedPage > 0 ? AppColors.textPrimary : Colors.grey,
                            iconSize: 28,
                          ),
                          ...List.generate(totalPages, (i) => GestureDetector(
                            onTap: () => setState(() => _memberPage = i),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == clampedPage
                                    ? const Color(0xFF1E1E1E)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == clampedPage ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )),
                          IconButton(
                            onPressed: clampedPage < totalPages - 1
                                ? () => setState(() => _memberPage = clampedPage + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            color: clampedPage < totalPages - 1 ? AppColors.textPrimary : Colors.grey,
                            iconSize: 28,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }),

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
              ..._tasks.map((t) {
                final List<String> assignedEmailsList =
                    (t['assigned_emails'] as List<dynamic>?)?.cast<String>() ??
                    [t['user']?['email'] ?? 'Unassigned'];
                final List<String> completedByList =
                    (t['completed_by'] as List<dynamic>?)?.cast<String>() ?? [];
                final bool taskDone = t['is_completed'] == true;
                final bool taskLeaderChecked = taskDone &&
                    _currentUserEmail != null &&
                    !completedByList.any((e) =>
                        e.toLowerCase().trim() ==
                        _currentUserEmail!.toLowerCase().trim());
                final bool taskIsOwner = _teamData?['created_by']?.toString() == _currentUserId?.toString();
                return _TaskTile(
                  key: ValueKey(t['id']),
                  title: t['judul'] ?? '',
                  priority: t['priority']?.toString(),
                  assignedEmails: assignedEmailsList,
                  assignedUsernames: _getAssignedUsernames(assignedEmailsList),
                  completedBy: completedByList,
                  isDone: taskDone,
                  leaderChecked: taskLeaderChecked,
                  currentUserEmail: _currentUserEmail,
                  isOffline: _isOffline,
                  isOwner: taskIsOwner,
                  onTap: () => _showTaskDetail(t),
                  onToggle: () async {
                    if (_isOffline) return;
                    final bool isOwner = taskIsOwner;
                    final List<String> assignedEmailsForToggle = (t['assigned_emails'] as List<dynamic>?)?.cast<String>() ?? [];
                    final String? currentUserEmailNormalized = _currentUserEmail?.toLowerCase().trim();

                    final bool isAssigned = currentUserEmailNormalized != null && assignedEmailsForToggle.any((e) => e.toLowerCase().trim() == currentUserEmailNormalized);

                    // Block non-owner from toggling a task already force-completed by leader
                    if (t['is_completed'] == true && !isOwner) {
                      ErrorHandler.showErrorPopup('Task has been completed by the leader and cannot be modified');
                      return;
                    }

                    if (isOwner || isAssigned) {
                      final taskIndex = _tasks.indexOf(t);
                      if (taskIndex != -1) {
                        setState(() {
                          final task = Map<String, dynamic>.from(_tasks[taskIndex]);
                          final bool ownerNotAssigned = isOwner && !isAssigned;

                          if (ownerNotAssigned) {
                            // Force-toggle all assigned members
                            final bool currentlyDone = task['is_completed'] == true;
                            if (currentlyDone) {
                              task['completed_by'] = [];
                              task['is_completed'] = false;
                            } else {
                              task['completed_by'] = List<String>.from(assignedEmailsForToggle);
                              task['is_completed'] = true;
                            }
                          } else {
                            // Toggle own entry only
                            final List<String> completedBy = (task['completed_by'] as List<dynamic>?)?.cast<String>() ?? [];
                            if (currentUserEmailNormalized != null) {
                              if (completedBy.any((e) => e.toLowerCase().trim() == currentUserEmailNormalized)) {
                                completedBy.removeWhere((e) => e.toLowerCase().trim() == currentUserEmailNormalized);
                              } else {
                                completedBy.add(_currentUserEmail!);
                              }
                            }
                            task['completed_by'] = completedBy;
                            final int totalAssigned = assignedEmailsForToggle.isNotEmpty ? assignedEmailsForToggle.length : 1;
                            task['is_completed'] = completedBy.where((e) =>
                              assignedEmailsForToggle.any((a) => a.toLowerCase().trim() == e.toLowerCase().trim())
                            ).length >= totalAssigned;
                          }
                          _tasks[taskIndex] = task;
                        });
                      }

                      try {
                        await _teamService.toggleMemberTaskStatus(t['id']);
                        if (_currentUserEmail != null) {
                          _taskRepository.fetchTasksFromServer(_currentUserEmail!);
                        }
                        _loadData(showLoading: false);
                      } catch (e) {
                        _loadData(showLoading: false);
                        ErrorHandler.handleApiError(e);
                      }
                    } else {
                      ErrorHandler.showErrorPopup('Only the owner or assigned member can toggle this task');
                    }
                  },
                );
              }),
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
                  ? CachedNetworkImageProvider(avatarUrl!, headers: getNetworkImageHeaders(avatarUrl!), cacheManager: WudiCacheManager())
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

class _TaskTile extends StatefulWidget {
  final String title;
  final String? priority;
  final List<String> assignedEmails;
  final List<String> assignedUsernames;
  final List<String> completedBy;
  final bool isDone;
  final bool leaderChecked;
  final String? currentUserEmail;
  final bool isOffline;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskTile({
    super.key,
    required this.title,
    this.priority,
    required this.assignedEmails,
    this.assignedUsernames = const [],
    required this.completedBy,
    required this.isDone,
    this.leaderChecked = false,
    this.currentUserEmail,
    required this.isOffline,
    this.isOwner = false,
    required this.onTap,
    required this.onToggle,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _isToggling = false;

  void _handleToggle() {
    if (_isToggling) return;
    _isToggling = true;
    widget.onToggle();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _isToggling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalAssigned = widget.assignedEmails.length;
    final int totalCompleted = widget.isDone
        ? totalAssigned
        : widget.completedBy.where((e) => widget.assignedEmails.any(
            (a) => a.toLowerCase().trim() == e.toLowerCase().trim())).length;
    final double progress = totalAssigned > 0 ? totalCompleted / totalAssigned : 0;
    final bool currentUserChecked = widget.isDone || (
        widget.currentUserEmail != null &&
        widget.completedBy.any(
          (e) => e.toLowerCase().trim() == widget.currentUserEmail!.toLowerCase().trim(),
        )
    );

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
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox on the left
                  GestureDetector(
                    onTap: () {
                      if (widget.isOffline) return;
                      if (widget.isDone && !widget.isOwner) {
                        ErrorHandler.showErrorPopup('Task has been completed by the leader and cannot be modified');
                        return;
                      }
                      _handleToggle();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: currentUserChecked ? Colors.black87 : Colors.black38,
                          width: 1.8,
                        ),
                      ),
                      child: currentUserChecked
                          ? const Icon(Icons.check, size: 14, color: Colors.black87)
                          : null,
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + priority badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPriorityBadge(widget.priority),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Assign to chips
                        if (widget.assignedEmails.isNotEmpty) ...[
                          Row(
                            children: [
                              const Text(
                                'Assign to: ',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: widget.assignedEmails.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final email = entry.value;
                                    final isCurrentUser = widget.currentUserEmail != null &&
                                        email.toLowerCase().trim() ==
                                            widget.currentUserEmail!.toLowerCase().trim();
                                    final rawName = idx < widget.assignedUsernames.length
                                        ? widget.assignedUsernames[idx]
                                        : (email.contains('@') ? email.split('@').first : email);
                                    final displayName = isCurrentUser ? 'You' : (rawName.length > 14 ? '${rawName.substring(0, 13)}…' : rawName);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser ? const Color(0xFF2D2633) : const Color(0xFF4A4A4A),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 10, color: Colors.white70),
                                          const SizedBox(width: 3),
                                          Text(
                                            displayName,
                                            style: const TextStyle(fontSize: 11, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Progress bar + counter
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
                              '$totalCompleted/$totalAssigned',
                              style: const TextStyle(
                                fontSize: 12,
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
                              Text("Offline", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildPriorityBadge(String? priority) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;
    switch ((priority ?? 'low').toLowerCase()) {
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
        ],
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

  static String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final String time = AppTimeUtils.extractTimeFromDeadline(task['deadline']?.toString());
    final DateTime? deadlineDate = task['deadline'] != null
        ? DateTime.tryParse(task['deadline'].toString())
        : null;
    final String dateStr = deadlineDate != null
        ? '${deadlineDate.day.toString().padLeft(2, '0')} '
          '${_monthName(deadlineDate.month)} '
          '${deadlineDate.year}'
        : 'No date set';

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
                // Date
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Time
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
            if (isOwner) ...[Row(
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
            )],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
