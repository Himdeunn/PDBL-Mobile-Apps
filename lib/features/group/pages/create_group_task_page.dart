import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/primary_button.dart';
import '../../auth/services/auth_service.dart';
import '../../task/models/task_local.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/utils/error_handler.dart';
import '../services/team_service.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/connection_service.dart';

class CreateGroupTaskPage extends StatefulWidget {
  final AuthService? authService;
  const CreateGroupTaskPage({super.key, this.authService});

  @override
  State<CreateGroupTaskPage> createState() => _CreateGroupTaskPageState();
}

class _CreateGroupTaskPageState extends State<CreateGroupTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _invitedEmails = [];

  final TeamService _teamService = TeamService();
  final TaskRepository _taskRepository = TaskRepository();
  final ConnectionService _connectionService = ConnectionService();
  bool _isSaving = false;
  bool _isOffline = false;
  bool _isLoading = true;
  bool _isValidatingEmail = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    final isOnline = await _connectionService.isConnected();
    if (mounted) {
      setState(() {
        _isOffline = !isOnline;
        _isLoading = false;
      });
      if (!isOnline) {
        ErrorHandler.showErrorPopup(
          "Sorry, you don't have internet. Please connect to internet to create or see the team.",
          title: "No Internet Connection",
        );
      }
    }
  }

  Future<void> _addEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    
    if (email.isEmpty) return;

    if (!emailRegex.hasMatch(email)) {
      ErrorHandler.showErrorPopup("Please enter a valid email address.", title: "Invalid Email");
      return;
    }
    
    if (_invitedEmails.contains(email)) {
      ErrorHandler.showErrorPopup("This email is already in your invite list.", title: "Duplicate Email");
      return;
    }

    // New validation: check if user exists in backend
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
          "User with this email was not found in our system.", 
          title: "User Not Found"
        );
      }
    } catch (e) {
      if (e.toString().contains('404')) {
        ErrorHandler.showErrorPopup(
          "User with this email was not found in our system.", 
          title: "User Not Found"
        );
      } else {
        ErrorHandler.showErrorPopup(
          "Could not verify user at this time. Please check your connection.", 
          title: "Verification Error"
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isValidatingEmail = false);
      }
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _invitedEmails.remove(email);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _handleCreate() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final isOnline = await _connectionService.isConnected();
    if (!isOnline) {
      ErrorHandler.showErrorPopup(
        "Sorry, you don't have internet. Please connect to internet to create or see the team.",
        title: "No Internet Connection",
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String trimmedTitle = _titleController.text.trim();
      final String trimmedDescription = _descriptionController.text.trim();

      // 1. Create Team
      final teamResponse = await _teamService.createTeam(
        trimmedTitle,
        description: trimmedDescription, // Added description support
      );
      final int teamId = teamResponse['team']['id'];

      // 2. Invite People
      if (_invitedEmails.isNotEmpty) {
        await Future.wait(
          _invitedEmails.map(
            (email) => _teamService.inviteToTeam(teamId, email).catchError((e) {
              // Silently fail
            }),
          ),
        );
      }

      // 3. Create Task for the Team
      final user = await widget.authService?.getCurrentUser();
      final userEmail = user?.email ?? 'guest';

      final task = TaskLocal();
      task.title = trimmedTitle;
      task.description = trimmedDescription;
      task.dueDate = _selectedDate;
      task.dueTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';
      task.priority = 'medium';
      task.userEmail = userEmail;
      task.teamId = teamId;

      await _taskRepository.createTask(task, userEmail);

      if (mounted) {
        ErrorHandler.showSuccessPopup('Project Team created successfully!');
        Navigator.pop(context, true);
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

    if (_isOffline) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('No Internet Connection', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
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
                child: const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red),
              ),
              const SizedBox(height: 24),
              const Text(
                "You're Offline",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Sorry, you don't have internet. Please connect to internet to create or see the team.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _checkInitialConnection();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Project Team',
          style: TextStyle(
            color: Color(0xFF2D2631),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Task Title'),
                  _buildTextField(
                    _titleController,
                    'Enter task name...',
                    enabled: !_isSaving,
                    maxLength: 100,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter title';
                      if (v.trim().length > 100) return 'Title must be 100 characters or less';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildLabel('Description'),
                  _buildTextField(
                    _descriptionController,
                    'Write details about your task here...',
                    enabled: !_isSaving,
                    maxLines: 5,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 24),
                  _buildLabel('Add Member'),
                  TextField(
                    controller: _emailController,
                    onSubmitted: (_) => _isSaving ? null : _addEmail(),
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      hintText: 'Add Member Email',
                      fillColor: AppColors.surface,
                      filled: true,
                      counterText: "", // Hide count for email field
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _isValidatingEmail
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.add, color: AppColors.primary),
                              onPressed: (_isSaving || _isValidatingEmail) ? null : _addEmail,
                            ),
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _invitedEmails
                        .map((email) => _buildEmailChip(email))
                        .toList(),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Due Date'),
                            _buildPickerTile(
                              icon: Icons.calendar_today_outlined,
                              text: DateFormat(
                                'MMM dd, yyyy',
                              ).format(_selectedDate),
                              onTap: _isSaving
                                  ? () {}
                                  : () => _selectDate(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Time'),
                            _buildPickerTile(
                              icon: Icons.access_time,
                              text: _selectedTime.format(context),
                              onTap: _isSaving
                                  ? () {}
                                  : () => _selectTime(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _isSaving
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : PrimaryButton(
                          label: 'Create Task',
                          onPressed: _handleCreate,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    bool enabled = true,
    Color? fillColor,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: fillColor ?? AppColors.surface,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? fillColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fillColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailChip(String email) {
    return Chip(
      avatar: const CircleAvatar(child: Icon(Icons.person, size: 14)),
      label: Text(email, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: _isSaving ? null : () => _removeEmail(email),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
