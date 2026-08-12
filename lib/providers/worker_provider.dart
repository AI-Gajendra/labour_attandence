import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';
import '../services/sync_status.dart';

/// Single source of truth for the worker list.
///
/// The only real-time listener in the app. Everything else reads on demand.
class WorkerProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Worker> _all = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _sub;

  /// Active workers only, name-sorted — what every picker and list shows.
  List<Worker> get workers =>
      _all.where((w) => w.isActive).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Everyone, including archived — needed to resolve names in history.
  List<Worker> get allWorkers => List.unmodifiable(_all);

  List<Worker> get archivedWorkers => _all.where((w) => !w.isActive).toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => workers.length;
  int get archivedCount => archivedWorkers.length;

  WorkerProvider() {
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = _service.streamWorkers().listen(
      (list) {
        _all = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        // A permission or network failure must not leave the UI spinning.
        _isLoading = false;
        _error = 'Could not load workers. $e';
        debugPrint('WorkerProvider: $_error');
        notifyListeners();
      },
    );
  }

  /// Re-subscribes after an error.
  void retry() {
    _isLoading = true;
    _error = null;
    notifyListeners();
    _listen();
  }

  /// Looks a worker up by id, including archived ones.
  Worker? byId(String id) {
    for (final w in _all) {
      if (w.workerId == id) return w;
    }
    return null;
  }

  /// Display name for an id, for history screens where the worker may be gone.
  String nameOf(String id) => byId(id)?.name ?? 'Unknown';

  Future<void> addWorker(String name, String type, int dailyWage) =>
      SyncStatus.instance.track(
        _service.addWorker(name, type, dailyWage),
        description: 'Adding worker',
      );

  /// [wageEffectiveFrom] is a `YYYY-MM-DD` key; null means "this rate has
  /// always applied" (correcting a typo) and re-prices unsettled history.
  Future<void> updateWorker(
    String id,
    String name,
    String type,
    int dailyWage, {
    String? wageEffectiveFrom,
  }) => SyncStatus.instance.track(
    _service.updateWorker(
      id,
      name,
      type,
      dailyWage,
      wageEffectiveFrom: wageEffectiveFrom,
    ),
    description: 'Updating worker',
  );

  /// Soft delete — keeps history intact.
  Future<void> archiveWorker(String id) => SyncStatus.instance.track(
    _service.archiveWorker(id),
    description: 'Archiving worker',
  );

  Future<void> restoreWorker(String id) => SyncStatus.instance.track(
    _service.restoreWorker(id),
    description: 'Restoring worker',
  );

  /// Permanent erase of the worker and every record referencing them.
  Future<int> purgeWorker(String id) => SyncStatus.instance.track(
    _service.purgeWorker(id),
    description: 'Deleting worker',
  );

  /// Filters active workers by name or trade.
  List<Worker> search(String query) {
    if (query.isEmpty) return workers;
    final q = query.toLowerCase();
    return workers
        .where(
          (w) =>
              w.name.toLowerCase().contains(q) ||
              w.type.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
