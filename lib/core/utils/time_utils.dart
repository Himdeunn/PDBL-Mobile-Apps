import 'package:intl/intl.dart';

class AppTimeUtils {
  /// Standardizes time display to 24-hour format (HH:mm).
  /// Handles formats like "HH:mm:ss", "HH:mm", "h:mm a", etc.
  static String formatTo24h(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--:--') {
      return '--:--';
    }

    try {
      // 1. If it contains AM/PM, parse it accordingly
      if (timeStr.toUpperCase().contains('AM') ||
          timeStr.toUpperCase().contains('PM')) {
        try {
          final date = DateFormat.jm().parse(timeStr);
          return DateFormat('HH:mm').format(date);
        } catch (e) {
          // If jm() fails (e.g. "13:00 AM"), strip the suffixes and continue to ":" parsing
          timeStr = timeStr
              .toUpperCase()
              .replaceAll('AM', '')
              .replaceAll('PM', '')
              .trim();
        }
      }

      // 2. If it is already in HH:mm:ss or HH:mm format
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final hour = parts[0].trim().padLeft(2, '0');
        final minute = parts.length > 1
            ? parts[1].trim().padLeft(2, '0')
            : '00';

        // Final validation to ensure they are numbers
        int.parse(hour);
        int.parse(minute);

        return '$hour:$minute';
      }

      return timeStr!;
    } catch (e) {
      return timeStr!; // Fallback to raw string if parsing fails
    }
  }

  /// Formats a DateTime object to 24-hour string (HH:mm).
  static String formatDateTimeTo24h(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  /// Extracts time from a deadline string (ISO8601) and formats to 24h.
  static String extractTimeFromDeadline(String? deadline) {
    if (deadline == null || deadline.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(deadline);
      return formatDateTimeTo24h(dt);
    } catch (e) {
      return '--:--';
    }
  }
}
