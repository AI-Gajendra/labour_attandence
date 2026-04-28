import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker.dart';
import '../models/attendance.dart';
import '../models/advance.dart';
import 'audit_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  // Workers
  Stream<List<Worker>> streamWorkers() {
    return _db.collection('workers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Worker.fromFirestore(doc)).toList());
  }

  Future<void> addWorker(String name, String type, double dailyWage) {
    Worker worker = Worker(
      workerId: '', // Firebase assigns document ID
      name: name,
      type: type,
      dailyWage: dailyWage,
      createdBy: 'admin_1',
      createdAt: DateTime.now(),
    );
    return _db.collection('workers').doc().set(worker.toMap());
  }

  // Attendance
  // Optimized 1-tap UX relies on composite key: workerId_date
  Future<void> markAttendance(String workerId, String date, String month, String status) {
    String attendanceId = '${workerId}_$date';
    return _db.collection('attendance').doc(attendanceId).set({
      'workerId': workerId,
      'date': date,
      'month': month,
      'status': status,
      'createdBy': 'admin_1', // MVP generic admin
    }, SetOptions(merge: true));
  }

  // Fetch Attendance for a specific month (present + half_day for salary)
  Future<List<Attendance>> getAttendance(String month) async {
    QuerySnapshot snap = await _db
        .collection('attendance')
        .where('month', isEqualTo: month)
        .where('status', whereIn: ['present', 'half_day'])
        .get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }
  
  // Fetch Attendance for a specific worker and month (includes both present and absent)
  Future<List<Attendance>> getWorkerAttendance(String workerId, String month) async {
    QuerySnapshot snap = await _db
        .collection('attendance')
        .where('workerId', isEqualTo: workerId)
        .where('month', isEqualTo: month)
        .get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // Fetch Attendance for a specific date
  Future<List<Attendance>> getAttendanceForDate(String date) async {
    QuerySnapshot snap = await _db
        .collection('attendance')
        .where('date', isEqualTo: date)
        .get();
    return snap.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // Advance
  Future<void> addAdvance(String workerId, double amount, String date, String month) {
    Advance advance = Advance(
      advanceId: '',
      workerId: workerId,
      amount: amount,
      date: date,
      month: month,
      createdBy: 'admin_1',
    );
    return _db.collection('advances').doc().set(advance.toMap());
  }

  // Fetch Advances for a specific month
  Future<List<Advance>> getAdvances(String month) async {
    QuerySnapshot snap = await _db
        .collection('advances')
        .where('month', isEqualTo: month)
        .get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }
  
  // Fetch Advances for a specific worker and month
  Future<List<Advance>> getWorkerAdvances(String workerId, String month) async {
    QuerySnapshot snap = await _db
        .collection('advances')
        .where('workerId', isEqualTo: workerId)
        .where('month', isEqualTo: month)
        .get();
    return snap.docs.map((doc) => Advance.fromFirestore(doc)).toList();
  }

  // Get count of present days for a worker in a month (half_day = 0.5)
  Future<double> getAttendanceCount(String workerId, String month) async {
    final list = await getWorkerAttendance(workerId, month);
    double count = 0;
    for (final a in list) {
      if (a.status == 'present') count += 1.0;
      if (a.status == 'half_day') count += 0.5;
    }
    return count;
  }

  // Get total advances for a worker in a month
  Future<double> getAdvancesTotal(String workerId, String month) async {
    final list = await getWorkerAdvances(workerId, month);
    double total = 0;
    for (final a in list) {
      total += a.amount;
    }
    return total;
  }

  // Update worker details
  Future<void> updateWorker(String workerId, String name, String type, double dailyWage) {
    return _db.collection('workers').doc(workerId).update({
      'name': name,
      'type': type,
      'dailyWage': dailyWage,
    });
  }

  // Delete worker
  Future<void> deleteWorker(String workerId) {
    return _db.collection('workers').doc(workerId).delete();
  }

  // Update an advance record (with audit trail)
  Future<void> updateAdvance(String advanceId, double newAmount, String newDate, String newMonth) async {
    final docRef = _db.collection('advances').doc(advanceId);
    final oldDoc = await docRef.get();
    if (!oldDoc.exists) return;

    final oldData = oldDoc.data()!;
    final newData = {
      'amount': newAmount,
      'date': newDate,
      'month': newMonth,
    };

    await docRef.update(newData);

    // Log audit
    await AuditService().logUpdate(
      collectionName: 'advances',
      documentId: advanceId,
      workerId: oldData['workerId'] ?? '',
      before: {
        'amount': oldData['amount'],
        'date': oldData['date'],
        'month': oldData['month'],
      },
      after: newData,
    );
  }

  // Delete an advance record (with audit trail)
  Future<void> deleteAdvance(String advanceId) async {
    final docRef = _db.collection('advances').doc(advanceId);
    final oldDoc = await docRef.get();
    if (!oldDoc.exists) return;

    final oldData = oldDoc.data()!;
    await docRef.delete();

    // Log audit
    await AuditService().logDelete(
      collectionName: 'advances',
      documentId: advanceId,
      workerId: oldData['workerId'] ?? '',
      data: {
        'amount': oldData['amount'],
        'date': oldData['date'],
        'month': oldData['month'],
      },
    );
  }
}
