import 'package:flutter_test/flutter_test.dart';
import 'package:labour_attendance/models/advance.dart';
import 'package:labour_attendance/models/attendance.dart';
import 'package:labour_attendance/models/settlement.dart';
import 'package:labour_attendance/models/worker.dart';
import 'package:labour_attendance/utils/payroll.dart';

Worker worker(
  String id, {
  int wage = 600,
  String name = 'Test',
  List<WageRate> wageHistory = const [],
}) => Worker(
  workerId: id,
  name: name,
  type: 'Helper',
  dailyWage: wage,
  createdBy: 'test',
  createdAt: DateTime(2026, 1, 1),
  wageHistory: wageHistory,
);

/// A worker whose rate went from [oldWage] to [newWage] starting [from].
/// Mirrors exactly what `FirestoreService.updateWorker` writes.
Worker raised(
  String id, {
  required int oldWage,
  required int newWage,
  required String from,
}) => worker(
  id,
  wage: newWage,
  wageHistory: [
    WageRate(from: from, wage: newWage),
    WageRate(from: WageRate.beginning, wage: oldWage),
  ],
);

/// [date] is a full `YYYY-MM-DD` key; the month is derived from it.
Attendance mark(String workerId, String date, String status) => Attendance(
  attendanceId: '${workerId}_$date',
  workerId: workerId,
  date: date,
  month: date.substring(0, 7),
  status: status,
  createdBy: 'test',
);

Advance advance(String workerId, int amount, String date) => Advance(
  advanceId: '$workerId-$date-$amount',
  workerId: workerId,
  amount: amount,
  date: date,
  month: date.substring(0, 7),
  createdBy: 'test',
);

Settlement settlement(
  String workerId, {
  required String month,
  int opening = 0,
  int salary = 0,
  int advances = 0,
  required int paid,
  int? closing,
}) => Settlement(
  settlementId: Settlement.idFor(workerId, month),
  workerId: workerId,
  month: month,
  opening: opening,
  salary: salary,
  advances: advances,
  paid: paid,
  closing: closing ?? (opening + salary - advances - paid),
  mode: Settlement.modeCash,
  note: '',
  createdBy: 'test',
  settledAt: DateTime(2026, 8, 31),
);

void main() {
  group('day values', () {
    test('present = 1, half = 0.5, absent = 0, unmarked = nothing', () {
      expect(AttendanceStatus.dayValue(AttendanceStatus.present), 1.0);
      expect(AttendanceStatus.dayValue(AttendanceStatus.halfDay), 0.5);
      expect(AttendanceStatus.dayValue(AttendanceStatus.absent), 0.0);
      expect(AttendanceStatus.dayValue(null), 0.0);
      expect(AttendanceStatus.dayValue('something_else'), 0.0);
    });
  });

  group('computeMonthlyRows', () {
    test('salary is days × wage', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1', wage: 600)],
        attendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
          mark('w1', '2026-08-03', AttendanceStatus.halfDay),
          mark('w1', '2026-08-04', AttendanceStatus.absent),
        ],
        advances: const [],
        settlements: const [],
        opening: const {},
      );

      expect(rows.single.days, 2.5);
      expect(rows.single.salary, 1500); // 2.5 × 600
      expect(rows.single.balance, 1500);
    });

    test('a half day at an odd wage rounds to whole rupees', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1', wage: 655)],
        attendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
          mark('w1', '2026-08-03', AttendanceStatus.halfDay),
        ],
        advances: const [],
        settlements: const [],
        opening: const {},
      );

      // 2.5 × 655 = 1637.50 → 1638
      expect(rows.single.salary, 1638);
    });

    test('advances are subtracted and can push the balance negative', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1', wage: 500)],
        attendance: [mark('w1', '2026-08-01', AttendanceStatus.present)],
        advances: [
          advance('w1', 1000, '2026-08-05'),
          advance('w1', 500, '2026-08-06'),
        ],
        settlements: const [],
        opening: const {},
      );

      expect(rows.single.salary, 500);
      expect(rows.single.advances, 1500);
      expect(rows.single.balance, -1000);
    });

    test('a worker with no records shows zeros rather than being dropped', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1'), worker('w2')],
        attendance: [mark('w1', '2026-08-01', AttendanceStatus.present)],
        advances: const [],
        settlements: const [],
        opening: const {},
      );

      expect(rows.length, 2);
      final w2 = rows.firstWhere((r) => r.worker.workerId == 'w2');
      expect(w2.days, 0);
      expect(w2.balance, 0);
      expect(w2.isSettled, isFalse);
    });

    test('records for unknown workers do not create phantom rows', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1')],
        attendance: [mark('ghost', '2026-08-01', AttendanceStatus.present)],
        advances: [advance('ghost', 500, '2026-08-05')],
        settlements: const [],
        opening: const {},
      );

      expect(rows.length, 1);
      expect(rows.single.worker.workerId, 'w1');
      expect(rows.single.days, 0);
    });

    test('opening is added and a payment marks the row settled', () {
      final rows = computeMonthlyRows(
        workers: [worker('w1', wage: 500)],
        attendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
        ],
        advances: [advance('w1', 200, '2026-08-05')],
        settlements: [settlement('w1', month: '2026-08', paid: 800)],
        opening: const {'w1': 0},
      );

      final row = rows.single;
      expect(row.salary, 1000);
      expect(row.paid, 800);
      expect(row.balance, 0);
      expect(row.isSettled, isTrue);
    });
  });

  group('openingBalances — carry-forward across every past month', () {
    // The regression this guards: opening used to read only the *previous
    // month's settlement*. Months nobody had settled contributed nothing, so a
    // worker owed for July started August at zero and the debt disappeared.
    test('an unsettled past month still carries its balance forward', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 600)],
        priorAttendance: [
          mark('w1', '2026-07-01', AttendanceStatus.present),
          mark('w1', '2026-07-02', AttendanceStatus.present),
          mark('w1', '2026-07-03', AttendanceStatus.present),
        ],
        priorAdvances: const [],
        priorSettlements: const [], // never settled
      );

      expect(opening['w1'], 1800);
    });

    test('several unsettled months accumulate', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 500)],
        priorAttendance: [
          mark('w1', '2026-05-01', AttendanceStatus.present),
          mark('w1', '2026-06-01', AttendanceStatus.present),
          mark('w1', '2026-07-01', AttendanceStatus.halfDay),
        ],
        priorAdvances: [advance('w1', 300, '2026-06-10')],
        priorSettlements: const [],
      );

      // 500 + 500 + 250 − 300
      expect(opening['w1'], 950);
    });

    test('an over-drawn past month carries a negative balance', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 500)],
        priorAttendance: [mark('w1', '2026-07-01', AttendanceStatus.present)],
        priorAdvances: [advance('w1', 2500, '2026-07-02')],
        priorSettlements: const [],
      );

      expect(opening['w1'], -2000);
    });

    test('a settled month uses its recorded figures, not a recomputation', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 900)], // wage was raised since
        priorAttendance: [
          mark('w1', '2026-07-01', AttendanceStatus.present),
          mark('w1', '2026-07-02', AttendanceStatus.present),
        ],
        priorAdvances: const [],
        priorSettlements: [
          // Settled at the old ₹500 rate: earned 1000, paid 400.
          settlement('w1', month: '2026-07', salary: 1000, paid: 400),
        ],
      );

      // 1000 − 400 = 600, NOT 2 × 900.
      expect(opening['w1'], 600);
    });

    test('settled and unsettled months combine without double-counting', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 500)],
        priorAttendance: [
          mark('w1', '2026-06-01', AttendanceStatus.present), // settled month
          mark('w1', '2026-07-01', AttendanceStatus.present), // unsettled
          mark('w1', '2026-07-02', AttendanceStatus.present),
        ],
        priorAdvances: [
          advance('w1', 100, '2026-06-05'), // inside the settled month
          advance('w1', 200, '2026-07-05'), // unsettled
        ],
        priorSettlements: [
          settlement(
            'w1',
            month: '2026-06',
            salary: 500,
            advances: 100,
            paid: 400,
          ),
        ],
      );

      // June (settled): 500 − 100 − 400 = 0
      // July (raw):     1000 − 200      = 800
      expect(opening['w1'], 800);
    });

    test('workers with no history are simply absent from the map', () {
      final opening = openingBalances(
        workers: [worker('w1'), worker('w2')],
        priorAttendance: [mark('w1', '2026-07-01', AttendanceStatus.present)],
        priorAdvances: const [],
        priorSettlements: const [],
      );

      expect(opening['w2'], isNull);
      expect(opening['w1'], 600);
    });

    test('feeds computeMonthlyRows end to end', () {
      final opening = openingBalances(
        workers: [worker('w1', wage: 500)],
        priorAttendance: [mark('w1', '2026-07-01', AttendanceStatus.present)],
        priorAdvances: [advance('w1', 2500, '2026-07-02')],
        priorSettlements: const [],
      );

      final rows = computeMonthlyRows(
        workers: [worker('w1', wage: 500)],
        attendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
        ],
        advances: const [],
        settlements: const [],
        opening: opening,
      );

      // Carried −2000, earned 1000 → still 1000 owing to the contractor.
      expect(rows.single.opening, -2000);
      expect(rows.single.balance, -1000);
    });
  });

  group('buildWorkerStatement', () {
    final w = worker('w1', wage: 600, name: 'Ramesh');

    test('counts each status and totals only the selected range', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 20),
        allAttendance: [
          mark('w1', '2026-08-09', AttendanceStatus.present), // before
          mark('w1', '2026-08-10', AttendanceStatus.present),
          mark('w1', '2026-08-11', AttendanceStatus.halfDay),
          mark('w1', '2026-08-12', AttendanceStatus.absent),
          mark('w1', '2026-08-20', AttendanceStatus.present),
          mark('w1', '2026-08-21', AttendanceStatus.present), // after
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.fullDays, 2);
      expect(s.halfDays, 1);
      expect(s.absentDays, 1);
      expect(s.daysWorked, 2.5);
      expect(s.earned, 1500);
      expect(s.attendance.length, 4);
    });

    test('boundary dates are inclusive at both ends', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 12),
        allAttendance: [
          mark('w1', '2026-08-10', AttendanceStatus.present),
          mark('w1', '2026-08-12', AttendanceStatus.present),
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.fullDays, 2);
    });

    test('brought forward is everything before the start date', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 20),
        allAttendance: [
          mark('w1', '2026-07-01', AttendanceStatus.present), // 600
          mark('w1', '2026-08-01', AttendanceStatus.present), // 600
          mark('w1', '2026-08-15', AttendanceStatus.present), // in range
        ],
        allAdvances: [advance('w1', 200, '2026-07-05')], // before
        allSettlements: const [],
      );

      expect(s.broughtForward, 1000); // 600 + 600 − 200
      expect(s.earned, 600);
      expect(s.pending, 1600);
    });

    test('advances inside the range are listed, dated and totalled', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        allAttendance: [mark('w1', '2026-08-05', AttendanceStatus.present)],
        allAdvances: [
          advance('w1', 500, '2026-08-03'),
          advance('w1', 300, '2026-08-20'),
          advance('w1', 900, '2026-09-01'), // outside
        ],
        allSettlements: const [],
      );

      expect(s.advances.length, 2);
      expect(s.advancesTotal, 800);
      expect(s.advances.first.date, '2026-08-03'); // sorted oldest first
      expect(s.pending, 600 - 800);
    });

    test('back-dated attendance entered late still counts', () {
      // A worker joins on the 1st but is only added to the app on the 5th, and
      // the first four days are marked retrospectively. The statement must
      // include them regardless of when they were typed in.
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 5),
        allAttendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
          mark('w1', '2026-08-03', AttendanceStatus.present),
          mark('w1', '2026-08-04', AttendanceStatus.present),
          mark('w1', '2026-08-05', AttendanceStatus.present),
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.fullDays, 5);
      expect(s.earned, 3000);
      expect(s.broughtForward, 0);
    });

    test('payments reduce pending', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        allAttendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
        ],
        allAdvances: const [],
        allSettlements: [settlement('w1', month: '2026-08', paid: 500)],
      );

      expect(s.earned, 1200);
      expect(s.paid, 500);
      expect(s.pending, 700);
    });

    test('unmarked days are distinguished from absences', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 10), // 10-day span
        allAttendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.absent),
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.absentDays, 1);
      expect(s.unmarkedDays, 8);
    });

    test('an empty period produces zeros, not an error', () {
      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        allAttendance: const [],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.daysWorked, 0);
      expect(s.earned, 0);
      expect(s.pending, 0);
    });
  });

  group('wage history — a raise must not re-price past work', () {
    test('wageOn returns the rate in force on each day', () {
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-01');

      expect(w.wageOn('2026-07-31'), 600);
      expect(w.wageOn('2026-08-01'), 650); // inclusive from the effective day
      expect(w.wageOn('2026-08-15'), 650);
      expect(w.wageOn('2026-12-31'), 650);
      expect(w.dailyWage, 650); // current rate, for display
    });

    test('a worker with no history prices every day at the current rate', () {
      final w = worker('w1', wage: 600);
      expect(w.wageOn('2020-01-01'), 600);
      expect(w.wageOn('2026-08-15'), 600);
    });

    test('July stays at the old rate when August is raised', () {
      // Jagdish: ₹600 → ₹650 effective August. July's five days must still be
      // worth ₹3,000, not ₹3,250.
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-01');

      final july = openingBalances(
        workers: [w],
        priorAttendance: [
          mark('w1', '2026-07-01', AttendanceStatus.present),
          mark('w1', '2026-07-02', AttendanceStatus.present),
          mark('w1', '2026-07-03', AttendanceStatus.present),
          mark('w1', '2026-07-04', AttendanceStatus.present),
          mark('w1', '2026-07-05', AttendanceStatus.present),
        ],
        priorAdvances: const [],
        priorSettlements: const [],
      );

      expect(july['w1'], 3000, reason: '5 × ₹600, not 5 × ₹650');
    });

    test('August is charged at the new rate in the same computation', () {
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-01');

      final rows = computeMonthlyRows(
        workers: [w],
        attendance: [
          mark('w1', '2026-08-01', AttendanceStatus.present),
          mark('w1', '2026-08-02', AttendanceStatus.present),
        ],
        advances: const [],
        settlements: const [],
        opening: openingBalances(
          workers: [w],
          priorAttendance: [mark('w1', '2026-07-01', AttendanceStatus.present)],
          priorAdvances: const [],
          priorSettlements: const [],
        ),
      );

      expect(rows.single.opening, 600); // July at the old rate
      expect(rows.single.salary, 1300); // August at the new rate
      expect(rows.single.balance, 1900);
    });

    test('a mid-month change splits the month across both rates', () {
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-15');

      final rows = computeMonthlyRows(
        workers: [w],
        attendance: [
          mark('w1', '2026-08-14', AttendanceStatus.present), // 600
          mark('w1', '2026-08-15', AttendanceStatus.present), // 650
          mark('w1', '2026-08-16', AttendanceStatus.halfDay), // 325
        ],
        advances: const [],
        settlements: const [],
        opening: const {},
      );

      expect(rows.single.days, 2.5);
      expect(rows.single.salary, 1575); // 600 + 650 + 325
    });

    test('"correct a mistake" history re-prices everything, by design', () {
      // A single all-time entry is what updateWorker writes when the user says
      // the rate was always this.
      final w = worker(
        'w1',
        wage: 650,
        wageHistory: [const WageRate(from: WageRate.beginning, wage: 650)],
      );

      final july = openingBalances(
        workers: [w],
        priorAttendance: [mark('w1', '2026-07-01', AttendanceStatus.present)],
        priorAdvances: const [],
        priorSettlements: const [],
      );

      expect(july['w1'], 650);
    });

    test('a statement prices each day at its own rate', () {
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-01');

      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 31),
        allAttendance: [
          mark('w1', '2026-07-10', AttendanceStatus.present), // 600
          mark('w1', '2026-08-10', AttendanceStatus.present), // 650
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.earned, 1250);
      expect(s.ratesApplied, [600, 650]);
    });

    test('a statement over one rate reports a single rate', () {
      final w = raised('w1', oldWage: 600, newWage: 650, from: '2026-08-01');

      final s = buildWorkerStatement(
        worker: w,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        allAttendance: [
          mark('w1', '2026-07-10', AttendanceStatus.present), // brought forward
          mark('w1', '2026-08-10', AttendanceStatus.present),
        ],
        allAdvances: const [],
        allSettlements: const [],
      );

      expect(s.broughtForward, 600, reason: 'July priced at the July rate');
      expect(s.earned, 650);
      expect(s.ratesApplied, [650]);
    });
  });

  group('closingBalance', () {
    test('is opening + salary - advances - paid', () {
      expect(
        closingBalance(opening: 0, salary: 1000, advances: 200, paid: 800),
        0,
      );
      expect(
        closingBalance(opening: -2000, salary: 1000, advances: 0, paid: 0),
        -1000,
      );
    });
  });
}
