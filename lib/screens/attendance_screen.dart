import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../providers/worker_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/worker.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Load attendance for today by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AttendanceProvider>().loadForDate(DateTime.now());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkerProvider>();
    final ap = context.watch<AttendanceProvider>();
    final workers = wp.workers;

    final now = ap.selectedDate;
    final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final displayDate = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: DS.surface,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Dark Header with date + interaction guide ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                decoration: const BoxDecoration(
                  color: DS.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mark Attendance',
                              style: TextStyle(
                                fontFamily: DS.fontHeadline,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayDate,
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
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: ap.selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: DS.green,
                                      onPrimary: Colors.white,
                                      surface: DS.surface,
                                      onSurface: DS.onSurface,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != ap.selectedDate) {
                              ap.loadForDate(picked);
                            }
                          },
                          child: const Icon(Icons.calendar_today, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Interaction Guide Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(DS.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TAP ',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          const Text(
                            'FULL',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: DS.green,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: Colors.white.withAlpha(60),
                          ),
                          Text(
                            'HOLD ',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          Text(
                            'ABSENT',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: DS.error.withAlpha(230),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: Colors.white.withAlpha(60),
                          ),
                          Text(
                            'SWIPE ',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          const Text(
                            'HALF',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Team Availability Card (from Provider) ──
              Transform.translate(
                offset: const Offset(0, -12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AvailabilityCard(
                    total: workers.length,
                    marked: ap.markedCount,
                    present: ap.presentCount,
                    halfDay: ap.halfDayCount,
                  ),
                ),
              ),

              // ── Worker List (from Provider) ──
              Expanded(
                child: wp.isLoading || ap.isLoading
                    ? const Center(child: CircularProgressIndicator(color: DS.green))
                    : workers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: DS.outlineVariant),
                                const SizedBox(height: 16),
                                Text('No workers found', style: DS.bodyMd.copyWith(color: DS.outline)),
                                const SizedBox(height: 4),
                                Text('Add workers first', style: DS.bodySm),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: DS.green,
                            onRefresh: () => ap.loadForDate(ap.selectedDate),
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, 100 + bottomPad),
                              itemCount: workers.length,
                              itemBuilder: (context, index) {
                                return _AttendanceRow(
                                  worker: workers[index],
                                  date: dateStr,
                                  month: monthStr,
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),

          // ── Floating Save Button ──
          Positioned(
            bottom: 24 + bottomPad,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  await ap.triggerSavedOverlay();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: DS.primaryContainer,
                    borderRadius: BorderRadius.circular(DS.radiusXl),
                    boxShadow: DS.cardShadow,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),

          // ── Success Overlay ──
          if (ap.showSaved)
            AnimatedOpacity(
              opacity: ap.showSaved ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withAlpha(120),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    decoration: BoxDecoration(
                      color: DS.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: DS.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: DS.green.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: DS.green, size: 48),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Attendance Saved!',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: DS.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All records have been updated',
                          style: DS.bodySm.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Availability Card (now driven by Provider counts) ──
class _AvailabilityCard extends StatelessWidget {
  final int total;
  final int marked;
  final int present;
  final int halfDay;
  const _AvailabilityCard({required this.total, required this.marked, required this.present, this.halfDay = 0});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (marked / total * 100).round() : 0;
    final progress = total > 0 ? marked / total : 0.0;

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
          Text(
            'TEAM AVAILABILITY',
            style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5, color: DS.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$present',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: DS.onSurface,
                      ),
                    ),
                    if (halfDay > 0)
                      TextSpan(
                        text: '+$halfDay½',
                        style: const TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    TextSpan(
                      text: '/$total',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: DS.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DS.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(DS.radiusFull),
                ),
                child: Text(
                  '$pct% Marked',
                  style: DS.labelXs.copyWith(color: DS.green, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: DS.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(DS.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attendance Row (uses AttendanceProvider for state) ──
class _AttendanceRow extends StatelessWidget {
  final Worker worker;
  final String date;
  final String month;

  const _AttendanceRow({
    required this.worker,
    required this.date,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AttendanceProvider>();
    final status = ap.statusOf(worker.workerId);

    const Color halfDayColor = Color(0xFFF59E0B);
    Color bgColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    Widget statusIcon;

    if (status == 'present') {
      bgColor = DS.green.withAlpha(12);
      borderColor = DS.green;
      statusIcon = Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: DS.green, borderRadius: BorderRadius.circular(DS.radiusFull)),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
      );
    } else if (status == 'absent') {
      bgColor = DS.error.withAlpha(12);
      borderColor = DS.error;
      statusIcon = Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: DS.error, borderRadius: BorderRadius.circular(DS.radiusFull)),
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      );
    } else if (status == 'half_day') {
      bgColor = halfDayColor.withAlpha(12);
      borderColor = halfDayColor;
      statusIcon = Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: halfDayColor, borderRadius: BorderRadius.circular(DS.radiusFull)),
        child: const Center(
          child: Text(
            '½',
            style: TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      statusIcon = Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: DS.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(DS.radiusFull),
        ),
      );
    }

    return Dismissible(
      key: ValueKey('dismiss_${worker.workerId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        ap.mark(worker.workerId, date, month, 'half_day');
        return false; // don't remove the row
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: halfDayColor.withAlpha(25),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HALF DAY',
              style: TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: halfDayColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: halfDayColor,
                borderRadius: BorderRadius.circular(DS.radiusFull),
              ),
              child: const Center(
                child: Text(
                  '½',
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      child: InkWell(
        onTap: () => ap.mark(worker.workerId, date, month, 'present'),
        onLongPress: () => ap.mark(worker.workerId, date, month, 'absent'),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(left: BorderSide(color: borderColor, width: status != null ? 4 : 0)),
          ),
          padding: EdgeInsets.fromLTRB(status != null ? 20 : 24, 18, 24, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontFamily: DS.fontHeadline, fontSize: 18,
                        fontWeight: FontWeight.w700, color: DS.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.type} • ₹${worker.dailyWage.toStringAsFixed(0)}/day',
                      style: DS.bodySm.copyWith(color: DS.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              statusIcon,
            ],
          ),
        ),
      ),
    );
  }
}
