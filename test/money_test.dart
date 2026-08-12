import 'package:flutter_test/flutter_test.dart';
import 'package:labour_attendance/utils/money.dart';

void main() {
  group('asRupees', () {
    test('passes ints through', () {
      expect(asRupees(650), 650);
      expect(asRupees(0), 0);
      expect(asRupees(-500), -500);
    });

    test('rounds doubles — legacy documents were written as doubles', () {
      expect(asRupees(650.0), 650);
      expect(asRupees(650.4), 650);
      expect(asRupees(650.5), 651);
    });

    test('parses numeric strings', () {
      expect(asRupees('750'), 750);
      expect(asRupees(' 750 '), 750);
      expect(asRupees('750.6'), 751);
    });

    test('never throws on malformed data', () {
      expect(asRupees(null), 0);
      expect(asRupees('abc'), 0);
      expect(asRupees(<String, dynamic>{}), 0);
      expect(asRupees(double.nan), 0);
      expect(asRupees(double.infinity), 0);
    });
  });

  group('asDays', () {
    test('reads whole and half days', () {
      expect(asDays(1), 1.0);
      expect(asDays(0.5), 0.5);
      expect(asDays('2.5'), 2.5);
    });

    test('defaults to zero on junk', () {
      expect(asDays(null), 0);
      expect(asDays('x'), 0);
      expect(asDays(double.nan), 0);
    });
  });

  group('roundRupees', () {
    test('rounds half away from zero', () {
      expect(roundRupees(1637.5), 1638);
      expect(roundRupees(1637.4), 1637);
      expect(roundRupees(-1637.5), -1638);
    });

    test('handles a half day at an odd wage', () {
      // 2.5 days at ₹655 = ₹1637.50
      expect(roundRupees(2.5 * 655), 1638);
    });

    test('survives non-finite input', () {
      expect(roundRupees(double.nan), 0);
      expect(roundRupees(double.infinity), 0);
    });
  });

  group('groupIndian', () {
    test('groups by Indian convention, not thousands', () {
      expect(groupIndian(0), '0');
      expect(groupIndian(999), '999');
      expect(groupIndian(1000), '1,000');
      expect(groupIndian(100000), '1,00,000');
      expect(groupIndian(1000000), '10,00,000');
      expect(groupIndian(12345678), '1,23,45,678');
    });

    test('handles negatives', () {
      expect(groupIndian(-100000), '-1,00,000');
      expect(groupIndian(-500), '-500');
    });
  });

  group('rupees', () {
    test('formats with the sign outside the rupee symbol', () {
      expect(rupees(1500), '₹1,500');
      expect(rupees(100000), '₹1,00,000');
      expect(rupees(-2000), '-₹2,000');
      expect(rupees(0), '₹0');
    });
  });

  group('formatDays', () {
    test('trims whole days and keeps halves', () {
      expect(formatDays(22), '22');
      expect(formatDays(22.0), '22');
      expect(formatDays(22.5), '22.5');
      expect(formatDays(0), '0');
    });
  });
}
