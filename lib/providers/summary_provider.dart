import 'package:flutter/foundation.dart';
import '../models/advance.dart';
import '../models/attendance.dart';
import '../models/monthly_row.dart';
import '../models/settlement.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/sync_status.dart';
import '../utils/dates.dart';
import '../utils/payroll.dart';

/// Monthly payroll aggregation for every worker.
///
/// ## Why this got rewritten
///
/// The previous version looped over workers and awaited **two Firestore
/// round-trips each**, serially: 30 workers meant 60 sequential queries on
/// every month change and every pull-to-refresh. This version issues **four
/// queries total, regardless of headcount**, and groups in memory. All four are
/// single-field equality filters, so they are served by the automatic index —
/// no composite index needed.
class SummaryProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  DateTime _currentMonth = firstOfMonth(DateTime.now());
  bool _isLoading = false;
  String? _error;

  Map<String, MonthlyRow> _rows = {};
  List<MonthlyRow> _ordered = [];

  /// Cached results, so flicking between months already loaded costs nothing.
  ///
  /// Keyed by month **and the worker set**, not month alone. Keying by month
  /// alone was a real bug: the Reports tab is built eagerly inside the shell's
  /// IndexedStack, so its first load fires while `WorkerProvider` is still
  /// streaming. That computed zero rows from an empty worker list and cached
  /// them under the month — and nothing re-triggered a load once the workers
  /// arrived, so the payroll showed an empty month until the user happened to
  /// pull-to-refresh.
  final Map<String, List<MonthlyRow>> _cache = {};

  /// Identity of a worker set, for cache keying.
  static String _signature(List<Worker> workers) =>
      workers.map((w) => w.workerId).join(',');

  String _cacheKey(String month, List<Worker> workers) =>
      '$month|${_signature(workers)}';

  void _evictMonth(String month) =>
      _cache.removeWhere((key, _) => key.startsWith('$month|'));

  double _totalDays = 0;
  int _totalSalary = 0;
  int _totalAdvances = 0;
  int _totalPaid = 0;
  int _totalBalance = 0;

  DateTime get currentMonth => _currentMonth;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Rows in the order they should be displayed (worker name).
  List<MonthlyRow> get rows => List.unmodifiable(_ordered);
  MonthlyRow? rowFor(String workerId) => _rows[workerId];

  double get totalDays => _totalDays;
  int get totalSalary => _totalSalary;
  int get totalAdvances => _totalAdvances;
  int get totalPaid => _totalPaid;
  int get totalBalance => _totalBalance;

  String get monthStr => monthKey(_currentMonth);
  String get displayMonth => displayMonthLong(_currentMonth);

  /// True once every active worker in the list has a settlement for the month.
  bool get isMonthFullySettled =>
      _ordered.isNotEmpty && _ordered.every((r) => r.isSettled);

  void prevMonth() {
    _currentMonth = addMonths(_currentMonth, -1);
    notifyListeners();
  }

  void nextMonth() {
    _currentMonth = addMonths(_currentMonth, 1);
    notifyListeners();
  }

  /// Loads the current month for [workers].
  ///
  /// Pass `force: true` to bypass the per-month cache (pull-to-refresh, or
  /// after a settlement is recorded).
  Future<void> loadData(List<Worker> workers, {bool force = false}) async {
    final month = monthStr;
    final key = _cacheKey(month, workers);

    if (!force && _cache.containsKey(key)) {
      _publish(_cache[key]!);
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Six queries, independent of how many workers there are. The three
      // "before this month" queries feed the running carry-forward balance —
      // reading only the previous month's settlement meant any month nobody had
      // settled contributed nothing, and the debt vanished.
      final results = await Future.wait([
        _service.getAttendanceForMonth(month),
        _service.getAdvancesForMonth(month),
        _service.getSettlementsForMonth(month),
        _service.getAttendanceBeforeMonth(month),
        _service.getAdvancesBeforeMonth(month),
        _service.getSettlementsBeforeMonth(month),
      ]);

      // The arithmetic itself lives in utils/payroll.dart so it can be unit
      // tested without Firebase.
      final rows = computeMonthlyRows(
        workers: workers,
        attendance: results[0] as List<Attendance>,
        advances: results[1] as List<Advance>,
        settlements: results[2] as List<Settlement>,
        opening: openingBalances(
          workers: workers,
          priorAttendance: results[3] as List<Attendance>,
          priorAdvances: results[4] as List<Advance>,
          priorSettlements: results[5] as List<Settlement>,
        ),
      );

      // Never remember an answer computed from an empty worker list — that
      // means the worker stream had not arrived yet, not that there is no crew.
      if (workers.isNotEmpty) _cache[key] = rows;
      _publish(rows);
    } catch (e) {
      _error = 'Could not load the payroll for $displayMonth.';
      debugPrint('SummaryProvider: load failed — $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _publish(List<MonthlyRow> rows) {
    _ordered = rows;
    _rows = {for (final r in rows) r.worker.workerId: r};

    _totalDays = rows.fold(0.0, (sum, r) => sum + r.days);
    _totalSalary = rows.fold(0, (sum, r) => sum + r.salary);
    _totalAdvances = rows.fold(0, (sum, r) => sum + r.advances);
    _totalPaid = rows.fold(0, (sum, r) => sum + r.paid);
    _totalBalance = rows.fold(0, (sum, r) => sum + r.balance);

    _isLoading = false;
    notifyListeners();
  }

  /// Records a payout, closing this month for [row]'s worker.
  ///
  /// The closing balance is stored explicitly so next month can read it as its
  /// opening figure without replaying history — which matters because a
  /// worker's daily wage changes over time and old attendance must not be
  /// re-priced at today's rate.
  Future<void> settle(
    MonthlyRow row,
    int amountPaid, {
    String mode = Settlement.modeCash,
    String note = '',
  }) async {
    final settlement = Settlement(
      settlementId: Settlement.idFor(row.worker.workerId, monthStr),
      workerId: row.worker.workerId,
      month: monthStr,
      opening: row.opening,
      salary: row.salary,
      advances: row.advances,
      paid: amountPaid,
      closing: closingBalance(
        opening: row.opening,
        salary: row.salary,
        advances: row.advances,
        paid: amountPaid,
      ),
      mode: mode,
      note: note,
      createdBy: AuthService().actorId,
      settledAt: DateTime.now(),
    );

    await SyncStatus.instance.track(
      _service.saveSettlement(settlement),
      description: 'Recording payment',
    );

    // The next month's opening balance depends on this, so both are stale.
    _evictMonth(monthStr);
    _evictMonth(monthKey(addMonths(_currentMonth, 1)));
  }

  /// Reopens a settled month.
  Future<void> unsettle(String workerId) async {
    await SyncStatus.instance.track(
      _service.deleteSettlement(workerId, monthStr),
      description: 'Reopening month',
    );
    _evictMonth(monthStr);
    _evictMonth(monthKey(addMonths(_currentMonth, 1)));
  }

  /// Drops all cached months — used after edits made elsewhere in the app.
  void invalidateCache() => _cache.clear();
}
