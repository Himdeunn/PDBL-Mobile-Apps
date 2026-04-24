import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/reminder_service.dart';

class ReminderPickerSheet extends StatefulWidget {
  final DateTime taskDeadline;

  const ReminderPickerSheet({super.key, required this.taskDeadline});

  @override
  State<ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<ReminderPickerSheet> {
  String _unit = 'D';
  int _hour = 8;
  int _minute = 0;

  final _amountController = TextEditingController(text: '1');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _maxAmount {
    return switch (_unit) {
      'D' => 365,
      'W' => 52,
      'M' => 12,
      'Y' => 5,
      _ => 365,
    };
  }

  String get _unitLabel => switch (_unit) {
        'D' => 'Days',
        'W' => 'Weeks',
        'M' => 'Months',
        'Y' => 'Years',
        _ => _unit,
      };

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
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
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0 || amount > _maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount must be between 1 and $_maxAmount $_unitLabel.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminder = TaskReminder(
      unit: _unit,
      amount: amount,
      hour: _hour,
      minute: _minute,
    );

    // Validate that the reminder fires before the deadline
    final fireDate = widget.taskDeadline.subtract(reminder.duration);
    final fire = DateTime(
        fireDate.year, fireDate.month, fireDate.day, _hour, _minute);

    if (!fire.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This reminder would fire in the past. Choose a different time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context, reminder);
  }

  @override
  Widget build(BuildContext context) {
    final h = _hour.toString().padLeft(2, '0');
    final m = _minute.toString().padLeft(2, '0');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Unit selector
          const Text(
            'Remind me',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['D', 'W', 'M', 'Y'].map((u) {
              final label = switch (u) {
                'D' => 'Days',
                'W' => 'Weeks',
                'M' => 'Months',
                'Y' => 'Years',
                _ => u,
              };
              final selected = _unit == u;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _unit = u;
                      final cur = int.tryParse(_amountController.text) ?? 1;
                      _amountController.text = cur.clamp(1, _maxAmount).toString();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Amount input
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_unitLabel before deadline (1–$_maxAmount)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        fillColor: AppColors.surface,
                        filled: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reminder time',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 18, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Text(
                            '$h:$m',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Add Reminder',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
