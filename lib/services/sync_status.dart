import 'package:flutter/foundation.dart';

/// Tracks whether the app's writes have actually reached Firestore.
///
/// This matters more here than in most apps. Firestore queues writes locally
/// when there is no connection and the returned `Future` **does not complete
/// until the server acknowledges it** — so on a site with no signal a write is
/// neither failed nor done, it is simply pending, potentially for hours.
///
/// The old code awaited those futures silently, which meant the operator had no
/// way to tell "saved" from "queued" from "failed". [pending] and [isOffline]
/// exist so the UI can say so out loud.
class SyncStatus extends ChangeNotifier {
  static final SyncStatus instance = SyncStatus._();
  SyncStatus._();

  int _pending = 0;
  String? _lastError;
  bool _fromCache = false;

  /// Writes issued but not yet acknowledged by the server.
  int get pending => _pending;

  /// True when the most recent snapshot was served from the local cache,
  /// i.e. the device is not currently talking to Firestore.
  bool get isOffline => _fromCache;

  /// Last write error, if any. Cleared by [clearError].
  String? get lastError => _lastError;

  bool get hasPendingWrites => _pending > 0;

  void setFromCache(bool value) {
    if (_fromCache == value) return;
    _fromCache = value;
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Runs [operation], counting it as pending until it settles.
  ///
  /// Rethrows so callers can roll back optimistic state; the error is also
  /// recorded in [lastError] for the status banner.
  Future<T> track<T>(Future<T> operation, {String? description}) async {
    _pending++;
    notifyListeners();
    try {
      final result = await operation;
      return result;
    } catch (e) {
      _lastError = description == null ? '$e' : '$description failed: $e';
      debugPrint('SyncStatus: $_lastError');
      rethrow;
    } finally {
      _pending--;
      notifyListeners();
    }
  }
}
