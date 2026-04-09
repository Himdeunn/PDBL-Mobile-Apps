import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FocusCard extends StatelessWidget {
  final String tag;
  final String title;
  final String description;
  final String timeRange;

  const FocusCard({
    super.key,
    required this.tag,
    required this.title,
    required this.description,
    required this.timeRange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Focus',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFEADBC8).withValues(alpha: 0.75),
                const Color(0xFF2F2235).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag + avatar row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityBgColor(tag),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPriorityIcon(tag),
                          size: 14,
                          color: _getPriorityColor(tag),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPriorityLabel(tag),
                          style: TextStyle(
                            color: _getPriorityColor(tag),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Time
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF0000); // Pure Red
      case 'medium':
        return const Color(0xFFA49C00); // Dark Olive (Text)
      case 'low':
        return const Color(0xFF16A34A); // Forest Green
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Color _getPriorityBgColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'medium':
        return const Color(0xFFD4EA0C).withValues(alpha: 0.15); // Lime/Yellow Tint
      default:
        return _getPriorityColor(priority).withValues(alpha: 0.15);
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return priority;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.priority_high;
      case 'low':
        return Icons.low_priority;
      default:
        return Icons.info_outline;
    }
  }
}
