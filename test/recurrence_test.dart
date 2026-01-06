import 'package:flutter_test/flutter_test.dart';
import 'package:planar/models/task.dart';
import 'package:planar/utils/recurrence_logic.dart';

void main() {
  group('RecurrenceLogic Tests', () {
    test('Daily recurrence adds 1 day', () {
      final date = DateTime(2023, 1, 1);
      final next = RecurrenceLogic.getNextDate(date, RecurrenceType.daily);
      expect(next, DateTime(2023, 1, 2));
    });

    test('Weekly recurrence adds 7 days', () {
      final date = DateTime(2023, 1, 1);
      final next = RecurrenceLogic.getNextDate(date, RecurrenceType.weekly);
      expect(next, DateTime(2023, 1, 8));
    });

    test('Monthly recurrence adds 1 month', () {
      final date = DateTime(2023, 1, 15);
      final next = RecurrenceLogic.getNextDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2023, 2, 15));
    });

    test('Monthly recurrence handles year rollover', () {
      final date = DateTime(2023, 12, 15);
      final next = RecurrenceLogic.getNextDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2024, 1, 15));
    });

    test('Monthly recurrence handles month overflow logic (Dart default)', () {
      // Jan 31 -> Feb 31
      // In 2023 (non-leap), Feb has 28 days.
      // DateTime(2023, 2, 31) normalizes to March 3rd.
      final date = DateTime(2023, 1, 31);
      final next = RecurrenceLogic.getNextDate(date, RecurrenceType.monthly);
      expect(next, DateTime(2023, 3, 3));
    });

    test('Generates correct number of daily tasks', () {
      final date = DateTime(2023, 1, 1);
      final dates = RecurrenceLogic.generateDates(date, RecurrenceType.daily);
      expect(dates.length, 30);
      expect(dates.first, DateTime(2023, 1, 2));
      expect(dates.last, DateTime(2023, 1, 31));
    });

    test('Generates correct number of weekly tasks', () {
      final date = DateTime(2023, 1, 1);
      final dates = RecurrenceLogic.generateDates(date, RecurrenceType.weekly);
      expect(dates.length, 12);
      expect(dates.first, DateTime(2023, 1, 8));
      expect(dates.last, DateTime(2023, 3, 26));
    });

    test('Generates correct number of monthly tasks', () {
      final date = DateTime(2023, 1, 1);
      final dates = RecurrenceLogic.generateDates(date, RecurrenceType.monthly);
      expect(dates.length, 6);
      expect(dates.first, DateTime(2023, 2, 1));
      expect(dates.last, DateTime(2023, 7, 1));
    });

    test('None recurrence returns original date / empty list', () {
      final date = DateTime(2023, 1, 1);
      expect(RecurrenceLogic.getNextDate(date, RecurrenceType.none), date);
      expect(RecurrenceLogic.generateDates(date, RecurrenceType.none), isEmpty);
    });
  });
}
