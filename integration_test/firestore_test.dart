import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labour_attendance/firebase_options.dart';
import 'package:labour_attendance/services/firestore_service.dart';

/// Integration tests for Firestore connectivity and CRUD operations.
/// Run with: flutter test integration_test/firestore_test.dart -d emulator-5554
///
/// These tests use a real Firestore instance. Test data is created with a
/// unique prefix and cleaned up after each test to avoid polluting production.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirestoreService service;
  late FirebaseFirestore db;
  const testPrefix = '__test_';
  String testWorkerId = '';

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    service = FirestoreService();
    db = FirebaseFirestore.instance;
  });

  // ── Cleanup helper ──
  Future<void> cleanupTestData() async {
    // Delete test worker
    if (testWorkerId.isNotEmpty) {
      try { await db.collection('workers').doc(testWorkerId).delete(); } catch (_) {}
    }
    // Delete test attendance records
    final attSnap = await db.collection('attendance')
        .where('workerId', isEqualTo: testWorkerId)
        .get();
    for (final doc in attSnap.docs) {
      await doc.reference.delete();
    }
    // Delete test advance records
    final advSnap = await db.collection('advances')
        .where('workerId', isEqualTo: testWorkerId)
        .get();
    for (final doc in advSnap.docs) {
      await doc.reference.delete();
    }
    testWorkerId = '';
  }

  group('Firestore Connection', () {
    testWidgets('1. Firebase initializes successfully', (tester) async {
      // If we reach here, Firebase.initializeApp in setUpAll succeeded.
      final apps = Firebase.apps;
      expect(apps, isNotEmpty, reason: 'Firebase should have at least one initialized app');
      debugPrint('✅ Firebase initialized. App name: ${apps.first.name}');
    });

    testWidgets('2. Firestore instance is accessible', (tester) async {
      expect(db, isNotNull);
      // Attempt a lightweight read to verify network connectivity
      final snap = await db.collection('workers').limit(1).get();
      // If no exception was thrown, connection is live.
      expect(snap, isNotNull, reason: 'Firestore query should return a snapshot');
      debugPrint('✅ Firestore connected. Workers collection accessible.');
    });
  });

  group('Worker CRUD', () {
    testWidgets('3. addWorker — creates a new document', (tester) async {
      // Create a test worker
      await service.addWorker('${testPrefix}Rajesh', 'Mason', 650);

      // Query it back
      final snap = await db.collection('workers')
          .where('name', isEqualTo: '${testPrefix}Rajesh')
          .get();

      expect(snap.docs, isNotEmpty, reason: 'Test worker should exist in Firestore');
      testWorkerId = snap.docs.first.id;

      final data = snap.docs.first.data();
      expect(data['name'], equals('${testPrefix}Rajesh'));
      expect(data['type'], equals('Mason'));
      expect(data['dailyWage'], equals(650));
      debugPrint('✅ Worker created. ID: $testWorkerId');
    });

    testWidgets('4. updateWorker — modifies existing document', (tester) async {
      // Ensure we have a test worker
      if (testWorkerId.isEmpty) {
        await service.addWorker('${testPrefix}Rajesh', 'Mason', 650);
        final snap = await db.collection('workers')
            .where('name', isEqualTo: '${testPrefix}Rajesh')
            .get();
        testWorkerId = snap.docs.first.id;
      }

      // Update the worker
      await service.updateWorker(testWorkerId, '${testPrefix}Rajesh Kumar', 'Mistri', 750);

      // Verify update
      final doc = await db.collection('workers').doc(testWorkerId).get();
      expect(doc.exists, isTrue, reason: 'Worker document should still exist after update');

      final data = doc.data()!;
      expect(data['name'], equals('${testPrefix}Rajesh Kumar'));
      expect(data['type'], equals('Mistri'));
      expect(data['dailyWage'], equals(750));
      debugPrint('✅ Worker updated: name=${data['name']}, type=${data['type']}, wage=${data['dailyWage']}');
    });

    testWidgets('5. deleteWorker — removes the document', (tester) async {
      // Create a disposable worker
      await service.addWorker('${testPrefix}DeleteMe', 'Helper', 400);
      final snap = await db.collection('workers')
          .where('name', isEqualTo: '${testPrefix}DeleteMe')
          .get();
      final deleteId = snap.docs.first.id;

      // Delete it
      await service.deleteWorker(deleteId);

      // Verify it's gone
      final doc = await db.collection('workers').doc(deleteId).get();
      expect(doc.exists, isFalse, reason: 'Deleted worker should not exist');
      debugPrint('✅ Worker deleted successfully.');
    });
  });

  group('Attendance Operations', () {
    testWidgets('6. markAttendance — creates/updates composite-key document', (tester) async {
      // Ensure test worker exists
      if (testWorkerId.isEmpty) {
        await service.addWorker('${testPrefix}AttTest', 'Helper', 500);
        final snap = await db.collection('workers')
            .where('name', isEqualTo: '${testPrefix}AttTest')
            .get();
        testWorkerId = snap.docs.first.id;
      }

      const date = '2026-04-05';
      const month = '2026-04';

      // Mark present
      await service.markAttendance(testWorkerId, date, month, 'present');

      // Verify the composite key document
      final docId = '${testWorkerId}_$date';
      final doc = await db.collection('attendance').doc(docId).get();

      expect(doc.exists, isTrue, reason: 'Attendance doc with composite ID should exist');

      final data = doc.data()!;
      expect(data['workerId'], equals(testWorkerId));
      expect(data['date'], equals(date));
      expect(data['month'], equals(month));
      expect(data['status'], equals('present'));
      debugPrint('✅ Attendance marked: $docId → status=${data['status']}');
    });

    testWidgets('7. markAttendance — re-marking is idempotent (overwrites)', (tester) async {
      const date = '2026-04-05';
      const month = '2026-04';

      // Mark absent (override the previous present)
      await service.markAttendance(testWorkerId, date, month, 'absent');

      final docId = '${testWorkerId}_$date';
      final doc = await db.collection('attendance').doc(docId).get();

      expect(doc.data()!['status'], equals('absent'),
          reason: 'Re-marking should overwrite the old status');
      debugPrint('✅ Idempotent overwrite verified: status changed to absent');
    });

    testWidgets('8. getAttendanceCount — returns correct count', (tester) async {
      const month = '2026-04';

      // Mark present on 2 different days
      await service.markAttendance(testWorkerId, '2026-04-01', month, 'present');
      await service.markAttendance(testWorkerId, '2026-04-02', month, 'present');
      // Mark absent on a 3rd day (should NOT count)
      await service.markAttendance(testWorkerId, '2026-04-03', month, 'absent');

      final count = await service.getAttendanceCount(testWorkerId, month);

      // We have 2 present days (01 and 02). The earlier 04-05 was marked absent.
      expect(count, equals(2), reason: 'Only present days should be counted');
      debugPrint('✅ Attendance count = $count (expected 2)');
    });
  });

  group('Advance Operations', () {
    testWidgets('9. addAdvance — creates a new advance record', (tester) async {
      const date = '2026-04-05';
      const month = '2026-04';

      await service.addAdvance(testWorkerId, 1000, date, month);

      // Verify
      final snap = await db.collection('advances')
          .where('workerId', isEqualTo: testWorkerId)
          .where('month', isEqualTo: month)
          .get();

      expect(snap.docs, isNotEmpty, reason: 'Advance record should exist');
      final data = snap.docs.first.data();
      expect(data['amount'], equals(1000));
      expect(data['date'], equals(date));
      debugPrint('✅ Advance recorded: ₹${data['amount']} on ${data['date']}');
    });

    testWidgets('10. getAdvancesTotal — sums multiple advances', (tester) async {
      const month = '2026-04';

      // Add a second advance
      await service.addAdvance(testWorkerId, 500, '2026-04-06', month);

      final total = await service.getAdvancesTotal(testWorkerId, month);

      expect(total, equals(1500), reason: 'Total should be 1000 + 500 = 1500');
      debugPrint('✅ Advance total = ₹$total (expected 1500)');
    });
  });

  group('Salary Calculation (End-to-End)', () {
    testWidgets('11. Full salary calculation: days × wage - advances', (tester) async {
      const month = '2026-04';

      // At this point for testWorkerId in 2026-04:
      // - 2 present days (04-01, 04-02)
      // - Worker wage = 500 (${testPrefix}AttTest)
      // - Advances = ₹1500

      final days = await service.getAttendanceCount(testWorkerId, month);
      final advances = await service.getAdvancesTotal(testWorkerId, month);

      // Fetch the worker's wage from Firestore
      final workerDoc = await db.collection('workers').doc(testWorkerId).get();
      final wage = (workerDoc.data()!['dailyWage'] as num).toDouble();

      final salary = days * wage;
      final balance = salary - advances;

      debugPrint('── Salary Breakdown ──');
      debugPrint('  Days worked: $days');
      debugPrint('  Daily wage:  ₹${wage.toStringAsFixed(0)}');
      debugPrint('  Gross salary: ₹${salary.toStringAsFixed(0)}');
      debugPrint('  Advances:    ₹${advances.toStringAsFixed(0)}');
      debugPrint('  Balance:     ₹${balance.toStringAsFixed(0)}');

      expect(days, equals(2));
      expect(salary, equals(1000)); // 2 × 500
      expect(advances, equals(1500));
      expect(balance, equals(-500)); // 1000 - 1500
      debugPrint('✅ Full salary calculation verified.');
    });
  });

  // ── Cleanup all test data ──
  tearDownAll(() async {
    await cleanupTestData();
    debugPrint('🧹 Test data cleaned up.');
  });
}
