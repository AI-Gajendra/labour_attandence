import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit trail service for tracking all data modifications.
/// Logs changes to the `audit_log` Firestore collection.
class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final AuditService _instance = AuditService._internal();

  factory AuditService() => _instance;
  AuditService._internal();

  static const String _collection = 'audit_log';

  /// Log a create action.
  Future<void> logCreate({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> data,
    String changedBy = 'admin_1',
  }) {
    return _db.collection(_collection).add({
      'action': '${collectionName}_created',
      'collectionName': collectionName,
      'documentId': documentId,
      'workerId': workerId,
      'before': null,
      'after': data,
      'changedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Log an update action with before/after diff.
  Future<void> logUpdate({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    String changedBy = 'admin_1',
  }) {
    return _db.collection(_collection).add({
      'action': '${collectionName}_updated',
      'collectionName': collectionName,
      'documentId': documentId,
      'workerId': workerId,
      'before': before,
      'after': after,
      'changedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Log a delete action.
  Future<void> logDelete({
    required String collectionName,
    required String documentId,
    required String workerId,
    required Map<String, dynamic> data,
    String changedBy = 'admin_1',
  }) {
    return _db.collection(_collection).add({
      'action': '${collectionName}_deleted',
      'collectionName': collectionName,
      'documentId': documentId,
      'workerId': workerId,
      'before': data,
      'after': null,
      'changedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch audit log entries, newest first.
  Future<List<Map<String, dynamic>>> getAuditLog({int limit = 50}) async {
    final snap = await _db
        .collection(_collection)
        .orderBy('changedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Fetch audit log for a specific worker.
  Future<List<Map<String, dynamic>>> getWorkerAuditLog(String workerId, {int limit = 50}) async {
    final snap = await _db
        .collection(_collection)
        .where('workerId', isEqualTo: workerId)
        .orderBy('changedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
