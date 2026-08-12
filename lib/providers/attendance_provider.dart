import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/firestore_service.dart';
import '../services/sync_status.dart';
import '../utils/dates.dart';

/// Attendance state for a single selected day.
///
/// Marking is optimistic: the local map updates and repaints immediately, then
/// the Firestore write is issued. The write is deliberately **not awaited** —
/// offline, Firestore queues it and the future stays pending indefinitely, so
/// awaiting would freeze the one interaction that has to stay instant on a site
/// with no signal. Failures roll the local state back.
class AttendanceProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  /// workerId → `present` | `half_day` | `absent`
  final Map<String, String> _statuses = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _showSaved = false;
  String _savedMessage = '';
  String? _error;

  Map<String, String> get statuses => Map.unmodifiable(_statuses);
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get showSaved => _showSaved;
  String get savedMessage => _savedMessage;
  String? get error => _error;

  int get presentCount =>
      _statuses.values.where((s) => s == AttendanceStatus.present).length;
  int get halfDayCount =>
      _statuses.values.where((s) => s == AttendanceStatus.halfDay).length;
  int get absentCount =>
      _statuses.values.where((s) => s == AttendanceStatus.absent).length;
  int get markedCount => _statuses.length;

  /// Day-equivalents marked so far — half days count 0.5.
  double get dayEquivalents => _statuses.values.fold(
    0.0,
    (sum, s) => sum + AttendanceStatus.dayValue(s),
  );

  String? statusOf(String workerId) => _statuses[workerId];

  String get selectedDateKey => dateKey(_selectedDate);
  String get selectedMonthKey => monthKey(_selectedDate);

  /// Loads the marks already recorded for [date].
  Future<void> loadForDate(DateTime date) async {
    _selectedDate = date;
    _isLoading = true;
    _error = null;
    _statuses.clear();
    notifyListeners();

    try {
      final records = await _service.getAttendanceForDate(dateKey(date));
      for (final record in records) {
        _statuses[record.workerId] = record.status;
      }
    } catch (e) {
      _error = 'Could not load attendance for this date.';
      debugPrint('AttendanceProvider: load failed — $e');
    } finally {
      _isLoading = false;
      _syncTodayCounters();
      notifyListeners();
    }
  }

  /// Marks one worker. Returns immediately; the write completes in background.
  void mark(String workerId, String status) {
    final previous = _statuses[workerId];
    if (previous == status) return;

    // Optimistic update first — the gesture must feel instant.
    _statuses[workerId] = status;
    _error = null;
    _syncTodayCounters();
    notifyListeners();

    SyncStatus.instance
        .track(
          _service.markAttendance(
            workerId,
            selectedDateKey,
            selectedMonthKey,
            status,
            previousStatus: previous,
          ),
          description: 'Saving attendance',
        )
        .catchError((Object e) {
          // Roll the optimistic change back so the UI never claims a mark that
          // Firestore rejected.
          if (previous == null) {
            _statuses.remove(workerId);
          } else {
            _statuses[workerId] = previous;
          }
          _error = 'Could not save that mark. Please try again.';
          debugPrint('AttendanceProvider: mark failed — $e');
          _syncTodayCounters();
          notifyListeners();
        });
  }

  /// Keeps the dashboard counters in step when the day being edited *is* today.
  void _syncTodayCounters() {
    if (!isSameDay(_selectedDate, DateTime.now())) return;
    _todayMarked = markedCount;
    _todayPresent = presentCount;
    _todayDayEquivalents = dayEquivalents;
    _todayLoaded = true;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ── Today, independent of the selected date ──
  //
  // The dashboard needs "how many are marked *today*" even while the attendance
  // screen is sitting on some other date, so this is tracked separately rather
  // than reusing [_statuses].

  int _todayMarked = 0;
  int _todayPresent = 0;
  double _todayDayEquivalents = 0;
  bool _todayLoaded = false;

  int get todayMarked => _todayMarked;
  int get todayPresent => _todayPresent;
  double get todayDayEquivalents => _todayDayEquivalents;
  bool get todayLoaded => _todayLoaded;

  /// Refreshes the dashboard's view of today.
  Future<void> refreshToday() async {
    try {
      final records = await _service.getAttendanceForDate(
        dateKey(DateTime.now()),
      );
      _todayMarked = records.length;
      _todayPresent = records
          .where((r) => r.status == AttendanceStatus.present)
          .length;
      _todayDayEquivalents = records.fold(0.0, (sum, r) => sum + r.dayValue);
      _todayLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AttendanceProvider: today refresh failed — $e');
    }
  }

  /// Shows the confirmation overlay with a message that reflects reality:
  /// marks are already written, and whether they have *synced* depends on the
  /// connection. The old overlay always claimed "All records have been updated"
  /// regardless of what had actually happened.
  Future<void> triggerSavedOverlay() async {
    final pending = SyncStatus.instance.pending;
    final offline = SyncStatus.instance.isOffline;

    if (pending > 0 || offline) {
      _savedMessage = 'Saved on this phone. Will sync when back online.';
    } else {
      _savedMessage = '$markedCount of today\'s marks are saved.';
    }

    _showSaved = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1600));
    _showSaved = false;
    notifyListeners();
  }

  /// Resets state for a new day / screen re-entry.
  void reset() {
    _statuses.clear();
    _selectedDate = DateTime.now();
    _isLoading = false;
    _showSaved = false;
    _savedMessage = '';
    _error = null;
    notifyListeners();
  }
}
