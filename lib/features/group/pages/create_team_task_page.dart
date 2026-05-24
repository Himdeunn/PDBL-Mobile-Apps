import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/native_text_input.dart';
import '../../../../core/theme/primary_button.dart';
import '../../../../core/utils/error_handler.dart';
import 'package:intl/intl.dart';
import '../../task/models/task_local.dart';
import '../../task/services/task_repository.dart';
import '../../task/widgets/priority_badge.dart';

class CreateTeamTaskPage extends StatefulWidget {
  final int teamId;
  final List<dynamic> members;
  final String userEmail;

  const CreateTeamTaskPage({
    super.key,
    required this.teamId,
    required this.members,
    required this.userEmail,
  });

  @override
  State<CreateTeamTaskPage> createState() => _CreateTeamTaskPageState();
}

class _CreateTeamTaskPageState extends State<CreateTeamTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _selectedMemberEmails = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedPriority = 'Medium';

  final TaskRepository _taskRepository = TaskRepository();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  void _toggleMember(String email) {
    setState(() {
      if (_selectedMemberEmails.contains(email)) {
        _selectedMemberEmails.remove(email);
      } else {
        _selectedMemberEmails.add(email);
      }
    });
  }

  Future<void> _handleCreate() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final task = TaskLocal();
      task.title = _titleController.text;
      task.description = _descriptionController.text;
      task.dueDate = _selectedDate;
      task.dueTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';
      task.priority = _selectedPriority.toLowerCase();
      task.userEmail = widget.userEmail;
      task.teamId = widget.teamId;

      await _taskRepository.createTeamTask(
        task,
        widget.userEmail,
        _selectedMemberEmails,
      );

      if (mounted) {
        ErrorHandler.showSuccessPopup('Task assigned successfully!');
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
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bottomScrollPadding = keyboardBottom > 0 ? keyboardBottom + 48 : 24.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: AppColors.textPrimary,
            size: 32,
          ),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Team Task',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomScrollPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Task Title *'),
                  _buildTextField(
                    _titleController,
                    'Enter task name...',
                    enabled: !_isSaving,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Assign To *'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.members.map((m) {
                        final email = m['email'] as String;
                        final isSelected = _selectedMemberEmails.contains(
                          email,
                        );
                        return FilterChip(
                          label: Text(m['name'] ?? email),
                          selected: isSelected,
                          onSelected: _isSaving
                              ? null
                              : (_) => _toggleMember(email),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.primary,
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Description (optional)'),
                  _buildTextField(
                    _descriptionController,
                    'Task details...',
                    enabled: !_isSaving,
                    maxLines: 5,
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
                                  : () async {
                                      final now = DateTime.now();
                                      final today = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );
                                      final fifteenYearsLater = DateTime(
                                        now.year + 15,
                                        now.month,
                                        now.day,
                                      );
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _selectedDate.isBefore(today)
                                            ? today
                                            : _selectedDate,
                                        firstDate: today,
                                        lastDate: fifteenYearsLater,
                                        builder: (ctx, child) => Theme(
                                          data: ThemeData.light().copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                                  primary: AppColors.primary,
                                                  onPrimary: Colors.white,
                                                  surface: AppColors.surface,
                                                  onSurface:
                                                      AppColors.textPrimary,
                                                ),
                                          ),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedDate = picked);
                                      }
                                    },
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
                                  : () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _selectedTime,
                                        builder:
                                            (
                                              BuildContext context,
                                              Widget? child,
                                            ) {
                                              return Theme(
                                                data: ThemeData.light().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                        primary:
                                                            AppColors.primary,
                                                        onPrimary: Colors.white,
                                                        surface:
                                                            AppColors.surface,
                                                        onSurface: AppColors
                                                            .textPrimary,
                                                      ),
                                                ),
                                                child: MediaQuery(
                                                  data: MediaQuery.of(context)
                                                      .copyWith(
                                                        alwaysUse24HourFormat:
                                                            true,
                                                      ),
                                                  child: child!,
                                                ),
                                              );
                                            },
                                      );
                                      if (picked != null) {
                                        final now = DateTime.now();
                                        final today = DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        );
                                        if (_selectedDate.year == today.year &&
                                            _selectedDate.month ==
                                                today.month &&
                                            _selectedDate.day == today.day) {
                                          if (picked.hour < now.hour ||
                                              (picked.hour == now.hour &&
                                                  picked.minute < now.minute)) {
                                            if (mounted) {
                                              ErrorHandler.showErrorPopup(
                                                'Time cannot be in the past',
                                              );
                                            }
                                            return;
                                          }
                                        }
                                        setState(() => _selectedTime = picked);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Priority *'),
                  _buildPriorityPicker(),
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
                          label: 'Add Task',
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

  Widget _buildPriorityPicker() {
    return Row(
      children: ["High", "Medium", "Low"].map((p) {
        final bool isSelected = _selectedPriority == p;
        return TaskPriorityOption(
          priority: p,
          isSelected: isSelected,
          onTap: _isSaving ? null : () => setState(() => _selectedPriority = p),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NativeTextInput(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines > 1 ? 3 : 1,
            enabled: enabled,
            height: maxLines > 1 ? 132 : 52,
            hintText: hint,
            backgroundColor: AppColors.surface,
            borderRadius: 16,
            onChanged: (v) => state.didChange(v),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
            fallbackBuilder: (context) => TextFormField(
              controller: controller,
              maxLines: maxLines,
              validator: validator,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hint,
                fillColor: AppColors.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => state.didChange(v),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Text(
                state.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
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
          color: AppColors.surface,
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
}
