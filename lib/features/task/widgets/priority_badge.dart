import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TaskPriorityStyle {
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  const TaskPriorityStyle({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });
}

class TaskPriorityVisuals {
  static const Color highColor = Color(0xFFE24B4A);
  static const Color mediumColor = Color(0xFFBA7517);
  static const Color lowColor = Color(0xFF3B6D11);
  static const Color fallbackColor = Color(0xFF8E8E93);

  static TaskPriorityStyle style(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return TaskPriorityStyle(
          label: 'High Priority',
          color: highColor,
          backgroundColor: highColor.withValues(alpha: 0.25),
          icon: Icons.error_rounded,
        );
      case 'medium':
        return TaskPriorityStyle(
          label: 'Medium',
          color: mediumColor,
          backgroundColor: mediumColor.withValues(alpha: 0.25),
          icon: Icons.warning_amber_rounded,
        );
      case 'low':
        return TaskPriorityStyle(
          label: 'Low',
          color: lowColor,
          backgroundColor: lowColor.withValues(alpha: 0.15),
          icon: Icons.low_priority_rounded,
        );
      default:
        return TaskPriorityStyle(
          label: priority,
          color: fallbackColor,
          backgroundColor: fallbackColor.withValues(alpha: 0.15),
          icon: Icons.circle_outlined,
        );
    }
  }
}

class TaskPriorityBadge extends StatelessWidget {
  final String priority;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const TaskPriorityBadge({
    super.key,
    required this.priority,
    this.iconSize = 12,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    final style = TaskPriorityVisuals.style(priority);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: iconSize, color: style.color),
          SizedBox(width: iconSize <= 12 ? 4 : 6),
          Text(
            style.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskPriorityOption extends StatelessWidget {
  final String priority;
  final bool isSelected;
  final VoidCallback? onTap;

  const TaskPriorityOption({
    super.key,
    required this.priority,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = TaskPriorityVisuals.style(priority);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? style.backgroundColor : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? style.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(style.icon, color: style.color, size: 28),
              const SizedBox(height: 8),
              Text(
                priority,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? style.color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
