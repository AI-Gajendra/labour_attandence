import 'package:flutter/foundation.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';

/// Manages monthly summary data (days worked, salary, advances, balance)
/// for all workers. Fetches data once per month change and caches it.
class SummaryProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;

  /// workerId → {days: int, salary: double, advances: double, balance: double}
  Map<String, Map<String, dynamic>> _data = {};

  // Aggregate totals
  double _totalDays = 0;
  double _totalSalary = 0;
  double _totalAdvances = 0;
  double _totalBalance = 0;

  DateTime get currentMonth => _currentMonth;
  bool get isLoading => _isLoading;
  Map<String, Map<String, dynamic>> get data => _data;
  double get totalDays => _totalDays;
  double get totalSalary => _totalSalary;
  double get totalAdvances => _totalAdvances;
  double get totalBalance => _totalBalance;

  String get monthStr =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get displayMonth {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  void prevMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    notifyListeners();
  }

  /// Load summary data for all workers for the current month.
  Future<void> loadData(List<Worker> workers) async {
    _isLoading = true;
    notifyListeners();

    final result = <String, Map<String, dynamic>>{};
    double tDays = 0;
    double tSalary = 0;
    double tAdvances = 0;

    for (final w in workers) {
      final records = await _service.getWorkerAttendance(w.workerId, monthStr);
      double days = 0;
      for (final r in records) {
        if (r.status == 'present') days += 1.0;
        if (r.status == 'half_day') days += 0.5;
      }
      final advances = await _service.getAdvancesTotal(w.workerId, monthStr);
      final salary = days * w.dailyWage;
      result[w.workerId] = {
        'days': days,
        'salary': salary,
        'advances': advances,
        'balance': salary - advances,
        'records': records,
      };
      tDays += days;
      tSalary += salary;
      tAdvances += advances;
    }

    _data = result;
    _totalDays = tDays;
    _totalSalary = tSalary;
    _totalAdvances = tAdvances;
    _totalBalance = tSalary - tAdvances;
    _isLoading = false;
    notifyListeners();
  }
}
