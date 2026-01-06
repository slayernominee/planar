import '../models/task.dart';

class RecurrenceLogic {
  /// Calculates the next occurrence date based on the recurrence type.
  static DateTime getNextDate(DateTime currentDate, RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return currentDate.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return currentDate.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        // Note: DateTime will handle overflow (e.g. Jan 31 -> Feb 28/29 or Mar 1/2)
        // automatically by spilling over into the next month if the day is invalid.
        return DateTime(nextYear, nextMonth, currentDate.day);
      case RecurrenceType.none:
      default:
        return currentDate;
    }
  }

  /// Generates a list of future dates based on the start date and recurrence type.
  ///
  /// Daily: 30 occurrences
  /// Weekly: 12 occurrences
  /// Monthly: 6 occurrences
  static List<DateTime> generateDates(DateTime startDate, RecurrenceType type) {
    List<DateTime> dates = [];
    int iterations = 0;

    switch (type) {
      case RecurrenceType.daily:
        iterations = 30;
        break;
      case RecurrenceType.weekly:
        iterations = 12;
        break;
      case RecurrenceType.monthly:
        iterations = 6;
        break;
      case RecurrenceType.none:
        return [];
    }

    DateTime currentDate = startDate;
    for (int i = 0; i < iterations; i++) {
      currentDate = getNextDate(currentDate, type);
      dates.add(currentDate);
    }

    return dates;
  }
}
