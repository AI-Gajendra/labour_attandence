import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// One page of audit entries plus the cursor needed to fetch the next.
class AuditPage {
  final List<Map<String, dynamic>> entries;
  final DocumentSnapshot? cursor;
  final bool hasMore;

  const AuditPage({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  static const AuditPage empty = AuditPage(
    entries: [],
    cursor: null,
    hasMore: false,
  );
}

/// Audit trail for every data modification.
///
/// Logging lives behind [FirestoreService] rather than in the screens, so no
/// caller can forget it — the previous arrangement audited advances only, and
/// only because `advance_screen.dart` remembered to ask.
///
/// Audit failures never propagate: losing the trail entry for a change is bad,
/// but failing the change itself because the trail write failed is worse.
class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final AuditService _instance = AuditService._internal();

  factory AuditService() => _instance;
  AuditService._internal();

  static const String _collection = 'audit_log';

  String get _actor => AuthService().actorId;

  Future<void> logCreate({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> data,
  }) => _write(
    action: '${collectionName}_created',
    collectionName: collectionName,
    documentId: documentId,
    workerId: workerId,
    before: null,
    after: data,
  );

  Future<void> logUpdate({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) => _write(
    action: '${collectionName}_updated',
    collectionName: collectionName,
    documentId: documentId,
    workerId: workerId,
    before: before,
    after: after,
  );

  Future<void> logDelete({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> data,
  }) => _write(
    action: '${collectionName}_deleted',
    collectionName: collectionName,
    documentId: documentId,
    workerId: workerId,
    before: data,
    after: null,
  );

  Future<void> _write({
    required String action,
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic>? before,
    required Map<String, dynamic>? after,
  }) async {
    try {
      await _db.collection(_collection).add({
        'action': action,
        'collectionName': collectionName,
        'documentId': documentId,
        'workerId': workerId,
        'before': before,
        'after': after,
        'changedBy': _actor,
        'changedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AuditService: failed to log $action — $e');
    }
  }

  /// Fetches audit entries newest-first, one page at a time.
  ///
  /// Pass the previous page's [AuditPage.cursor] as [startAfter] to page down.
  Future<AuditPage> getAuditLog({
    int limit = 40,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(_collection)
        .orderBy('changedAt', descending: true)
        .limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snap = await query.get();
    return AuditPage(
      entries: snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList(),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  // Note: a per-worker audit query (`where workerId` + `orderBy changedAt`)
  // would need a composite index in firestore.indexes.json. It was previously
  // here as dead code and has been removed — add it back together with the
  // index if a screen ever needs it.
}
