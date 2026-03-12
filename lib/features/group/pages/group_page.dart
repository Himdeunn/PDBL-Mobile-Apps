import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../widgets/invitation_card.dart';
import '../widgets/group_card.dart';
import '../services/team_service.dart';
import '../../auth/services/auth_service.dart';
import 'team_detail_page.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final TeamService _teamService = TeamService();
  final AuthService _authService =
      AuthService(); // Ensure AuthService is initialized
  List<dynamic> _teams = [];
  List<dynamic> _invitations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _fetchData(silent: true);
    });
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      _currentUserId = user?.id;

      final data = await _teamService.getDashboardData();
      setState(() {
        _teams = data['teams'] ?? [];
        _invitations = data['invitations'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching teams: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInvitation(int teamId, bool accept) async {
    try {
      if (accept) {
        await _teamService.acceptInvitation(teamId);
      } else {
        await _teamService.declineInvitation(teamId);
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
      }
    }
  }

  Future<void> _confirmDeleteTeam(int teamId, String teamName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Are you sure you want to delete "$teamName"? This action cannot be undone.'),
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete team: $e')));
        }
      }
    }
  }

  void _showTeamOptions(dynamic team) {
    if (team['created_by']?.toString() != _currentUserId?.toString()) return; // Only owner can delete

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
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Project / Team',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 16,
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Invitations Section
                if (_invitations.isNotEmpty) ...[
                  Row(
                    children: [
                  const Text(
                    'Undangan Tertunda',
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
                  ..._invitations.map(
                    (invite) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InvitationCard(
                        title: invite['name'] ?? 'Team',
                        description: invite['description'] ?? '',
                        inviter: invite['owner']['name'] ?? 'Unknown',
                        icon: Icons.group_add_rounded,
                        onAccept: () => _handleInvitation(invite['id'], true),
                        onReject: () => _handleInvitation(invite['id'], false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Teams Section
                const Text(
                  'Tim Project',
                  style: TextStyle(
                    fontSize: 20,
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
                  ..._teams.map(
                    (team) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GroupCard(
                        title: team['name'] ?? '',
                        description: team['description'] ?? 'Team Project',
                        icon: Icons.groups_rounded,
                        progress: (team['progress'] ?? 0).toDouble() / 100.0,
                        memberCount: (team['members'] as List?)?.length ?? 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeamDetailPage(
                                teamId: team['id'],
                                authService: AuthService(),
                              ),
                            ),
                          ).then((_) => _fetchData());
                        },
                        onMoreTap: team['created_by']?.toString() == _currentUserId?.toString()
                            ? () => _showTeamOptions(team)
                            : null, // Only show if owner
                      ),
                    ),
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
