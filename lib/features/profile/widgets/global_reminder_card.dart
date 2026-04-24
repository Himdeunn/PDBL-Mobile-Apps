import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/global_reminder_service.dart';

/// Card widget untuk menampilkan satu global reminder.
class GlobalReminderCard extends StatelessWidget {
  final GlobalReminder reminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const GlobalReminderCard({
    super.key,
    required this.reminder,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  Color get _accentColor {
    switch (reminder.taskType) {
      case ReminderTaskType.individual:
        return const Color(0xFF4A90D9);
      case ReminderTaskType.team:
        return const Color(0xFF27AE60);
      case ReminderTaskType.all:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final isEnabled = reminder.isEnabled;

    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? accent.withValues(alpha: 0.25)
                : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Icon badge ────────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reminder.triggerMode == ReminderTriggerMode.daily
                      ? Icons.alarm_outlined
                      : Icons.timelapse_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge + trigger label
                    Row(
                      children: [
                        _TypeBadge(type: reminder.taskType, accent: accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            reminder.triggerLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reminder.taskType.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Actions ───────────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Toggle
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      onChanged: onToggle,
                      activeThumbColor: accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  // Edit & Delete buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        color: AppColors.textTertiary,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.delete_outline,
                        color: Colors.red.shade300,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ReminderTaskType type;
  final Color accent;

  const _TypeBadge({required this.type, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: accent),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
