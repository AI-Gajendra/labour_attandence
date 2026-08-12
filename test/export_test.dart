import 'package:flutter_test/flutter_test.dart';
import 'package:labour_attendance/models/advance.dart';
import 'package:labour_attendance/models/attendance.dart';
import 'package:labour_attendance/models/monthly_row.dart';
import 'package:labour_attendance/models/worker.dart';
import 'package:labour_attendance/models/worker_statement.dart';
import 'package:labour_attendance/services/export_service.dart';
import 'package:labour_attendance/utils/payroll.dart';

MonthlyRow row(
  String name, {
  int wage = 600,
  double days = 10,
  int opening = 0,
  int salary = 6000,
  int advances = 1000,
  int paid = 0,
  bool settled = false,
}) => MonthlyRow(
  worker: Worker(
    workerId: name,
    name: name,
    type: 'Helper',
    dailyWage: wage,
    createdBy: 'test',
    createdAt: DateTime(2026, 1, 1),
  ),
  days: days,
  opening: opening,
  salary: salary,
  advances: advances,
  paid: paid,
  balance: opening + salary - advances - paid,
  isSettled: settled,
  records: const [],
  advanceRecords: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = ExportService();

  group('CSV', () {
    test('has a header, a row per worker and a totals line', () {
      final csv = service.buildPayrollCsv(
        month: '2026-08',
        rows: [row('Ramesh'), row('Kalu', salary: 3000, advances: 500)],
      );

      final lines = csv.trim().split('\n');
      expect(lines.length, 4); // header + 2 workers + totals
      expect(lines.first, startsWith('"Worker","Trade"'));
      expect(lines[1], contains('"Ramesh"'));
      expect(lines.last, startsWith('"TOTAL"'));
    });

    test('totals add up', () {
      final csv = service.buildPayrollCsv(
        month: '2026-08',
        rows: [
          row('A', salary: 6000, advances: 1000),
          row('B', salary: 3000, advances: 500),
        ],
      );
      final totals = csv.trim().split('\n').last;
      expect(totals, contains('"9000"')); // salary
      expect(totals, contains('"1500"')); // advances
      expect(totals, contains('"7500"')); // balance
    });

    test(
      'quotes are escaped so a name with punctuation cannot break the file',
      () {
        final csv = service.buildPayrollCsv(
          month: '2026-08',
          rows: [row('Ram "Chotu", Lal')],
        );
        expect(csv, contains('"Ram ""Chotu"", Lal"'));
      },
    );

    test('handles an empty month', () {
      final csv = service.buildPayrollCsv(month: '2026-08', rows: const []);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2); // header + empty totals
    });
  });

  group('PDF', () {
    test('renders with the embedded font', () async {
      // Guards two things: that the bundled Inter TTF parses, and that the ₹
      // sign therefore has a glyph. The PDF standard fonts have no U+20B9 and
      // would drop it silently.
      final bytes = await service.buildPayrollPdf(
        month: '2026-08',
        rows: [row('Ramesh'), row('Kalu')],
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders an empty month without throwing', () async {
      final bytes = await service.buildPayrollPdf(
        month: '2026-08',
        rows: const [],
      );
      expect(bytes.length, greaterThan(500));
    });
  });

  group('worker statement PDF', () {
    final worker = Worker(
      workerId: 'w1',
      name: 'Ramesh',
      type: 'Electrician',
      dailyWage: 600,
      createdBy: 'test',
      createdAt: DateTime(2026, 1, 1),
    );

    WorkerStatement statement({
      List<Attendance> attendance = const [],
      List<Advance> advances = const [],
    }) => buildWorkerStatement(
      worker: worker,
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
      allAttendance: attendance,
      allAdvances: advances,
      allSettlements: const [],
    );

    test('renders with attendance and advances listed', () async {
      final bytes = await service.buildWorkerStatementPdf(
        statement(
          attendance: [
            Attendance(
              attendanceId: 'a1',
              workerId: 'w1',
              date: '2026-08-01',
              month: '2026-08',
              status: AttendanceStatus.present,
              createdBy: 'test',
            ),
            Attendance(
              attendanceId: 'a2',
              workerId: 'w1',
              date: '2026-08-02',
              month: '2026-08',
              status: AttendanceStatus.halfDay,
              createdBy: 'test',
            ),
          ],
          advances: [
            Advance(
              advanceId: 'adv1',
              workerId: 'w1',
              amount: 500,
              date: '2026-08-03',
              month: '2026-08',
              createdBy: 'test',
            ),
          ],
        ),
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('renders a period with no records at all', () async {
      final bytes = await service.buildWorkerStatementPdf(statement());
      expect(bytes.length, greaterThan(500));
    });
  });
}
