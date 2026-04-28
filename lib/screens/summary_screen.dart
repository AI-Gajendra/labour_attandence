import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../providers/worker_provider.dart';
import '../providers/summary_provider.dart';
import '../models/worker.dart';
import '../models/attendance.dart';
import 'main_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    // Load data after the first frame so Provider context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final sp = context.read<SummaryProvider>();
    final workers = context.read<WorkerProvider>().workers;
    sp.loadData(workers);
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SummaryProvider>();
    final wp = context.watch<WorkerProvider>();
    final workers = wp.workers;

    return Scaffold(
      backgroundColor: DS.surface,
      body: Column(
        children: [
          // ── Dark Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            decoration: const BoxDecoration(color: DS.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final state = context.findAncestorStateOfType<MainScreenState>();
                        if (state != null) {
                          state.setIndex(0);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Summary',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SALARY REPORTS',
                          style: TextStyle(
                            fontFamily: DS.fontBody,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.white.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Month Navigator ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          sp.prevMonth();
                          sp.loadData(workers);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                        ),
                      ),
                      Text(
                        sp.displayMonth.toUpperCase(),
                        style: TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white.withAlpha(230),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          sp.nextMonth();
                          sp.loadData(workers);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: sp.isLoading
                ? const Center(child: CircularProgressIndicator(color: DS.green))
                : workers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assessment_outlined, size: 64, color: DS.outlineVariant),
                            const SizedBox(height: 16),
                            Text('No data available', style: DS.bodyMd.copyWith(color: DS.outline)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: DS.green,
                        onRefresh: () => sp.loadData(workers),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            // Per-worker cards
                            ...workers.map((w) {
                              final d = sp.data[w.workerId];
                              final days = (d?['days'] as double?) ?? 0;
                              final salary = (d?['salary'] as double?) ?? 0;
                              final advances = (d?['advances'] as double?) ?? 0;
                              final balance = salary - advances;
                              final recordsList = (d?['records'] as List<dynamic>?) ?? [];
                              final records = recordsList.cast<Attendance>();

                              return _WorkerSummaryCard(
                                worker: w,
                                days: days,
                                salary: salary,
                                advances: advances,
                                balance: balance,
                                onDaysTap: () {
                                  _showCalendarDialog(context, w, sp.currentMonth, records);
                                },
                              );
                            }),

                            const SizedBox(height: 12),

                            // ── Aggregate Footer ──
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: DS.primaryContainer,
                                borderRadius: BorderRadius.circular(DS.radiusLg),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AGGREGATE TOTALS',
                                    style: DS.labelSm.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      color: Colors.white.withAlpha(150),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: _FooterStat('DAYS', '${sp.totalDays % 1 == 0 ? sp.totalDays.toInt() : sp.totalDays}')),
                                      Expanded(child: _FooterStat('SALARY', '₹${sp.totalSalary.toStringAsFixed(0)}')),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: _FooterStat('ADVANCE', '₹${sp.totalAdvances.toStringAsFixed(0)}')),
                                      Expanded(
                                        child: _FooterStat(
                                          'BALANCE',
                                          '₹${sp.totalBalance.toStringAsFixed(0)}',
                                          valueColor: sp.totalBalance >= 0 ? DS.green : DS.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

// ── Worker Summary Card (2x2 stat grid) ──
class _WorkerSummaryCard extends StatelessWidget {
  final Worker worker;
  final double days;
  final double salary;
  final double advances;
  final double balance;
  final VoidCallback? onDaysTap;

  const _WorkerSummaryCard({
    required this.worker,
    required this.days,
    required this.salary,
    required this.advances,
    required this.balance,
    this.onDaysTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name, style: DS.titleMd),
                  const SizedBox(height: 2),
                  Text(
                    '${worker.type} • ₹${worker.dailyWage.toStringAsFixed(0)}/day',
                    style: DS.bodySm,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: balance >= 0 ? DS.green.withAlpha(25) : DS.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(DS.radiusFull),
                ),
                child: Text(
                  '₹${balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: balance >= 0 ? DS.green : DS.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: DS.surfaceContainerHigh),
          const SizedBox(height: 16),
          // 2x2 Stat Grid
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDaysTap,
                  child: _StatCell('DAYS', '${days % 1 == 0 ? days.toInt() : days}', DS.tertiary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _StatCell('SALARY', '₹${salary.toStringAsFixed(0)}', DS.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCell('ADVANCE', '₹${advances.toStringAsFixed(0)}', const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  'BALANCE',
                  '₹${balance.toStringAsFixed(0)}',
                  balance >= 0 ? DS.green : DS.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat Cell ──
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatCell(this.label, this.value, this.accent);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(12),
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: DS.fontBody,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: DS.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer Stat (dark bg) ──
class _FooterStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _FooterStat(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: DS.fontBody,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withAlpha(130),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: DS.fontHeadline,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Calendar Dialog ──
void _showCalendarDialog(BuildContext context, Worker worker, DateTime month, List<Attendance> records) {
  // Convert records list to a map of { day: status }
  final Map<int, String> recordMap = {};
  for (var r in records) {
    // r.date is "YYYY-MM-DD", let's split and parse day
    final parts = r.date.split('-');
    if (parts.length == 3) {
      final d = int.tryParse(parts[2]);
      if (d != null) {
        recordMap[d] = r.status;
      }
    }
  }

  // How many days in the month?
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  final daysInMonth = nextMonth.subtract(const Duration(days: 1)).day;

  // Find weekday of the 1st
  final firstDay = DateTime(month.year, month.month, 1);
  final weekday = firstDay.weekday; // 1=Mon, 7=Sun

  // Generate grid items
  final items = <Widget>[];
  final weekdaysStr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  for (var w in weekdaysStr) {
    items.add(Center(
      child: Text(w, style: DS.labelSm.copyWith(color: DS.outline, fontWeight: FontWeight.bold)),
    ));
  }

  // Add empty spaces for offset
  for (int i = 1; i < weekday; i++) {
    items.add(const SizedBox());
  }

  // Add days
  for (int i = 1; i <= daysInMonth; i++) {
    final status = recordMap[i];
    Color dotColor = Colors.transparent;
    if (status == 'present') {
      dotColor = DS.green;
    } else if (status == 'absent') {
      dotColor = DS.error;
    } else if (status == 'half_day') {
      dotColor = const Color(0xFFF59E0B);
    }

    items.add(
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$i', style: DS.bodyMd.copyWith(color: DS.onSurface, fontSize: 13)),
          const SizedBox(height: 2),
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: DS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${worker.name} - Attendance', style: DS.titleMd),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: items,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: DS.green,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontFamily: DS.fontHeadline, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
