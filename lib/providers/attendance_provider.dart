import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

/// Manages attendance marking state for a single day.
/// Tracks which workers have been marked and their status,
/// providing instant UI feedback before Firestore confirms.
class AttendanceProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  /// workerId → 'present' | 'absent'
  final Map<String, String> _statuses = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showSaved = false;

  Map<String, String> get statuses => _statuses;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get showSaved => _showSaved;

  int get presentCount => _statuses.values.where((s) => s == 'present').length;
  int get halfDayCount => _statuses.values.where((s) => s == 'half_day').length;
  int get absentCount => _statuses.values.where((s) => s == 'absent').length;
  int get markedCount => _statuses.length;

  String? statusOf(String workerId) => _statuses[workerId];

  /// Fetch attendance status for a given date.
  Future<void> loadForDate(DateTime date) async {
    _selectedDate = date;
    _isLoading = true;
    _statuses.clear(); // Clear existing
    notifyListeners();

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final records = await _service.getAttendanceForDate(dateStr);
      for (final r in records) {
        _statuses[r.workerId] = r.status;
      }
    } catch (e) {
      debugPrint('Error loading attendance for date: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a worker as present or absent (optimistic UI update).
  Future<void> mark(String workerId, String date, String month, String status) async {
    _statuses[workerId] = status;
    notifyListeners();
    await _service.markAttendance(workerId, date, month, status);
  }

  /// Show the saved overlay, then auto-dismiss after 1.8s.
  Future<void> triggerSavedOverlay() async {
    _showSaved = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 1800));
    _showSaved = false;
    notifyListeners();
  }

  /// Reset state for a new day / screen re-entry.
  void reset() {
    _statuses.clear();
    _selectedDate = DateTime.now();
    _isLoading = false;
    _isSaving = false;
    _showSaved = false;
    notifyListeners();
  }
}
