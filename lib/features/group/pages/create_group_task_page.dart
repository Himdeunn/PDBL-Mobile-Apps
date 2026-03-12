import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../task/models/task_local.dart';
import '../../task/services/task_repository.dart';
import '../../../../core/utils/error_handler.dart';
import '../services/team_service.dart';
import 'package:intl/intl.dart';

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
  bool _isSaving = false;
  String _selectedPriority = 'Medium';

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        email.contains('@') &&
        !_invitedEmails.contains(email)) {
      setState(() {
        _invitedEmails.add(email);
        _emailController.clear();
      });
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _invitedEmails.remove(email);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 1. Create Team
      final teamResponse = await _teamService.createTeam(
        _titleController.text,
        description: _descriptionController.text, // Added description support
      );
      final int teamId = teamResponse['team']['id'];

      // 2. Invite People
      if (_invitedEmails.isNotEmpty) {
        await Future.wait(
          _invitedEmails.map((email) => _teamService.inviteToTeam(teamId, email).catchError((e) {
            debugPrint('Failed to invite $email: $e');
          })),
        );
      }

      // 3. Create Task for the Team
      final user = await widget.authService?.getCurrentUser();
      final userEmail = user?.email ?? 'guest';

      final task = TaskLocal();
      task.title = _titleController.text;
      task.description = _descriptionController.text;
      task.dueDate = _selectedDate;
      task.dueTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';
      task.priority = _selectedPriority.toLowerCase();
      task.userEmail = userEmail;
      task.teamId = teamId;

      await _taskRepository.createTask(task, userEmail);

      if (mounted) {
        Navigator.pop(context, true);
        ErrorHandler.showSuccessPopup('Project Team created successfully!');
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Project Team',
          style: TextStyle(
            color: Color(0xFF2D2631),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 24),
              _buildLabel('Description'),
              _buildTextField(
                _descriptionController,
                'Write details about your task here...',
                maxLines: 5,
              ),

              const SizedBox(height: 24),
              _buildLabel('Add People'),
              TextField(
                controller: _emailController,
                onSubmitted: (_) => _addEmail(),
                decoration: InputDecoration(
                  hintText: 'Add People',
                  fillColor: const Color(0xFFF1E6D2),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: _addEmail,
                  ),
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
                        _buildLabel('Due Date'),
                        _buildPickerTile(
                          icon: Icons.calendar_today_outlined,
                          text: DateFormat(
                            'MMM dd, yyyy',
                          ).format(_selectedDate),
                          onTap: () => _selectDate(context),
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
                          onTap: () => _selectTime(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _isSaving
            ? const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              )
            : SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF140E0E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Create Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: const Color(0xFFF1E6D2),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E6D2),
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


  Widget _buildPriorityPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ["High", "Medium", "Low"].map((p) {
        final bool isSelected = _selectedPriority == p;
        Color iconColor;
        IconData icon;
        
        if (p == "High") {
          iconColor = const Color(0xFFFF5252);
          icon = Icons.error_rounded;
        } else if (p == "Medium") {
          iconColor = const Color(0xFFFFD700);
          icon = Icons.priority_high_rounded;
        } else {
          iconColor = const Color(0xFF4CAF50);
          icon = Icons.sync_rounded;
        }

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPriority = p),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E6D2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B7E74) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    p,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmailChip(String email) {
    return Chip(
      avatar: const CircleAvatar(child: Icon(Icons.person, size: 14)),
      label: Text(email, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: () => _removeEmail(email),
      backgroundColor: const Color(0xFFF1E6D2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
