import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class WeekStrip extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<DateTime> onDaySelected;

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
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _weekDates = _getWeekDates();
    // 30 days back + today + 14 days forward = 45 days
    // Each item is 60 width + 12 separator = 72
    // We want to center today (index 30)
    final initialOffset = (30 * 72.0) - 20.0; // Subtract a bit of padding
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Get 45 days: 30 days before today, today, and 14 days after today
  List<DateTime> _getWeekDates() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    return List.generate(45, (index) => start.add(Duration(days: index)));
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
    return SizedBox(
      height: 90,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _weekDates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = widget.selectedIndex == index;

          return GestureDetector(
            onTap: () => widget.onDaySelected(date),
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
                mainAxisAlignment: MainAxisAlignment.center,
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
        },
      ),
    );
  }
}
