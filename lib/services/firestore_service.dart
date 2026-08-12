import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker.dart';
import '../models/attendance.dart';
import '../models/advance.dart';
import '../models/settlement.dart';
import '../utils/money.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'sync_status.dart';

/// All Firestore reads and writes.
///
/// Two rules hold here:
/// 1. **Screens never touch `FirebaseFirestore.instance`** — everything goes
///    through this service.
/// 2. **Audit logging happens inside this service**, not at the call sites, so
///    a mutation cannot be added without a trail entry coming with it.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;
  FirestoreService._internal();

  AuditService get _audit => AuditService();
  String get _actor => AuthService().actorId;

  CollectionReference<Map<String, dynamic>> get _workers =>
      _db.collection('workers');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _db.collection('attendance');
  CollectionReference<Map<String, dynamic>> get _advances =>
      _db.collection('advances');
  CollectionReference<Map<String, dynamic>> get _settlements =>
      _db.collection('settlements');

  // ────────────────────────────── Workers ──────────────────────────────

  /// Live stream of every worker, active and archived.
  ///
  /// The collection is small (tens of documents) so filtering happens in
  /// [WorkerProvider] rather than costing a second query.
  ///
  /// Metadata changes are included so this one listener doubles as the app's
  /// online/offline signal — `isFromCache` tells us the device isn't reaching
  /// Firestore, which the sync banner surfaces. Cheaper than a connectivity
  /// plugin and truer, since it reports the connection that actually matters.
  Stream<List<Worker>> streamWorkers() {
    return _workers.snapshots(includeMetadataChanges: true).map((snapshot) {
      SyncStatus.instance.setFromCache(snapshot.metadata.isFromCache);
      return snapshot.docs.map((doc) => Worker.fromFirestore(doc)).toList();
    });
  }

  /// Creates a worker and returns the generated document id.
  Future<String> addWorker(String name, String type, int dailyWage) async {
    final worker = Worker(
      workerId: '',
      name: name,
      type: type,
      dailyWage: dailyWage,
      createdBy: _actor,
      createdAt: DateTime.now(),
    );

    final ref = _workers.doc();
    await ref.set(worker.toMap());

    await _audit.logCreate(
      collectionName: 'workers',
      documentId: ref.id,
      workerId: ref.id,
      data: {'name': name, 'type': type, 'dailyWage': dailyWage},
    );
    return ref.id;
  }

  /// Updates a worker.
  ///
  /// When [dailyWage] differs from the stored rate, [wageEffectiveFrom]
  /// (a `YYYY-MM-DD` key) decides which days the new rate applies to. Days
  /// before it keep the old rate — see [Worker.wageOn] for why that matters.
  ///
  /// Pass `null` to rewrite history entirely, i.e. "the rate was always this,
  /// I typed it in wrong". That deliberately re-prices every unsettled day.
  Future<void> updateWorker(
    String workerId,
    String name,
    String type,
    int dailyWage, {
    String? wageEffectiveFrom,
  }) async {
    final ref = _workers.doc(workerId);
    final existing = await ref.get();
    final before = existing.data();
    final previousWage = asRupees(before?['dailyWage']);

    final update = <String, dynamic>{
      'name': name,
      'type': type,
      'dailyWage': dailyWage,
    };

    if (dailyWage != previousWage) {
      final current = Worker.fromFirestore(existing).wageHistory;

      if (wageEffectiveFrom == null) {
        // Correcting a mistake: one entry covering all of time.
        update['wageHistory'] = [
          WageRate(from: WageRate.beginning, wage: dailyWage).toMap(),
        ];
      } else {
        final history = [
          // Drop any entry starting on the same day — re-stating a rate for a
          // date should replace it, not stack a duplicate.
          ...current.where((r) => r.from != wageEffectiveFrom),
          WageRate(from: wageEffectiveFrom, wage: dailyWage),
        ];
        // Seed the baseline the first time a rate ever changes, so days before
        // the change keep the rate that was actually agreed then.
        if (!history.any((r) => r.from == WageRate.beginning)) {
          history.add(WageRate(from: WageRate.beginning, wage: previousWage));
        }
        history.sort((a, b) => b.from.compareTo(a.from));
        update['wageHistory'] = history.map((r) => r.toMap()).toList();
      }
    }

    await ref.update(update);

    await _audit.logUpdate(
      collectionName: 'workers',
      documentId: workerId,
      workerId: workerId,
      before: {
        'name': before?['name'],
        'type': before?['type'],
        'dailyWage': previousWage,
      },
      after: {
        'name': name,
        'type': type,
        'dailyWage': dailyWage,
        if (dailyWage != previousWage)
          'wageEffectiveFrom': wageEffectiveFrom ?? 'all time',
      },
    );
  }

  /// Archives a worker (soft delete).
  ///
  /// Their attendance, advances and settlements stay intact so historical
  /// months keep resolving. Use [purgeWorker] for a genuine erase.
  Future<void> archiveWorker(String workerId) async {
    final ref = _workers.doc(workerId);
    final existing = await ref.get();
    if (!existing.exists) return;

    await ref.update({'isActive': false});

    await _audit.logUpdate(
      collectionName: 'workers',
      documentId: workerId,
      workerId: workerId,
      before: {'isActive': existing.data()?['isActive'] ?? true},
      after: {'isActive': false},
    );
  }

  Future<void> restoreWorker(String workerId) async {
    await _workers.doc(workerId).update({'isActive': true});
    await _audit.logUpdate(
      collectionName: 'workers',
      documentId: workerId,
      workerId: workerId,
      before: {'isActive': false},
      after: {'isActive': true},
    );
  }

  /// Permanently deletes a worker **and all of their records**.
  ///
  /// Destroys payroll history — only call behind an explicit confirmation that
  /// names what will be lost. Returns the number of documents removed.
  Future<int> purgeWorker(String workerId) async {
    final existing = await _workers.doc(workerId).get();
    var removed = 0;

    for (final collection in [_attendance, _advances, _settlements]) {
      final snap = await collection
          .where('workerId', isEqualTo: workerId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
        removed++;
      }
    }

    await _workers.doc(workerId).delete();
    removed++;

    await _audit.logDelete(
      collectionName: 'workers',
      documentId: workerId,
      workerId: workerId,
      data: {
        'name': existing.data()?['name'],
        'type': existing.data()?['type'],
        'dailyWage': asRupees(existing.data()?['dailyWage']),
        'documentsRemoved': removed,
      },
    );
    return removed;
  }

  // ───────────────────────────── Attendance ─────────────────────────────

  /// Marks attendance. Idempotent by construction: the document id is
  /// `{workerId}_{date}`, so re-marking overwrites rather than duplicating.
  ///
  /// [previousStatus] is supplied by the caller (which already holds it in its
  /// local state) so the audit trail gets a before/after without paying for an
  /// extra read on the hot path. Marks that don't change anything are skipped.
  Future<void> markAttendance(
    String workerId,
    String date,
    String month,
    String status, {
    String? previousStatus,
  }) async {
    if (previousStatus == status) return;

    final attendanceId = '${workerId}_$date';
    await _attendance.doc(attendanceId).set({
      'workerId': workerId,
      'date': date,
      'month': month,
      'status': status,
      'createdBy': _actor,
    }, SetOptions(merge: true));

    if (previousStatus == null) {
      await _audit.logCreate(
        collectionName: 'attendance',
        documentId: attendanceId,
        workerId: workerId,
        data: {'date': date, 'status': status},
      );
    } else {
      await _audit.logUpdate(
        collectionName: 'attendance',
        documentId: attendanceId,
        workerId: workerId,
        before: {'date': date, 'status': previousStatus},
        after: {'date': date, 'status': status},
      );
    }
  }

  /// Every attendance record for one calendar day (all workers).
  Future<List<Attendance>> getAttendanceForDate(String date) async {
    final snap = await _attendance.where('date', isEqualTo: date).get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  /// Every attendance record for one month (all workers).
  ///
  /// Single-field equality — served by the automatic index, no composite index
  /// required. This one query replaces the old per-worker fan-out.
  Future<List<Attendance>> getAttendanceForMonth(String month) async {
    final snap = await _attendance.where('month', isEqualTo: month).get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  /// One worker's attendance for one month (worker profile screen).
  Future<List<Attendance>> getWorkerAttendance(
    String workerId,
    String month,
  ) async {
    final snap = await _attendance
        .where('workerId', isEqualTo: workerId)
        .where('month', isEqualTo: month)
        .get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  /// Every attendance record from before [month] (all workers).
  ///
  /// Single-field range — automatic index, no composite needed. Feeds the
  /// running carry-forward balance.
  Future<List<Attendance>> getAttendanceBeforeMonth(String month) async {
    final snap = await _attendance.where('month', isLessThan: month).get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  /// A worker's entire attendance history, for date-range statements.
  Future<List<Attendance>> getAllAttendanceForWorker(String workerId) async {
    final snap = await _attendance.where('workerId', isEqualTo: workerId).get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // ────────────────────────────── Advances ──────────────────────────────

  /// Records an advance and returns the generated document id.
  Future<String> addAdvance(
    String workerId,
    int amount,
    String date,
    String month,
  ) async {
    final advance = Advance(
      advanceId: '',
      workerId: workerId,
      amount: amount,
      date: date,
      month: month,
      createdBy: _actor,
    );

    final ref = _advances.doc();
    await ref.set(advance.toMap());

    // The audit entry is linked to the real document id — previously this was
    // logged with an empty id from the screen, orphaning the trail.
    await _audit.logCreate(
      collectionName: 'advances',
      documentId: ref.id,
      workerId: workerId,
      data: {'amount': amount, 'date': date, 'month': month},
    );
    return ref.id;
  }

  Future<List<Advance>> getAdvancesForMonth(String month) async {
    final snap = await _advances.where('month', isEqualTo: month).get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }

  Future<List<Advance>> getWorkerAdvances(String workerId, String month) async {
    final snap = await _advances
        .where('workerId', isEqualTo: workerId)
        .where('month', isEqualTo: month)
        .get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }

  /// Every advance from before [month] (all workers).
  Future<List<Advance>> getAdvancesBeforeMonth(String month) async {
    final snap = await _advances.where('month', isLessThan: month).get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }

  /// A worker's entire advance history, for date-range statements.
  Future<List<Advance>> getAllAdvancesForWorker(String workerId) async {
    final snap = await _advances.where('workerId', isEqualTo: workerId).get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }

  Future<void> updateAdvance(
    String advanceId,
    int newAmount,
    String newDate,
    String newMonth,
  ) async {
    final ref = _advances.doc(advanceId);
    final existing = await ref.get();
    if (!existing.exists) return;

    final before = existing.data()!;
    final after = {'amount': newAmount, 'date': newDate, 'month': newMonth};

    await ref.update(after);

    await _audit.logUpdate(
      collectionName: 'advances',
      documentId: advanceId,
      workerId: (before['workerId'] as String?) ?? '',
      before: {
        'amount': asRupees(before['amount']),
        'date': before['date'],
        'month': before['month'],
      },
      after: after,
    );
  }

  Future<void> deleteAdvance(String advanceId) async {
    final ref = _advances.doc(advanceId);
    final existing = await ref.get();
    if (!existing.exists) return;

    final before = existing.data()!;
    await ref.delete();

    await _audit.logDelete(
      collectionName: 'advances',
      documentId: advanceId,
      workerId: (before['workerId'] as String?) ?? '',
      data: {
        'amount': asRupees(before['amount']),
        'date': before['date'],
        'month': before['month'],
      },
    );
  }

  // ───────────────────────────── Settlements ─────────────────────────────

  /// Every settlement for one month (all workers). Used to read both the
  /// current month's payouts and the previous month's closing balances.
  Future<List<Settlement>> getSettlementsForMonth(String month) async {
    final snap = await _settlements.where('month', isEqualTo: month).get();
    return snap.docs.map((doc) => Settlement.fromFirestore(doc)).toList();
  }

  /// Every settlement from before [month] (all workers).
  Future<List<Settlement>> getSettlementsBeforeMonth(String month) async {
    final snap = await _settlements.where('month', isLessThan: month).get();
    return snap.docs.map((doc) => Settlement.fromFirestore(doc)).toList();
  }

  /// A worker's entire settlement history, for date-range statements.
  Future<List<Settlement>> getAllSettlementsForWorker(String workerId) async {
    final snap = await _settlements
        .where('workerId', isEqualTo: workerId)
        .get();
    return snap.docs.map((doc) => Settlement.fromFirestore(doc)).toList();
  }

  Future<Settlement?> getSettlement(String workerId, String month) async {
    final doc = await _settlements.doc(Settlement.idFor(workerId, month)).get();
    return doc.exists ? Settlement.fromFirestore(doc) : null;
  }

  /// Writes (or rewrites) a month's settlement for one worker.
  ///
  /// Idempotent — the document id is `{workerId}_{month}`.
  Future<void> saveSettlement(Settlement settlement) async {
    final ref = _settlements.doc(
      Settlement.idFor(settlement.workerId, settlement.month),
    );
    final existing = await ref.get();

    await ref.set(settlement.toMap());

    final after = {
      'paid': settlement.paid,
      'closing': settlement.closing,
      'mode': settlement.mode,
    };

    if (existing.exists) {
      final before = existing.data()!;
      await _audit.logUpdate(
        collectionName: 'settlements',
        documentId: ref.id,
        workerId: settlement.workerId,
        before: {
          'paid': asRupees(before['paid']),
          'closing': asRupees(before['closing']),
          'mode': before['mode'],
        },
        after: after,
      );
    } else {
      await _audit.logCreate(
        collectionName: 'settlements',
        documentId: ref.id,
        workerId: settlement.workerId,
        data: after,
      );
    }
  }

  /// Reopens a settled month.
  Future<void> deleteSettlement(String workerId, String month) async {
    final ref = _settlements.doc(Settlement.idFor(workerId, month));
    final existing = await ref.get();
    if (!existing.exists) return;

    final before = existing.data()!;
    await ref.delete();

    await _audit.logDelete(
      collectionName: 'settlements',
      documentId: ref.id,
      workerId: workerId,
      data: {
        'month': month,
        'paid': asRupees(before['paid']),
        'closing': asRupees(before['closing']),
      },
    );
  }
}
