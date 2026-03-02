import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // DateTime.weekday: Mon=1 ... Sun=7. Map to Sun=0 ... Sat=6.
    int firstWeekday = firstDayOfMonth.weekday == 7
        ? 0
        : firstDayOfMonth.weekday;

    final days = <DateTime>[];

    // Previous month days
    for (int i = firstWeekday - 1; i >= 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i + 1)));
    }

    // Current month days
    for (int i = 0; i < lastDayOfMonth.day; i++) {
      days.add(firstDayOfMonth.add(Duration(days: i)));
    }

    // Next month days to complete a 6-week grid (42 cells) to keep height consistent
    while (days.length < 42) {
      days.add(days.last.add(const Duration(days: 1)));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildHeader(),
          const SizedBox(height: 24),
          _buildWeekDays(),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
          const SizedBox(height: 16),
          Expanded(child: _buildTodoList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(Icons.chevron_left_rounded, _previousMonth),
          Column(
            children: [
              Text(
                _monthNames[_currentMonth.month - 1],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          _buildNavButton(Icons.chevron_right_rounded, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppColors.calendarBorder, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }

  Widget _buildWeekDays() {
    const days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days
            .map(
              (day) => SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final days = _getDaysInMonth(_currentMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          // Using childAspectRatio to keep the height tight since we removed the double dots
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final date = days[index];
          final isCurrentMonth = date.month == _currentMonth.month;
          final isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                // If user taps a date in previous/next month, jump to that month
                if (!isCurrentMonth) {
                  _currentMonth = DateTime(date.year, date.month, 1);
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.calendarSelected
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: !isCurrentMonth
                        ? AppColors.calendarOtherMonth
                        : isSelected
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodoList() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notification / To do list',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.calendarSelected,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: AppColors.calendarEmptyIcon,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tasks on this date.',
                    style: TextStyle(
                      color: AppColors.calendarEmptyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
