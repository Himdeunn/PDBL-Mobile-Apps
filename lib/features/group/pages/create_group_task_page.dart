import 'dart:async';

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
import '../../../../core/widgets/native_text_input.dart';

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
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _connectionSubscription = _connectionService.isConnectedStream.listen((
      connected,
    ) {
      if (!mounted) return;
      setState(() => _isOffline = !connected);
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final isOnline = await _connectionService.isConnected();
    if (mounted) {
      setState(() {
        _isOffline = !isOnline;
        _isLoading = false;
      });
    }
  }

  Future<void> _addEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );

    if (email.isEmpty) return;

    if (!emailRegex.hasMatch(email)) {
      ErrorHandler.showErrorPopup(
        "Please enter a valid email address.",
        title: "Invalid Email",
      );
      return;
    }

    if (_invitedEmails.contains(email)) {
      ErrorHandler.showErrorPopup(
        "This email is already in your invite list.",
        title: "Duplicate Email",
      );
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
          title: "User Not Found",
        );
      }
    } catch (e) {
      if (e.toString().contains('404')) {
        ErrorHandler.showErrorPopup(
          "User with this email was not found in our system.",
          title: "User Not Found",
        );
      } else {
        ErrorHandler.showErrorPopup(
          "Could not verify user at this time. Please check your connection.",
          title: "Verification Error",
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
    final fifteenYearsLater = DateTime(now.year + 15, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: fifteenYearsLater,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (_selectedDate.year == today.year &&
          _selectedDate.month == today.month &&
          _selectedDate.day == today.day) {
        if (picked.hour < now.hour ||
            (picked.hour == now.hour && picked.minute < now.minute)) {
          if (mounted) {
            ErrorHandler.showErrorPopup('Time cannot be in the past');
          }
          return;
        }
      }
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleCreate() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

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
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
                  if (_isOffline) ...[
                    _buildOfflineNotice(),
                    const SizedBox(height: 16),
                  ],
                  _buildLabel('Task Title *'),
                  _buildTextField(
                    _titleController,
                    'Enter task name...',
                    enabled: !_isSaving,
                    maxLength: 100,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter title';
                      if (v.trim().length > 100)
                        return 'Title must be 100 characters or less';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildLabel('Description (optional)'),
                  _buildTextField(
                    _descriptionController,
                    'Write details about your task here...',
                    enabled: !_isSaving,
                    maxLines: 5,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 24),
                  _buildLabel('Add Member (optional)'),
                  NativeTextInput(
                    controller: _emailController,
                    onSubmitted: (_) => _isSaving ? null : _addEmail(),
                    enabled: !_isSaving,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    maxLength: 100,
                    height: 52,
                    hintText: 'Add Member Email',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    fallbackBuilder: (context) => TextField(
                      controller: _emailController,
                      onSubmitted: (_) => _isSaving ? null : _addEmail(),
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'Add Member Email',
                        fillColor: AppColors.surface,
                        filled: true,
                        counterText: "",
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: AppColors.primary,
                                ),
                                onPressed: (_isSaving || _isValidatingEmail)
                                    ? null
                                    : _addEmail,
                              ),
                      ),
                      maxLength: 100,
                    ),
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
                            _buildLabel('Due Date *'),
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
                            _buildLabel('Time *'),
                            _buildPickerTile(
                              icon: Icons.access_time,
                              text:
                                  "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}",
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

  Widget _buildOfflineNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.28)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline mode: the task is saved locally and will sync when the connection returns.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
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
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: fillColor ?? AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: field.hasError
                  ? Border.all(color: Colors.red, width: 1)
                  : null,
            ),
            child: NativeTextInput(
              controller: controller,
              maxLines: maxLines,
              maxLength: maxLength,
              enabled: enabled,
              height: maxLines > 1 ? 120 : 52,
              hintText: hint,
              borderRadius: 20,
              onChanged: field.didChange,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              fallbackBuilder: (context) => TextFormField(
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
              ),
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                field.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ],
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
