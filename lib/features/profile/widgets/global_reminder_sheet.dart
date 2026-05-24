import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/native_text_input.dart';
import '../services/global_reminder_service.dart';

/// Bottom sheet untuk Add / Edit global reminder.
/// Returns [GlobalReminder] if user confirms, null if cancelled.
class GlobalReminderSheet extends StatefulWidget {
  final GlobalReminder? existing; // null = add mode

  const GlobalReminderSheet({super.key, this.existing});

  @override
  State<GlobalReminderSheet> createState() => _GlobalReminderSheetState();
}

class _GlobalReminderSheetState extends State<GlobalReminderSheet> {
  late ReminderTaskType _taskType;
  late ReminderTriggerMode _triggerMode;
  late int _hour;
  late int _minute;
  late int _intervalAmount;
  late String _intervalUnit;

  final _amountController = TextEditingController();

  static const List<String> _units = ['H', 'D', 'W'];
  static const Map<String, String> _unitLabels = {
    'H': 'Hour',
    'D': 'Day',
    'W': 'Week',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _taskType = e?.taskType ?? ReminderTaskType.all;
    _triggerMode = e?.triggerMode ?? ReminderTriggerMode.daily;
    _hour = e?.hour ?? 8;
    _minute = e?.minute ?? 0;
    _intervalAmount = e?.intervalAmount ?? 1;
    _intervalUnit = e?.intervalUnit ?? 'D';
    _amountController.text = _intervalAmount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _confirm() {
    final amount = int.tryParse(_amountController.text.trim()) ?? 1;
    final clamped = amount.clamp(1, 999);

    final reminder = GlobalReminder(
      id: widget.existing?.id ?? GlobalReminderService.generateId(),
      taskType: _taskType,
      triggerMode: _triggerMode,
      hour: _hour,
      minute: _minute,
      intervalAmount: clamped,
      intervalUnit: _intervalUnit,
      isEnabled: widget.existing?.isEnabled ?? true,
    );
    Navigator.pop(context, reminder);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final hStr = _hour.toString().padLeft(2, '0');
    final mStr = _minute.toString().padLeft(2, '0');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              isEdit ? 'Edit Reminder' : 'Add Global Reminder',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reminder will apply to all tasks, not just one task.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),

            // ── Task Type ───────────────────────────────────────────────────
            _sectionLabel('Applies to'),
            const SizedBox(height: 10),
            Row(
              children: ReminderTaskType.values.map((type) {
                final selected = _taskType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _taskType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              type.icon,
                              size: 20,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Trigger Mode ─────────────────────────────────────────────────
            _sectionLabel('Trigger Type'),
            const SizedBox(height: 10),
            Row(
              children: ReminderTriggerMode.values.map((mode) {
                final selected = _triggerMode == mode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _triggerMode = mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              mode == ReminderTriggerMode.daily
                                  ? Icons.alarm_outlined
                                  : Icons.timelapse_outlined,
                              size: 20,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Interval (only for beforeDeadline) ───────────────────────────
            if (_triggerMode == ReminderTriggerMode.beforeDeadline) ...[
              _sectionLabel('Interval'),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Amount input
                  SizedBox(
                    width: 72,
                    child: NativeTextInput(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      height: 44,
                      backgroundColor: AppColors.surface,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      fallbackBuilder: (context) => TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Unit selector — Expanded so buttons share remaining space evenly
                  ..._units.map((u) {
                    final sel = _intervalUnit == u;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _intervalUnit = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _unitLabels[u]!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ── Time picker ──────────────────────────────────────────────────
            _sectionLabel(
              _triggerMode == ReminderTriggerMode.daily
                  ? 'Notification Time'
                  : 'Notification Time (before deadline)',
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$hStr:$mStr',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Action buttons ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isEdit ? 'Save' : 'Add',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}
