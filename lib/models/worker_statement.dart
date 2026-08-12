import 'advance.dart';
import 'attendance.dart';
import 'settlement.dart';
import 'worker.dart';

/// One worker's account for an arbitrary date range.
///
/// This is the shape behind the shareable statement — the *haazri parchi* a
/// contractor hands a worker. Deliberately not month-bound: a crew's questions
/// are "what about the 12th to the 26th", or "since Diwali", not "what about
/// calendar August".
class WorkerStatement {
  final Worker worker;
  final DateTime start;
  final DateTime end;

  /// Balance owed at the moment the period opens — everything earned before
  /// [start], less everything drawn and paid before it.
  final int broughtForward;

  final int fullDays;
  final int halfDays;
  final int absentDays;

  /// Day-equivalents: `fullDays + halfDays / 2`.
  final double daysWorked;

  /// `round(daysWorked × dailyWage)`.
  final int earned;

  /// Kharchi drawn inside the period.
  final int advancesTotal;

  /// Payments recorded inside the period.
  final int paid;

  /// `broughtForward + earned − advancesTotal − paid`. Negative means the
  /// worker has drawn more than they have earned.
  final int pending;

  /// Distinct daily rates that actually applied to worked days in the period,
  /// ascending. Usually one; more than one when the rate changed mid-period.
  final List<int> ratesApplied;

  /// Marked days inside the period, oldest first.
  final List<Attendance> attendance;

  /// Advances inside the period, oldest first.
  final List<Advance> advances;

  /// Settlements inside the period, oldest first.
  final List<Settlement> settlements;

  const WorkerStatement({
    required this.worker,
    required this.start,
    required this.end,
    required this.broughtForward,
    required this.fullDays,
    required this.halfDays,
    required this.absentDays,
    required this.daysWorked,
    required this.earned,
    required this.advancesTotal,
    required this.paid,
    required this.pending,
    this.ratesApplied = const [],
    required this.attendance,
    required this.advances,
    required this.settlements,
  });

  /// Days in the period with no mark at all — neither worked nor recorded
  /// absent. Distinguishing these matters: silence is not the same as absence,
  /// and conflating them is what starts wage arguments.
  int get unmarkedDays {
    final span = end.difference(start).inDays + 1;
    final marked = fullDays + halfDays + absentDays;
    return span - marked < 0 ? 0 : span - marked;
  }
}
