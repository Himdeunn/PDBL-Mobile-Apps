import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class WeekStrip extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;

  const WeekStrip({
    super.key,
    required this.selectedIndex,
    required this.onDaySelected,
  });

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  late List<DateTime> _weekDates;

  @override
  void initState() {
    super.initState();
    _weekDates = _getWeekDates();
  }

  // Get the 5 days of the current week (Monday to Friday)
  List<DateTime> _getWeekDates() {
    final now = DateTime.now();
    // Weekday: 1 = Monday, ..., 7 = Sunday
    // Find the Monday of the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Generate Mon-Fri (5 days)
    return List.generate(5, (index) => monday.add(Duration(days: index)));
  }

  String _formatDay(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_weekDates.length, (index) {
        final date = _weekDates[index];
        final isSelected = widget.selectedIndex == index;

        return GestureDetector(
          onTap: () => widget.onDaySelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _formatDay(date.weekday),
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white70
                        : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
