import 'advance.dart';
import 'attendance.dart';
import 'worker.dart';

/// One worker's payroll position for one month.
class MonthlyRow {
  final Worker worker;

  /// Day-equivalents worked (half days count 0.5).
  final double days;

  /// Balance carried in from the previous month's settlement.
  final int opening;

  /// `days × dailyWage`, rounded to whole rupees.
  final int salary;

  /// Kharchi drawn this month.
  final int advances;

  /// Already paid out for this month, if it has been settled.
  final int paid;

  /// `opening + salary − advances − paid`.
  final int balance;

  final bool isSettled;
  final List<Attendance> records;
  final List<Advance> advanceRecords;

  const MonthlyRow({
    required this.worker,
    required this.days,
    required this.opening,
    required this.salary,
    required this.advances,
    required this.paid,
    required this.balance,
    required this.isSettled,
    required this.records,
    required this.advanceRecords,
  });
}
