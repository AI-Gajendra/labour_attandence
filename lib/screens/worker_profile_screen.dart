import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design_tokens.dart';
import '../models/advance.dart';
import '../models/attendance.dart';
import '../models/settlement.dart';
import '../models/worker.dart';
import '../providers/worker_provider.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/payroll.dart';
import 'attendance_screen.dart';
import 'worker_list_screen.dart';

/// Per-worker history: attendance calendar, advances and the running balance.
///
/// Built from `ui_screens/worker_profile_redesign/`, which had been sitting in
/// the repo as a finished design with no implementation. This is the screen the
/// owner needs the moment a worker questions a number — previously the only
/// per-worker view was a cramped calendar dialog on the summary screen.
class WorkerProfileScreen extends StatefulWidget {
  final String workerId;
  const WorkerProfileScreen({super.key, required this.workerId});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final FirestoreService _service = FirestoreService();

  DateTime _month = firstOfMonth(DateTime.now());
  bool _loading = true;
  bool _buildingStatement = false;
  String? _error;

  // Full history, fetched once per month change and sliced locally.
  List<Attendance> _allAttendance = const [];
  List<Advance> _allAdvances = const [];
  List<Settlement> _allSettlements = const [];

  // The displayed month's slice.
  List<Attendance> _records = const [];
  List<Advance> _advances = const [];
  Settlement? _settlement;
  int _opening = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Loads this worker's **entire** history once, then slices it locally.
  ///
  /// Three queries instead of four, and the opening balance is computed with
  /// the same [openingBalances] walk the Payroll tab uses. That matters: this
  /// screen previously read only the previous month's settlement, so it and the
  /// Payroll tab disagreed about the same worker's balance — ₹2,000 here versus
  /// ₹3,200 there. Two screens contradicting each other about money is worse
  /// than either being wrong on its own.
  ///
  /// Holding the full history also means [_shareStatement] needs no second trip.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final month = monthKey(_month);
    // Captured before the await: the wage is needed to price unsettled months.
    final worker = context.read<WorkerProvider>().byId(widget.workerId);

    try {
      final results = await Future.wait([
        _service.getAllAttendanceForWorker(widget.workerId),
        _service.getAllAdvancesForWorker(widget.workerId),
        _service.getAllSettlementsForWorker(widget.workerId),
      ]);

      final allAttendance = results[0] as List<Attendance>;
      final allAdvances = results[1] as List<Advance>;
      final allSettlements = results[2] as List<Settlement>;

      if (!mounted) return;
      setState(() {
        _allAttendance = allAttendance;
        _allAdvances = allAdvances;
        _allSettlements = allSettlements;

        _records = allAttendance.where((r) => r.month == month).toList();
        _advances = allAdvances.where((a) => a.month == month).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        _settlement = allSettlements
            .where((s) => s.month == month)
            .cast<Settlement?>()
            .firstWhere((s) => true, orElse: () => null);

        _opening = worker == null
            ? 0
            : openingBalances(
                    workers: [worker],
                    priorAttendance: allAttendance
                        .where((r) => r.month.compareTo(month) < 0)
                        .toList(),
                    priorAdvances: allAdvances
                        .where((a) => a.month.compareTo(month) < 0)
                        .toList(),
                    priorSettlements: allSettlements
                        .where((s) => s.month.compareTo(month) < 0)
                        .toList(),
                  )[widget.workerId] ??
                  0;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this worker\'s history.';
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = addMonths(_month, delta));
    _load();
  }

  /// Pick any two dates and share this worker's statement as a PDF.
  ///
  /// Deliberately not month-bound: the questions a crew actually asks are "what
  /// about the 12th to the 26th" or "since Diwali", and a worker added to the
  /// app days after joining has a first period that starts mid-month.
  Future<void> _shareStatement(Worker worker) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: firstOfMonth(_month),
        end: _month.year == now.year && _month.month == now.month
            ? now
            : DateTime(_month.year, _month.month, daysInMonth(_month)),
      ),
      helpText: 'Statement period',
      saveText: 'CREATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: DS.green,
            onPrimary: Colors.white,
            surface: DS.surface,
            onSurface: DS.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _buildingStatement = true);
    try {
      // The full history is already loaded, and is sliced in memory so a date
      // range doesn't need a composite index — "brought forward" falls out of
      // the same split for free.
      final statement = buildWorkerStatement(
        worker: worker,
        start: range.start,
        end: range.end,
        allAttendance: _allAttendance,
        allAdvances: _allAdvances,
        allSettlements: _allSettlements,
      );

      await ExportService().shareWorkerStatementPdf(statement);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not build the statement: $e'),
          backgroundColor: DS.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _buildingStatement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = context.watch<WorkerProvider>().byId(widget.workerId);

    if (worker == null) {
      return Scaffold(
        backgroundColor: DS.surface,
        appBar: AppBar(title: const Text('Worker')),
        body: const Center(child: Text('This worker no longer exists.')),
      );
    }

    final days = _records.fold(0.0, (sum, r) => sum + r.dayValue);
    final salary = roundRupees(days * worker.dailyWage);
    final advanceTotal = _advances.fold(0, (sum, a) => sum + a.amount);
    final paid = _settlement?.paid ?? 0;
    final balance = _opening + salary - advanceTotal - paid;

    return Scaffold(
      backgroundColor: DS.surface,
      body: Column(
        children: [
          _ProfileHeader(
            worker: worker,
            month: _month,
            onBack: () => Navigator.pop(context),
            onEdit: () => showWorkerForm(context, worker: worker),
            onPrevMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: DS.green),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: DS.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(_error!, style: DS.bodyMd),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: DS.green,
                    onRefresh: _load,
                    child: ListView(
                      // Clear the system navigation bar, which was clipping the
                      // SHARE STATEMENT button.
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        32 + MediaQuery.of(context).padding.bottom,
                      ),
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -20),
                          child: _AttendanceCard(
                            days: days,
                            records: _records,
                            month: _month,
                          ),
                        ),
                        _SalaryCard(
                          opening: _opening,
                          days: days,
                          dailyWage: worker.dailyWage,
                          salary: salary,
                          advances: advanceTotal,
                          paid: paid,
                          balance: balance,
                          isSettled: _settlement != null,
                        ),
                        const SizedBox(height: 16),
                        _AdvancesCard(advances: _advances),
                        const SizedBox(height: 24),
                        _ProfileActions(
                          buildingStatement: _buildingStatement,
                          onMarkAttendance: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AttendanceScreen(),
                              ),
                            );
                            await _load();
                          },
                          onShareStatement: () => _shareStatement(worker),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Header + Hero ──
class _ProfileHeader extends StatelessWidget {
  final Worker worker;
  final DateTime month;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _ProfileHeader({
    required this.worker,
    required this.month,
    required this.onBack,
    required this.onEdit,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = _WorkerBadge.colorFor(worker.type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 36),
      decoration: const BoxDecoration(color: DS.primaryContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Worker Profile',
                style: TextStyle(
                  fontFamily: DS.fontHeadline,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withAlpha(210),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (worker.type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(50),
                              borderRadius: BorderRadius.circular(
                                DS.radiusFull,
                              ),
                            ),
                            child: Text(
                              worker.type.toUpperCase(),
                              style: TextStyle(
                                fontFamily: DS.fontBody,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          '${rupees(worker.dailyWage)}/day',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                        if (!worker.isActive) ...[
                          const SizedBox(width: 10),
                          Text(
                            'ARCHIVED',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: DS.warning.withAlpha(220),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _WorkerBadge(worker: worker),
            ],
          ),
          const SizedBox(height: 20),
          // Month navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(DS.radiusFull),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  displayMonthLong(month).toUpperCase(),
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ──
class _WorkerBadge extends StatelessWidget {
  final Worker worker;
  const _WorkerBadge({required this.worker});

  static Color colorFor(String type) => _typeColor(type);

  @override
  Widget build(BuildContext context) {
    final color = colorFor(worker.type);
    final initial = worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withAlpha(45),
        borderRadius: BorderRadius.circular(DS.radiusXl),
        border: Border.all(color: Colors.white.withAlpha(25), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: DS.fontHeadline,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

Color _typeColor(String type) {
  final t = type.toLowerCase();
  if (t.contains('mason') || t.contains('mistri') || t.contains('raj')) {
    return DS.tertiary;
  }
  if (t.contains('helper') || t.contains('labour') || t.contains('beldar')) {
    return DS.green;
  }
  if (t.contains('carpenter') || t.contains('paint')) return DS.warning;
  if (t.contains('electric') || t.contains('wire')) return DS.reports;
  if (t.contains('plumb')) return DS.cyan;
  return DS.secondaryFixed;
}

// ── Attendance Card ──
class _AttendanceCard extends StatelessWidget {
  final double days;
  final List<Attendance> records;
  final DateTime month;

  const _AttendanceCard({
    required this.days,
    required this.records,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final total = daysInMonth(month);
    final marked = records.length;
    final progress = total == 0 ? 0.0 : (days / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE THIS MONTH',
                      style: DS.labelSm.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: formatDays(days),
                            style: const TextStyle(
                              fontFamily: DS.fontHeadline,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: DS.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ' / $total days',
                            style: const TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: DS.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$marked day(s) marked', style: DS.bodySm),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: DS.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DS.green,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DS.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MonthGrid(month: month, records: records),
        ],
      ),
    );
  }
}

// ── Month Grid ──
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<Attendance> records;

  const _MonthGrid({required this.month, required this.records});

  @override
  Widget build(BuildContext context) {
    final byDay = <int, String>{};
    for (final record in records) {
      final day = dayOfDateKey(record.date);
      if (day != null) byDay[day] = record.status;
    }

    final total = daysInMonth(month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;

    final cells = <Widget>[
      for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Center(
          child: Text(
            label,
            style: DS.labelSm.copyWith(
              color: DS.outline,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      for (var i = 1; i < firstWeekday; i++) const SizedBox(),
      for (var day = 1; day <= total; day++)
        _DayCell(day: day, status: byDay[day]),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final String? status;

  const _DayCell({required this.day, required this.status});

  @override
  Widget build(BuildContext context) {
    Color dot;
    switch (status) {
      case AttendanceStatus.present:
        dot = DS.green;
        break;
      case AttendanceStatus.absent:
        dot = DS.error;
        break;
      case AttendanceStatus.halfDay:
        dot = DS.warning;
        break;
      default:
        dot = Colors.transparent;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$day', style: DS.bodyMd.copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

// ── Salary Card ──
class _SalaryCard extends StatelessWidget {
  final int opening;
  final double days;
  final int dailyWage;
  final int salary;
  final int advances;
  final int paid;
  final int balance;
  final bool isSettled;

  const _SalaryCard({
    required this.opening,
    required this.days,
    required this.dailyWage,
    required this.salary,
    required this.advances,
    required this.paid,
    required this.balance,
    required this.isSettled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Salary Summary',
                style: DS.headlineMd.copyWith(fontSize: 18),
              ),
              if (isSettled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  child: Text(
                    'SETTLED',
                    style: DS.labelXs.copyWith(color: DS.green, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (opening != 0)
            _Line(
              label: 'Carried from last month',
              value: rupees(opening),
              valueColor: opening >= 0 ? DS.onSurface : DS.error,
            ),
          _Line(label: 'Days worked', value: formatDays(days)),
          _Line(label: 'Rate', value: '${rupees(dailyWage)}/day'),
          _Line(label: 'Salary', value: rupees(salary)),
          _Line(
            label: 'Advances (kharchi)',
            value: '- ${rupees(advances)}',
            valueColor: DS.warning,
          ),
          if (paid != 0)
            _Line(
              label: 'Paid',
              value: '- ${rupees(paid)}',
              valueColor: DS.tertiary,
            ),
          const SizedBox(height: 12),
          Container(height: 1, color: DS.surfaceContainerHigh),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance', style: DS.titleMd),
              Text(
                rupees(balance),
                style: TextStyle(
                  fontFamily: DS.fontHeadline,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: balance >= 0 ? DS.green : DS.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Line({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DS.bodyMd.copyWith(color: DS.onSurfaceVariant)),
          Text(
            value,
            style: DS.titleMd.copyWith(
              fontSize: 15,
              color: valueColor ?? DS.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Advances Card ──
class _AdvancesCard extends StatelessWidget {
  final List<Advance> advances;
  const _AdvancesCard({required this.advances});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Advances', style: DS.headlineMd.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          if (advances.isEmpty)
            Text('No advances this month', style: DS.bodySm)
          else
            ...advances.map(
              (advance) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DS.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: DS.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayDateKey(advance.date),
                        style: DS.bodyMd,
                      ),
                    ),
                    Text(
                      rupees(advance.amount),
                      style: DS.titleMd.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Actions ──
class _ProfileActions extends StatelessWidget {
  final bool buildingStatement;
  final VoidCallback onMarkAttendance;
  final VoidCallback onShareStatement;

  const _ProfileActions({
    required this.buildingStatement,
    required this.onMarkAttendance,
    required this.onShareStatement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: DS.buttonHeight,
          width: double.infinity,
          child: GestureDetector(
            onTap: onMarkAttendance,
            child: Container(
              decoration: BoxDecoration(
                gradient: DS.ctaGradient,
                borderRadius: BorderRadius.circular(DS.radiusXl),
                boxShadow: DS.buttonShadow,
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'MARK ATTENDANCE',
                    style: TextStyle(
                      fontFamily: DS.fontHeadline,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: DS.buttonHeight,
          width: double.infinity,
          child: GestureDetector(
            onTap: buildingStatement ? null : onShareStatement,
            child: Container(
              decoration: BoxDecoration(
                color: DS.primaryContainer,
                borderRadius: BorderRadius.circular(DS.radiusXl),
              ),
              alignment: Alignment.center,
              child: buildingStatement
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'SHARE STATEMENT',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick any two dates — presents, absents, advances and pending money.',
          textAlign: TextAlign.center,
          style: DS.bodySm.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
