import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DailyTaskList extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;

  const DailyTaskList({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DAILY TASK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'SEE ALL',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPlaceholder,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Task list with timeline
        ...List.generate(tasks.length, (index) {
          return _TaskItem(task: tasks[index]);
        }),
      ],
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;

  const _TaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final hasTime = (task['time'] as String).isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 48,
            child: hasTime
                ? Text(
                    task['time'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPlaceholder,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : const SizedBox(),
          ),

          // Timeline dots
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.timelineDot,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(width: 1, color: AppColors.timelineLine),
                ),
              ],
            ),
          ),

          // Checkbox
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.timelineDot, width: 1.5),
              ),
            ),
          ),

          // Task content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: task['priorityColor'] as Color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task['priority'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: task['priorityTextColor'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
