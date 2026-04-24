import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/primary_button.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/register_page.dart';
import '../services/team_service.dart';

class CreateTeamPage extends StatefulWidget {
  final AuthService? authService;
  final VoidCallback? onSuccess;

  const CreateTeamPage({super.key, this.authService, this.onSuccess});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  final TeamService _teamService = TeamService();
  final ConnectionService _connectionService = ConnectionService();

  final _maxMembersController = TextEditingController(text: '100');
  final List<String> _invitedEmails = [];
  bool _isSaving = false;
  bool _isOffline = false;
  bool _isLoading = true;
  bool _isGuest = false;
  bool _isValidatingEmail = false;
  int get _maxMembers => int.tryParse(_maxMembersController.text) ?? 100;
  bool get _canInviteMore => _invitedEmails.length + 1 < _maxMembers;

  @override

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final auth = widget.authService ?? AuthService();
    final guest = await auth.isGuest();
    final online = await _connectionService.isConnected();
    if (mounted) {
      setState(() {
        _isGuest = guest;
        _isOffline = !online;
        _isLoading = false;
      });
    }
  }

  Future<void> _addEmail() async {
    if (_maxMembers <= 1) {
      ErrorHandler.showErrorPopup(
          'Maximum members is set to 1. Only the leader can be in this team.',
          title: 'Invitation Disabled');
      return;
    }

    if (!_canInviteMore) {
      ErrorHandler.showErrorPopup(
          'You have reached the maximum number of members for this team. Increase the limit to invite more.',
          title: 'Member Limit Reached');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

    if (email.isEmpty) return;
    if (!emailRegex.hasMatch(email)) {
      ErrorHandler.showErrorPopup('Please enter a valid email address.',
          title: 'Invalid Email');
      return;
    }
    if (_invitedEmails.contains(email)) {
      ErrorHandler.showErrorPopup('This email is already in your invite list.',
          title: 'Duplicate Email');
      return;
    }

    setState(() => _isValidatingEmail = true);
    try {
      final result = await _teamService.checkEmail(email);
      if (result['exists'] == true) {
        setState(() {
          _invitedEmails.add(email);
          _emailController.clear();
        });
      } else {
        ErrorHandler.showErrorPopup(
            'User with this email was not found in our system.',
            title: 'User Not Found');
      }
    } catch (e) {
      ErrorHandler.showErrorPopup(
          'Could not verify user. Please check your connection.',
          title: 'Verification Error');
    } finally {
      if (mounted) setState(() => _isValidatingEmail = false);
    }
  }

  void _removeEmail(String email) =>
      setState(() => _invitedEmails.remove(email));

  Future<void> _handleCreate() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      ErrorHandler.showErrorPopup(
          "No internet connection. Please connect to create a team.",
          title: 'No Internet');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final int maxMembers = int.tryParse(_maxMembersController.text.trim()) ?? 100;
      final response = await _teamService.createTeam(
        _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        maxMembers: maxMembers.clamp(1, 100),
      );

      final int teamId = response['team']['id'];

      if (_invitedEmails.isNotEmpty) {
        await Future.wait(
          _invitedEmails.map(
            (email) =>
                _teamService.inviteToTeam(teamId, email).catchError((_) {}),
          ),
        );
      }

      if (mounted) {
        ErrorHandler.showSuccessPopup('Team created successfully!');
        _nameController.clear();
        _descriptionController.clear();
        _emailController.clear();
        setState(() {
          _invitedEmails.clear();
        });
        if (mounted) {
          widget.onSuccess?.call();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_isGuest) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 64, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Login Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You need to be logged in to create or manage a team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Login',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Create Account',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isOffline) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 72, color: Colors.red),
              ),
              const SizedBox(height: 24),
              const Text("You're Offline",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Please connect to the internet to create a team.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _checkStatus();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Team',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Set up a new team and invite members',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      _label('Team Name *'),
                      _textField(
                        _nameController,
                        'Enter team name...',
                        maxLength: 50,
                        showCounter: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a team name'
                            : null,
                      ),

                      const SizedBox(height: 14),
                      _label('Description (optional)'),
                      _textField(
                        _descriptionController,
                        'What is this team about?',
                        maxLines: 3,
                        maxLength: 150,
                        showCounter: true,
                      ),

                      const SizedBox(height: 14),
                      _label('Max Members (1–100)'),
                      TextFormField(
                        controller: _maxMembersController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '100',
                          fillColor: AppColors.surface,
                          filled: true,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 100) {
                            return 'Please enter a number between 1 and 100';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),
                      Builder(builder: (context) {
                        final maxM = int.tryParse(_maxMembersController.text) ?? 100;
                        final currentCount = 1 + _invitedEmails.length; // 1 (Leader) + invited
                        final canInvite = currentCount < maxM;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Invite Members (optional)'),
                            TextField(
                              controller: _emailController,
                              onSubmitted: (_) => _isSaving ? null : _addEmail(),
                              enabled: !_isSaving && canInvite,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: canInvite ? 'Member email address' : 'Max members reached ($maxM/$maxM)',
                                fillColor: canInvite ? AppColors.surface : Colors.grey.withValues(alpha: 0.1),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: _isValidatingEmail
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(Icons.add, color: canInvite ? AppColors.primary : Colors.grey),
                                        onPressed: (_isSaving || _isValidatingEmail || !canInvite) ? null : _addEmail,
                                      ),
                              ),
                            ),
                          ],
                        );
                      }),

                      if (_invitedEmails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _invitedEmails
                              .map((email) => Chip(
                                    avatar: const CircleAvatar(
                                        child:
                                            Icon(Icons.person, size: 12)),
                                    label: Text(email,
                                        style:
                                            const TextStyle(fontSize: 11)),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 12),
                                    onDeleted: _isSaving
                                        ? null
                                        : () => _removeEmail(email),
                                    backgroundColor: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 32),

                      _isSaving
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            )
                          : PrimaryButton(
                              label: 'Create Team',
                              onPressed: _handleCreate,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary)),
      );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? maxLength,
    bool showCounter = false,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        enabled: !_isSaving,
        buildCounter: showCounter ? null : (context, {required currentLength, required isFocused, required maxLength}) => null,
        decoration: InputDecoration(
          hintText: hint,
          fillColor: AppColors.surface,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
}
