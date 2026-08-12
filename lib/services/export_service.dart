import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/attendance.dart';
import '../models/monthly_row.dart';
import '../models/worker_statement.dart';
import '../utils/dates.dart';
import '../utils/money.dart';

/// Gets payroll data out of the app.
///
/// Until now there was **no way to extract anything** — a lost phone or a
/// misconfigured Firebase project meant a year of payroll was simply gone, and
/// nothing could be handed to an accountant.
///
/// Two formats, both shared through the Android share sheet (WhatsApp, Drive,
/// Gmail): CSV for spreadsheets and PDF for handing over. The builder methods
/// are pure so the formatting is unit-testable without a device.
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  pw.Font? _font;

  /// Inter, embedded so the ₹ sign renders. The PDF standard fonts (Helvetica
  /// et al.) have no glyph for U+20B9 and would silently drop it — in a rupee
  /// app that is not an acceptable failure mode.
  Future<pw.Font> _loadFont() async {
    _font ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
    );
    return _font!;
  }

  // ────────────────────────────── CSV ──────────────────────────────

  /// Builds the payroll CSV for one month. Pure — no I/O.
  String buildPayrollCsv({
    required String month,
    required List<MonthlyRow> rows,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      _csvRow([
        'Worker',
        'Trade',
        'Daily Wage',
        'Days',
        'Opening Balance',
        'Salary',
        'Advances',
        'Paid',
        'Balance',
        'Settled',
      ]),
    );

    for (final row in rows) {
      buffer.writeln(
        _csvRow([
          row.worker.name,
          row.worker.type,
          rupeesPlain(row.rate),
          formatDays(row.days),
          rupeesPlain(row.opening),
          rupeesPlain(row.salary),
          rupeesPlain(row.advances),
          rupeesPlain(row.paid),
          rupeesPlain(row.balance),
          row.isSettled ? 'yes' : 'no',
        ]),
      );
    }

    // Totals line, so the file is self-checking when opened in a spreadsheet.
    buffer.writeln(
      _csvRow([
        'TOTAL',
        '',
        '',
        formatDays(rows.fold(0.0, (s, r) => s + r.days)),
        rupeesPlain(rows.fold(0, (s, r) => s + r.opening)),
        rupeesPlain(rows.fold(0, (s, r) => s + r.salary)),
        rupeesPlain(rows.fold(0, (s, r) => s + r.advances)),
        rupeesPlain(rows.fold(0, (s, r) => s + r.paid)),
        rupeesPlain(rows.fold(0, (s, r) => s + r.balance)),
        '',
      ]),
    );

    return buffer.toString();
  }

  /// RFC 4180 quoting: wrap every field, double any embedded quote. Worker
  /// names contain commas and apostrophes often enough to matter.
  String _csvRow(List<String> fields) =>
      fields.map((f) => '"${f.replaceAll('"', '""')}"').join(',');

  // ────────────────────────────── PDF ──────────────────────────────

  /// Builds the payroll PDF for one month.
  Future<Uint8List> buildPayrollPdf({
    required String month,
    required List<MonthlyRow> rows,
  }) async {
    final font = await _loadFont();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final monthDate = parseMonthKey(month);
    final title = monthDate == null ? month : displayMonthLong(monthDate);

    final totalDays = rows.fold(0.0, (s, r) => s + r.days);
    final totalSalary = rows.fold(0, (s, r) => s + r.salary);
    final totalAdvances = rows.fold(0, (s, r) => s + r.advances);
    final totalPaid = rows.fold(0, (s, r) => s + r.paid);
    final totalBalance = rows.fold(0, (s, r) => s + r.balance);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Labour Manager — Payroll',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$title  ·  generated ${displayDayMonth(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'Worker',
              'Trade',
              'Rate',
              'Days',
              'Opening',
              'Salary',
              'Advance',
              'Paid',
              'Balance',
            ],
            data: rows
                .map(
                  (row) => [
                    row.worker.name,
                    row.worker.type,
                    row.hasMixedRates
                        ? '${rupees(row.ratesApplied.first)}-${rupees(row.ratesApplied.last)}'
                        : rupees(row.rate),
                    formatDays(row.days),
                    rupees(row.opening),
                    rupees(row.salary),
                    rupees(row.advances),
                    rupees(row.paid),
                    rupees(row.balance),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              for (var i = 2; i <= 8; i++) i: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfTotal('DAYS', formatDays(totalDays)),
                _pdfTotal('SALARY', rupees(totalSalary)),
                _pdfTotal('ADVANCE', rupees(totalAdvances)),
                _pdfTotal('PAID', rupees(totalPaid)),
                _pdfTotal('BALANCE', rupees(totalBalance)),
              ],
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfTotal(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  // ─────────────────────── Per-worker statement ───────────────────────

  /// One worker's account for a date range — the shareable *haazri parchi*.
  ///
  /// Lists every marked day and every advance with its date, so the numbers can
  /// be checked line by line rather than taken on trust. That is the point of
  /// the document: a worker who can audit the total is a worker who comes back
  /// next season.
  Future<Uint8List> buildWorkerStatementPdf(WorkerStatement s) async {
    final font = await _loadFont();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final period = '${displayDayMonth(s.start)}  —  ${displayDayMonth(s.end)}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber > 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  '${s.worker.name} · $period',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              )
            : pw.SizedBox(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // ── Title ──
          pw.Text(
            'Worker Statement',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${s.worker.name}'
            '${s.worker.type.isEmpty ? '' : ' · ${s.worker.type}'}'
            ' · ${rateLabel(s.ratesApplied, fallback: s.worker.wageOn(dateKey(s.end)))}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            period,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),

          // ── Attendance totals ──
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfTotal('FULL DAYS', '${s.fullDays}'),
                _pdfTotal('HALF DAYS', '${s.halfDays}'),
                _pdfTotal('ABSENT', '${s.absentDays}'),
                _pdfTotal('NOT MARKED', '${s.unmarkedDays}'),
                _pdfTotal('DAYS WORKED', formatDays(s.daysWorked)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Money ──
          pw.Text(
            'Account',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['', 'Amount'],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            data: [
              if (s.broughtForward != 0)
                ['Brought forward', rupees(s.broughtForward)],
              [
                s.ratesApplied.length == 1
                    ? 'Earned  (${formatDays(s.daysWorked)} days × ${rupees(s.ratesApplied.single)})'
                    : s.ratesApplied.isEmpty
                    ? 'Earned  (${formatDays(s.daysWorked)} days)'
                    // The rate changed part-way through this period; the
                    // per-day table below shows which day got which rate.
                    : 'Earned  (${formatDays(s.daysWorked)} days, rates '
                          '${s.ratesApplied.map(rupees).join(' & ')})',
                rupees(s.earned),
              ],
              ['Advances taken (kharchi)', '- ${rupees(s.advancesTotal)}'],
              if (s.paid != 0) ['Already paid', '- ${rupees(s.paid)}'],
              [
                s.pending >= 0 ? 'PENDING (payable)' : 'PENDING (over-drawn)',
                rupees(s.pending),
              ],
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Advances detail ──
          pw.Text(
            'Advances',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (s.advances.isEmpty)
            pw.Text(
              'No advances in this period',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Amount'],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
              data: [
                ...s.advances.map(
                  (a) => [displayDateKey(a.date), rupees(a.amount)],
                ),
                ['Total', rupees(s.advancesTotal)],
              ],
            ),
          pw.SizedBox(height: 18),

          // ── Attendance detail ──
          pw.Text(
            'Attendance',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (s.attendance.isEmpty)
            pw.Text(
              'No days marked in this period',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Status', 'Day', 'Rate'],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              data: s.attendance
                  .map(
                    (r) => [
                      displayDateKey(r.date),
                      _statusLabel(r.status),
                      formatDays(r.dayValue),
                      // The rate in force on that day, not today's rate.
                      rupees(s.worker.wageOn(r.date)),
                    ],
                  )
                  .toList(),
            ),

          pw.SizedBox(height: 24),
          pw.Text(
            'Generated ${displayDayMonth(DateTime.now())} · Labour Manager',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return document.save();
  }

  static String _statusLabel(String status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Full day';
      case AttendanceStatus.halfDay:
        return 'Half day';
      case AttendanceStatus.absent:
        return 'Absent';
      default:
        return status;
    }
  }

  /// File name for a worker's statement, e.g.
  /// `statement-ramesh-2026-08-01-to-2026-08-31.pdf`.
  String statementFileName(WorkerStatement s) {
    final safeName = s.worker.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    return 'statement-$safeName-${dateKey(s.start)}-to-${dateKey(s.end)}.pdf';
  }

  /// One-line summary used as the share subject.
  String statementSubject(WorkerStatement s) =>
      '${s.worker.name} · ${displayDayMonth(s.start)} to '
      '${displayDayMonth(s.end)} · Pending ${rupees(s.pending)}';

  Future<void> shareWorkerStatementPdf(
    WorkerStatement s, {
    Uint8List? bytes,
  }) async {
    final data = bytes ?? await buildWorkerStatementPdf(s);
    final file = await _writeTemp(statementFileName(s), data);
    await _share(file, statementSubject(s));
  }

  /// Shares already-built PDF bytes — used by the preview screen so the
  /// document is not regenerated just to send it.
  Future<void> sharePdfBytes({
    required Uint8List bytes,
    required String fileName,
    required String subject,
  }) async {
    final file = await _writeTemp(fileName, bytes);
    await _share(file, subject);
  }

  // ───────────────────────────── Sharing ─────────────────────────────

  Future<void> sharePayrollCsv({
    required String month,
    required List<MonthlyRow> rows,
  }) async {
    final csv = buildPayrollCsv(month: month, rows: rows);
    final file = await _writeTemp('payroll-$month.csv', csv.codeUnits);
    await _share(file, 'Payroll $month (CSV)');
  }

  Future<void> sharePayrollPdf({
    required String month,
    required List<MonthlyRow> rows,
    Uint8List? bytes,
  }) async {
    final data = bytes ?? await buildPayrollPdf(month: month, rows: rows);
    final file = await _writeTemp('payroll-$month.pdf', data);
    await _share(file, 'Payroll $month (PDF)');
  }

  Future<File> _writeTemp(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _share(File file, String subject) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject, text: subject),
    );
  }
}
