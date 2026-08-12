import '../models/advance.dart';
import '../models/attendance.dart';
import '../models/monthly_row.dart';
import '../models/settlement.dart';
import '../models/worker.dart';
import '../models/worker_statement.dart';
import 'dates.dart';
import 'money.dart';

/// Net movement for one worker in one month: what the month added to (or took
/// from) the running balance, before any carry-in.
int monthlyNet({
  required int salary,
  required int advances,
  required int paid,
}) => salary - advances - paid;

/// Balance owed to each worker for **every month before [beforeMonth]**, keyed
/// by workerId. Missing worker = zero.
///
/// ## Why this is a full walk and not just "last month's settlement"
///
/// The first version read `opening` from the previous month's settlement alone.
/// Settlements only exist once someone taps RECORD PAYMENT, so any month that
/// was never settled contributed **nothing** — a worker owed ₹4,200 for July
/// started August at zero and the debt disappeared. Contractors do not settle
/// every month on the nose, so that was a live way to lose money.
///
/// Each prior month contributes its net:
/// * **settled** months use the figures recorded at settlement time — that is
///   what settling means, and it pins the wage that was actually agreed;
/// * **unsettled** months are computed from attendance and advances.
///
/// Because a settled month is taken as a checkpoint, back-dating attendance
/// into one will **not** change the balance — reopen the month first. Attendance
/// back-dated into an *unsettled* month is picked up automatically, which is the
/// common case when a worker is added to the app a few days after joining.
///
/// Unsettled months are priced day by day through [Worker.wageOn], so a rate
/// change made today does not reach back and re-price work already done.
Map<String, int> openingBalances({
  required List<Worker> workers,
  required List<Attendance> priorAttendance,
  required List<Advance> priorAdvances,
  required List<Settlement> priorSettlements,
}) {
  final workerById = {for (final w in workers) w.workerId: w};
  final totals = <String, int>{};

  void add(String workerId, int amount) => totals.update(
    workerId,
    (value) => value + amount,
    ifAbsent: () => amount,
  );

  // Settled months contribute their recorded net, and mark themselves handled
  // so the raw records below don't double-count them.
  final settled = <String>{};
  for (final s in priorSettlements) {
    settled.add('${s.workerId}|${s.month}');
    add(
      s.workerId,
      monthlyNet(salary: s.salary, advances: s.advances, paid: s.paid),
    );
  }

  // Unsettled months: earnings from attendance, each day priced at the rate
  // that was in force on that day.
  final earnedByWorker = <String, double>{};
  for (final record in priorAttendance) {
    if (settled.contains('${record.workerId}|${record.month}')) continue;
    final worker = workerById[record.workerId];
    if (worker == null) continue;
    earnedByWorker.update(
      record.workerId,
      (value) => value + record.dayValue * worker.wageOn(record.date),
      ifAbsent: () => record.dayValue * worker.wageOn(record.date),
    );
  }
  earnedByWorker.forEach((workerId, earned) {
    add(workerId, roundRupees(earned));
  });

  // …less advances drawn in those same unsettled months.
  for (final advance in priorAdvances) {
    if (settled.contains('${advance.workerId}|${advance.month}')) continue;
    add(advance.workerId, -advance.amount);
  }

  return totals;
}

/// The payroll calculation, as a pure function.
///
/// Deliberately free of Firestore so it can be unit-tested without a device or
/// a network — this arithmetic is where the real risk in the app lives, and it
/// previously sat inline inside a provider method that could only be exercised
/// by running the whole app against production data.
///
/// The rules (CLAUDE.md §6):
/// * `present = 1.0`, `half_day = 0.5`, `absent = 0.0`, unmarked = nothing
/// * `salary = round(days × dailyWage)`
/// * `balance = opening + salary − advances − paid`
/// * `opening` comes from [openingBalances] — the running total of *every*
///   month before this one, not just the last settled one.
List<MonthlyRow> computeMonthlyRows({
  required List<Worker> workers,
  required List<Attendance> attendance,
  required List<Advance> advances,
  required List<Settlement> settlements,
  required Map<String, int> opening,
}) {
  final workerById = {for (final w in workers) w.workerId: w};

  final daysByWorker = <String, double>{};
  final earnedByWorker = <String, double>{};
  final recordsByWorker = <String, List<Attendance>>{};
  for (final record in attendance) {
    daysByWorker.update(
      record.workerId,
      (value) => value + record.dayValue,
      ifAbsent: () => record.dayValue,
    );
    // Priced per day, so a rate change part-way through a month is handled and
    // a later change never reaches back.
    final rate = workerById[record.workerId]?.wageOn(record.date) ?? 0;
    earnedByWorker.update(
      record.workerId,
      (value) => value + record.dayValue * rate,
      ifAbsent: () => record.dayValue * rate,
    );
    recordsByWorker.putIfAbsent(record.workerId, () => []).add(record);
  }

  final advancesByWorker = <String, int>{};
  final advanceRecordsByWorker = <String, List<Advance>>{};
  for (final advance in advances) {
    advancesByWorker.update(
      advance.workerId,
      (value) => value + advance.amount,
      ifAbsent: () => advance.amount,
    );
    advanceRecordsByWorker.putIfAbsent(advance.workerId, () => []).add(advance);
  }

  final settlementByWorker = {for (final s in settlements) s.workerId: s};

  return workers.map((worker) {
    final id = worker.workerId;
    final days = daysByWorker[id] ?? 0;
    final broughtForward = opening[id] ?? 0;
    final salary = roundRupees(earnedByWorker[id] ?? 0);
    final advanceTotal = advancesByWorker[id] ?? 0;
    final settlement = settlementByWorker[id];
    final paid = settlement?.paid ?? 0;

    return MonthlyRow(
      worker: worker,
      days: days,
      opening: broughtForward,
      salary: salary,
      advances: advanceTotal,
      paid: paid,
      balance: broughtForward + salary - advanceTotal - paid,
      isSettled: settlement != null,
      records: recordsByWorker[id] ?? const [],
      advanceRecords: advanceRecordsByWorker[id] ?? const [],
    );
  }).toList();
}

/// Builds a [WorkerStatement] for [worker] between [start] and [end] inclusive.
///
/// Takes the worker's **entire** history and slices it here rather than querying
/// a range, because a date range plus a workerId equality would need a composite
/// index, and one worker's whole history is a few hundred documents. Slicing in
/// memory also means [WorkerStatement.broughtForward] comes free — it is just
/// the other side of the same split.
///
/// Settlements are attributed by *month*, so a payment counts as "before the
/// period" when its month precedes the month [start] falls in. That is a slight
/// imprecision at a boundary mid-month, and is the reason the statement labels
/// the figure "brought forward" rather than implying to-the-day accuracy.
WorkerStatement buildWorkerStatement({
  required Worker worker,
  required DateTime start,
  required DateTime end,
  required List<Attendance> allAttendance,
  required List<Advance> allAdvances,
  required List<Settlement> allSettlements,
}) {
  final startKey = dateKey(start);
  final endKey = dateKey(end);
  final startMonth = monthKey(start);
  final endMonth = monthKey(end);

  bool inRange(String key) =>
      key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
  bool before(String key) => key.compareTo(startKey) < 0;

  // ── Brought forward ──
  var carriedEarnings = 0.0;
  for (final record in allAttendance) {
    if (before(record.date)) {
      carriedEarnings += record.dayValue * worker.wageOn(record.date);
    }
  }
  var carried = roundRupees(carriedEarnings);
  for (final advance in allAdvances) {
    if (before(advance.date)) carried -= advance.amount;
  }
  for (final settlement in allSettlements) {
    if (settlement.month.compareTo(startMonth) < 0) carried -= settlement.paid;
  }

  // ── In period ──
  final attendance = allAttendance.where((r) => inRange(r.date)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final advances = allAdvances.where((a) => inRange(a.date)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final settlements =
      allSettlements
          .where(
            (s) =>
                s.month.compareTo(startMonth) >= 0 &&
                s.month.compareTo(endMonth) <= 0,
          )
          .toList()
        ..sort((a, b) => a.month.compareTo(b.month));

  var fullDays = 0;
  var halfDays = 0;
  var absentDays = 0;
  var daysWorked = 0.0;
  var earnedExact = 0.0;
  for (final record in attendance) {
    earnedExact += record.dayValue * worker.wageOn(record.date);
    switch (record.status) {
      case AttendanceStatus.present:
        fullDays++;
        break;
      case AttendanceStatus.halfDay:
        halfDays++;
        break;
      case AttendanceStatus.absent:
        absentDays++;
        break;
    }
    daysWorked += record.dayValue;
  }

  final earned = roundRupees(earnedExact);

  // Distinct rates actually applied in the period, so the statement can show
  // "5 days × ₹600" when there is one rate and stay honest when there are two.
  final ratesApplied =
      attendance
          .where((r) => r.dayValue > 0)
          .map((r) => worker.wageOn(r.date))
          .toSet()
          .toList()
        ..sort();
  final advancesTotal = advances.fold(0, (sum, a) => sum + a.amount);
  final paid = settlements.fold(0, (sum, s) => sum + s.paid);

  return WorkerStatement(
    worker: worker,
    start: start,
    end: end,
    broughtForward: carried,
    fullDays: fullDays,
    halfDays: halfDays,
    absentDays: absentDays,
    daysWorked: daysWorked,
    earned: earned,
    advancesTotal: advancesTotal,
    paid: paid,
    pending: carried + earned - advancesTotal - paid,
    ratesApplied: ratesApplied,
    attendance: attendance,
    advances: advances,
    settlements: settlements,
  );
}

/// Closing balance a settlement should record.
int closingBalance({
  required int opening,
  required int salary,
  required int advances,
  required int paid,
}) => opening + salary - advances - paid;
