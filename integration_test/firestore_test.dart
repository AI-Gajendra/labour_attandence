import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labour_attendance/firebase_options.dart';
import 'package:labour_attendance/models/attendance.dart';
import 'package:labour_attendance/models/settlement.dart';
import 'package:labour_attendance/services/auth_service.dart';
import 'package:labour_attendance/services/emulator_config.dart';
import 'package:labour_attendance/services/firestore_service.dart';

/// Integration tests for Firestore connectivity and CRUD.
///
/// **Prefer the emulator.** Without the flag below these run against the real
/// project:
///
/// ```
/// firebase emulators:start --only firestore,auth
/// flutter test integration_test/firestore_test.dart -d <device> \
///   --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Test data is prefixed `__test_` and removed in [tearDownAll]. Each group
/// creates the fixtures it needs rather than depending on a previous test's
/// leftovers, so any single test can be run on its own.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirestoreService service;
  late FirebaseFirestore db;
  const testPrefix = '__test_';
  final createdWorkerIds = <String>{};

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await EmulatorConfig.apply();
    // Rules now require an authenticated principal.
    await AuthService().ensureSignedIn();
    service = FirestoreService();
    db = FirebaseFirestore.instance;

    if (!EmulatorConfig.enabled) {
      debugPrint(
        '⚠️  Running against the REAL Firestore project. '
        'Pass --dart-define=USE_FIREBASE_EMULATOR=true to use the emulator.',
      );
    }
  });

  /// Creates a worker and remembers it for cleanup.
  Future<String> makeWorker(String name, {int wage = 500}) async {
    final id = await service.addWorker('$testPrefix$name', 'Helper', wage);
    createdWorkerIds.add(id);
    return id;
  }

  group('Connection', () {
    testWidgets('1. Firebase initialises', (tester) async {
      expect(Firebase.apps, isNotEmpty);
    });

    testWidgets('2. Firestore is reachable', (tester) async {
      final snap = await db.collection('workers').limit(1).get();
      expect(snap, isNotNull);
    });

    testWidgets('3. an authenticated principal exists', (tester) async {
      // Without this the hardened rules reject every write.
      expect(
        AuthService().isSignedIn,
        isTrue,
        reason: 'Anonymous auth must be enabled in the Firebase console',
      );
    });
  });

  group('Worker CRUD', () {
    testWidgets('4. addWorker returns the new document id', (tester) async {
      final id = await makeWorker('Rajesh', wage: 650);
      expect(id, isNotEmpty);

      final doc = await db.collection('workers').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], '${testPrefix}Rajesh');
      expect(doc.data()!['dailyWage'], 650);
      expect(doc.data()!['isActive'], isTrue);
    });

    testWidgets('5. updateWorker modifies the document', (tester) async {
      final id = await makeWorker('ToEdit', wage: 500);
      await service.updateWorker(id, '${testPrefix}Edited', 'Mistri', 750);

      final doc = await db.collection('workers').doc(id).get();
      expect(doc.data()!['name'], '${testPrefix}Edited');
      expect(doc.data()!['type'], 'Mistri');
      expect(doc.data()!['dailyWage'], 750);
    });

    testWidgets('6. archiveWorker soft-deletes and keeps history', (
      tester,
    ) async {
      final id = await makeWorker('ToArchive');
      await service.markAttendance(
        id,
        '2026-04-01',
        '2026-04',
        AttendanceStatus.present,
      );

      await service.archiveWorker(id);

      final doc = await db.collection('workers').doc(id).get();
      expect(doc.exists, isTrue, reason: 'archive must not delete the doc');
      expect(doc.data()!['isActive'], isFalse);

      // The attendance record survives, so old months still add up.
      final attendance = await service.getWorkerAttendance(id, '2026-04');
      expect(attendance, hasLength(1));
    });

    testWidgets('7. purgeWorker removes the worker and their records', (
      tester,
    ) async {
      final id = await makeWorker('ToPurge');
      await service.markAttendance(
        id,
        '2026-04-02',
        '2026-04',
        AttendanceStatus.present,
      );
      await service.addAdvance(id, 100, '2026-04-02', '2026-04');

      final removed = await service.purgeWorker(id);
      createdWorkerIds.remove(id);

      expect(removed, greaterThanOrEqualTo(3));
      expect((await db.collection('workers').doc(id).get()).exists, isFalse);
      expect(await service.getWorkerAttendance(id, '2026-04'), isEmpty);
      expect(await service.getWorkerAdvances(id, '2026-04'), isEmpty);
    });
  });

  group('Attendance', () {
    testWidgets('8. markAttendance uses the composite key', (tester) async {
      final id = await makeWorker('Att');
      const date = '2026-04-05';

      await service.markAttendance(
        id,
        date,
        '2026-04',
        AttendanceStatus.present,
      );

      final doc = await db.collection('attendance').doc('${id}_$date').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['status'], AttendanceStatus.present);
      expect(doc.data()!['month'], '2026-04');
    });

    testWidgets('9. re-marking overwrites instead of duplicating', (
      tester,
    ) async {
      final id = await makeWorker('Idempotent');
      const date = '2026-04-05';

      await service.markAttendance(
        id,
        date,
        '2026-04',
        AttendanceStatus.present,
      );
      await service.markAttendance(
        id,
        date,
        '2026-04',
        AttendanceStatus.absent,
        previousStatus: AttendanceStatus.present,
      );

      final all = await service.getWorkerAttendance(id, '2026-04');
      expect(all, hasLength(1), reason: 'composite id must prevent duplicates');
      expect(all.single.status, AttendanceStatus.absent);
    });

    testWidgets('10. month query returns half days at 0.5', (tester) async {
      final id = await makeWorker('Days');
      await service.markAttendance(
        id,
        '2026-04-01',
        '2026-04',
        AttendanceStatus.present,
      );
      await service.markAttendance(
        id,
        '2026-04-02',
        '2026-04',
        AttendanceStatus.present,
      );
      await service.markAttendance(
        id,
        '2026-04-03',
        '2026-04',
        AttendanceStatus.halfDay,
      );
      await service.markAttendance(
        id,
        '2026-04-04',
        '2026-04',
        AttendanceStatus.absent,
      );

      final records = await service.getWorkerAttendance(id, '2026-04');
      final days = records.fold(0.0, (total, r) => total + r.dayValue);
      expect(days, 2.5);
    });
  });

  group('Advances', () {
    testWidgets('11. addAdvance returns the id it created', (tester) async {
      final id = await makeWorker('Adv');
      final advanceId = await service.addAdvance(
        id,
        1000,
        '2026-04-05',
        '2026-04',
      );

      expect(advanceId, isNotEmpty);
      final doc = await db.collection('advances').doc(advanceId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['amount'], 1000);
    });

    testWidgets('12. advances accumulate within a month', (tester) async {
      final id = await makeWorker('AdvSum');
      await service.addAdvance(id, 1000, '2026-04-05', '2026-04');
      await service.addAdvance(id, 500, '2026-04-06', '2026-04');

      final advances = await service.getWorkerAdvances(id, '2026-04');
      final total = advances.fold(0, (running, a) => running + a.amount);
      expect(total, 1500);
    });
  });

  group('Settlements and carry-forward', () {
    testWidgets('13. a settlement closes a month and carries the balance', (
      tester,
    ) async {
      final id = await makeWorker('Settle', wage: 500);

      // 2 days at ₹500 = ₹1000, ₹1500 drawn → ₹500 over-drawn.
      await service.markAttendance(
        id,
        '2026-04-01',
        '2026-04',
        AttendanceStatus.present,
      );
      await service.markAttendance(
        id,
        '2026-04-02',
        '2026-04',
        AttendanceStatus.present,
      );
      await service.addAdvance(id, 1500, '2026-04-05', '2026-04');

      await service.saveSettlement(
        Settlement(
          settlementId: Settlement.idFor(id, '2026-04'),
          workerId: id,
          month: '2026-04',
          opening: 0,
          salary: 1000,
          advances: 1500,
          paid: 0,
          closing: -500,
          mode: Settlement.modeCash,
          note: 'integration test',
          createdBy: 'test',
          settledAt: DateTime.now(),
        ),
      );

      final stored = await service.getSettlement(id, '2026-04');
      expect(stored, isNotNull);
      expect(
        stored!.closing,
        -500,
        reason: 'the debt must survive into next month',
      );

      final byMonth = await service.getSettlementsForMonth('2026-04');
      expect(byMonth.where((s) => s.workerId == id), hasLength(1));
    });

    testWidgets('14. saving a settlement twice does not duplicate it', (
      tester,
    ) async {
      final id = await makeWorker('Resettle');
      Settlement build(int paid) => Settlement(
        settlementId: Settlement.idFor(id, '2026-05'),
        workerId: id,
        month: '2026-05',
        opening: 0,
        salary: 1000,
        advances: 0,
        paid: paid,
        closing: 1000 - paid,
        mode: Settlement.modeCash,
        note: '',
        createdBy: 'test',
        settledAt: DateTime.now(),
      );

      await service.saveSettlement(build(400));
      await service.saveSettlement(build(1000));

      final all = await service.getSettlementsForMonth('2026-05');
      final mine = all.where((s) => s.workerId == id).toList();
      expect(mine, hasLength(1));
      expect(mine.single.paid, 1000);
      expect(mine.single.closing, 0);
    });
  });

  tearDownAll(() async {
    for (final id in createdWorkerIds) {
      try {
        await service.purgeWorker(id);
      } catch (e) {
        debugPrint('cleanup failed for $id: $e');
      }
    }
    debugPrint('🧹 Test data cleaned up (${createdWorkerIds.length} workers).');
  });
}
