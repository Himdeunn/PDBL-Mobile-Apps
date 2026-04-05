import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_utils.dart';
import '../widgets/invitation_card.dart';
import '../widgets/group_card.dart';
import '../services/team_service.dart';
import '../../auth/services/auth_service.dart';
import 'team_detail_page.dart';
import '../../../../core/services/connection_service.dart';

class GroupPage extends StatefulWidget {
  final AuthService? authService;
  const GroupPage({super.key, this.authService});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final TeamService _teamService = TeamService();
  late final AuthService _authService;
  List<dynamic> _teams = [];
  List<dynamic> _invitations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  final ConnectionService _connectionService = ConnectionService();
  int? _currentUserId;
  bool _isOffline = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      }
    });
    _fetchData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    // Don't start timer for guests to avoid 401 spam
    _authService.isGuest().then((isGuest) {
      if (!isGuest && mounted) {
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
          if (mounted) _fetchData(silent: true);
        });
      }
    });
  }

  Future<void> _fetchData({bool silent = false}) async {
    final isGuest = await _authService.isGuest();
    if (isGuest) {
      if (mounted) {
        setState(() {
          _teams = [];
          _invitations = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (!silent && mounted) setState(() => _isLoading = true);
    
    // Check connection
    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
        if (!silent) {
          ErrorHandler.showErrorPopup(
            "Sorry, you don't have internet. Please connect to internet to create or see the team.",
            title: "No Internet Connection"
          );
        }
      }
      return;
    }

    try {
      final user = await _authService.getCurrentUser();
      _currentUserId = user?.id;

      final rawData = await _teamService.getDashboardData();
      if (mounted) {
        setState(() {
          _isOffline = false;
          // Robust parsing for teams
          final teamsPart = rawData is Map ? rawData['teams'] : null;
          if (teamsPart is List) {
            _teams = teamsPart;
          } else if (teamsPart is Map && teamsPart['data'] is List) {
            _teams = teamsPart['data'];
          } else if (teamsPart is Map) {
            // Handle associative map from PHP
            _teams = teamsPart.values.toList();
          } else {
            _teams = [];
          }
          
          // Robust parsing for invitations
          final invitesPart = rawData is Map ? rawData['invitations'] : null;
          if (invitesPart is List) {
            _invitations = invitesPart;
          } else if (invitesPart is Map && invitesPart['data'] is List) {
            _invitations = invitesPart['data'];
          } else if (invitesPart is Map) {
            _invitations = invitesPart.values.toList();
          } else {
            _invitations = [];
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleApiError(e);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInvitation(int teamId, bool accept) async {
    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      ErrorHandler.showErrorPopup(
        "Sorry, you don't have internet. Please connect to internet to create or see the team.",
        title: "No Internet Connection"
      );
      return;
    }

    try {
      if (accept) {
        await _teamService.acceptInvitation(teamId);
      } else {
        await _teamService.declineInvitation(teamId);
      }
      _fetchData();
    } catch (e) {
      ErrorHandler.handleApiError(e);
    }
  }

  Future<void> _confirmDeleteTeam(int teamId, String teamName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Team'),
        content: Text(
          'Are you sure you want to delete "$teamName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _teamService.deleteTeam(teamId);
        _fetchData();
        ErrorHandler.showSuccessPopup('Team deleted successfully');
      } catch (e) {
        ErrorHandler.handleApiError(e);
      }
    }
  }

  void _showTeamOptions(dynamic team) {
    if (team['created_by']?.toString() != _currentUserId?.toString()) {
      return; // Only owner can delete
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Team'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to team detail for editing
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamDetailPage(
                      teamId: team['id'],
                      authService: _authService,
                    ),
                  ),
                ).then((_) => _fetchData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Team Project',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTeam(team['id'], team['name'] ?? 'this team');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Project Team',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Search Bar Placeholder
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEE8E0),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search Project / Team',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (_isOffline && _teams.isEmpty && _invitations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              size: 64,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Offline Mode",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "Sorry, you don't have internet. Please connect to internet to create or see the team.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _fetchData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text("Try Again"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Invitations Section
                  if (_invitations.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'Pending Invitations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDE8E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_invitations.length} New',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2631),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._invitations.where((invite) {
                      final name = (invite['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery);
                    }).map(
                      (invite) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InvitationCard(
                          title: invite['name'] ?? 'Team',
                          description: invite['description'] ?? '',
                          inviter: invite['owner']['name'] ?? 'Unknown',
                          icon: Icons.group_add_rounded,
                          onAccept: () => _handleInvitation(invite['id'], true),
                          onReject: () =>
                              _handleInvitation(invite['id'], false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Teams Section
                  const Text(
                    'Project Team',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_teams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'You are not in any teams yet.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  else
                    ..._teams.where((team) {
                      final name = (team['name'] ?? '').toString().toLowerCase();
                      final desc = (team['description'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || desc.contains(_searchQuery);
                    }).map(
                      (team) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GroupCard(
                          title: team['name'] ?? '',
                          description: team['description'] ?? 'Team Project',
                          icon: Icons.groups_rounded,
                          progress: (team['progress'] ?? 0).toDouble() / 100.0,
                          memberCount: (team['members'] as List?)?.length ?? 0,
                          memberAvatars: ((team['members'] as List?) ?? [])
                              .map((m) => ImageUtils.getAvatarUrl(m['avatar']))
                              .toList(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamDetailPage(
                                  teamId: team['id'],
                                  authService: _authService,
                                ),
                              ),
                            ).then((_) => _fetchData());
                          },
                          onMoreTap:
                              team['created_by']?.toString() ==
                                  _currentUserId?.toString()
                              ? () => _showTeamOptions(team)
                              : null, // Only show if owner
                        ),
                      ),
                    ),
                  
                  // Guest Mode Message
                  FutureBuilder<bool>(
                    future: _authService.isGuest(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textTertiary),
                                const SizedBox(height: 16),
                                const Text(
                                  'Login required to use\nTeam Project features',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
