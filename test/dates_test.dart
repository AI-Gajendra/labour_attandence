import 'package:flutter_test/flutter_test.dart';
import 'package:labour_attendance/utils/dates.dart';

void main() {
  group('keys', () {
    test('dateKey zero-pads', () {
      expect(dateKey(DateTime(2026, 8, 11)), '2026-08-11');
      expect(dateKey(DateTime(2026, 1, 1)), '2026-01-01');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('monthKey zero-pads', () {
      expect(monthKey(DateTime(2026, 8, 11)), '2026-08');
      expect(monthKey(DateTime(2026, 1, 31)), '2026-01');
    });

    test('monthKeyOfDateKey slices the month out', () {
      expect(monthKeyOfDateKey('2026-08-11'), '2026-08');
      expect(monthKeyOfDateKey('short'), 'short');
    });
  });

  group('parsing', () {
    test('parses well-formed keys', () {
      expect(parseDateKey('2026-08-11'), DateTime(2026, 8, 11));
      expect(parseMonthKey('2026-08'), DateTime(2026, 8));
    });

    test('returns null rather than throwing on junk', () {
      // Firestore documents are not schema-enforced; one bad row must not take
      // down a whole screen.
      expect(parseDateKey(''), isNull);
      expect(parseDateKey('2026-08'), isNull);
      expect(parseDateKey('not-a-date'), isNull);
      expect(parseDateKey('2026-13-01'), isNull);
      expect(parseDateKey('2026-08-99'), isNull);
      expect(parseMonthKey('2026'), isNull);
    });

    test('dayOfDateKey extracts the day', () {
      expect(dayOfDateKey('2026-08-11'), 11);
      expect(dayOfDateKey('rubbish'), isNull);
    });
  });

  group('arithmetic', () {
    test('previousMonthKey crosses the year boundary', () {
      expect(previousMonthKey('2026-08'), '2026-07');
      expect(previousMonthKey('2026-01'), '2025-12');
      expect(previousMonthKey('nonsense'), 'nonsense');
    });

    test('addMonths wraps correctly', () {
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
    });

    test('daysInMonth handles February and leap years', () {
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2024, 2)), 29);
      expect(daysInMonth(DateTime(2026, 8)), 31);
      expect(daysInMonth(DateTime(2026, 4)), 30);
    });

    test('isSameDay ignores the time component', () {
      expect(
        isSameDay(DateTime(2026, 8, 11, 9), DateTime(2026, 8, 11, 23)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 8, 11), DateTime(2026, 8, 12)), isFalse);
    });
  });

  group('display', () {
    test('formats dates for the UI', () {
      // 11 Aug 2026 is a Tuesday.
      expect(displayFullDate(DateTime(2026, 8, 11)), 'TUESDAY, AUG 11, 2026');
      expect(displayMonthLong(DateTime(2026, 8)), 'August 2026');
      expect(displayDayMonth(DateTime(2026, 8, 11)), '11 AUG 2026');
      expect(displayDateKey('2026-08-11'), '11 AUG 2026');
      expect(displayDateKey('broken'), 'broken');
      expect(
        displayTimestamp(DateTime(2026, 8, 11, 14, 5)),
        '11 Aug 2026, 14:05',
      );
    });
  });
}
