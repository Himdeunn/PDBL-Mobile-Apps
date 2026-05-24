import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../task/widgets/priority_badge.dart';

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
            border: Border.all(
              color: const Color(0xFF2D2438).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag + avatar row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TaskPriorityBadge(
                    priority: tag,
                    iconSize: 14,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
}
