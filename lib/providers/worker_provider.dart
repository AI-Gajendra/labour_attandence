import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';

/// Single source of truth for the worker list.
/// All screens read from this provider instead of creating separate streams.
class WorkerProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Worker> _workers = [];
  bool _isLoading = true;
  StreamSubscription? _sub;

  List<Worker> get workers => _workers;
  bool get isLoading => _isLoading;
  int get count => _workers.length;

  WorkerProvider() {
    _listen();
  }

  void _listen() {
    _sub = _service.streamWorkers().listen((list) {
      _workers = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addWorker(String name, String type, double dailyWage) async {
    await _service.addWorker(name, type, dailyWage);
  }

  Future<void> updateWorker(String id, String name, String type, double wage) async {
    await _service.updateWorker(id, name, type, wage);
  }

  Future<void> deleteWorker(String id) async {
    await _service.deleteWorker(id);
  }

  /// Filter workers by search query (name or type).
  List<Worker> search(String query) {
    if (query.isEmpty) return _workers;
    final q = query.toLowerCase();
    return _workers.where((w) =>
        w.name.toLowerCase().contains(q) ||
        w.type.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
