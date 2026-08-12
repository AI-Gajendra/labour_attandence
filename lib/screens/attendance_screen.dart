import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../models/attendance.dart';
import '../models/worker.dart';
import '../providers/attendance_provider.dart';
import '../providers/worker_provider.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/sync_banner.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AttendanceProvider>().loadForDate(DateTime.now());
      }
    });
  }

  void _showErrorIfAny(AttendanceProvider ap) {
    final error = ap.error;
    if (error == null) return;
    // Surface the failure instead of letting the optimistic tick lie.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error), backgroundColor: DS.error));
      ap.clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkerProvider>();
    final ap = context.watch<AttendanceProvider>();
    final workers = wp.workers;

    _showErrorIfAny(ap);

    final selected = ap.selectedDate;
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
                decoration: const BoxDecoration(color: DS.primaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
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
                                displayFullDate(selected),
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
                        ),
                        GestureDetector(
                          onTap: () => _pickDate(context, ap),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _GesturePill(),
                  ],
                ),
              ),

              // ── Team Availability Card ──
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

              // ── Worker List ──
              Expanded(
                child: wp.isLoading || ap.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: DS.green),
                      )
                    : workers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: DS.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workers found',
                              style: DS.bodyMd.copyWith(color: DS.outline),
                            ),
                            const SizedBox(height: 4),
                            Text('Add workers first', style: DS.bodySm),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: DS.green,
                        onRefresh: () => ap.loadForDate(ap.selectedDate),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            0,
                            0,
                            110 + bottomPad,
                          ),
                          itemCount: workers.length,
                          itemBuilder: (context, index) =>
                              _AttendanceRow(worker: workers[index]),
                        ),
                      ),
              ),

              const SyncBanner(),
            ],
          ),

          // ── Floating Done Button ──
          //
          // Marks are written the instant a gesture happens, so this never was
          // a save button. It now reads "Done" and the overlay reports what
          // actually happened rather than always claiming success.
          Positioned(
            bottom: 24 + bottomPad,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  await ap.triggerSavedOverlay();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: DS.primaryContainer,
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                    boxShadow: DS.cardShadow,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'DONE',
                        style: TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Confirmation Overlay ──
          if (ap.showSaved)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withAlpha(120),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 32,
                    ),
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
                          child: const Icon(
                            Icons.check_circle,
                            color: DS.green,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Attendance Recorded',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: DS.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ap.savedMessage,
                          textAlign: TextAlign.center,
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

  Future<void> _pickDate(BuildContext context, AttendanceProvider ap) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ap.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    if (picked != null && !isSameDay(picked, ap.selectedDate)) {
      await ap.loadForDate(picked);
    }
  }
}

// ── Gesture Guide Pill ──
class _GesturePill extends StatelessWidget {
  const _GesturePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(DS.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pair('TAP ', 'FULL', DS.green),
          _divider(),
          _pair('HOLD ', 'ABSENT', DS.error.withAlpha(230)),
          _divider(),
          _pair('SWIPE ', 'HALF', DS.warning),
        ],
      ),
    );
  }

  Widget _pair(String prefix, String value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        prefix,
        style: TextStyle(
          fontFamily: DS.fontBody,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withAlpha(180),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: DS.fontBody,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  Widget _divider() => Container(
    width: 1,
    height: 14,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: Colors.white.withAlpha(60),
  );
}

// ── Availability Card ──
class _AvailabilityCard extends StatelessWidget {
  final int total;
  final int marked;
  final int present;
  final int halfDay;

  const _AvailabilityCard({
    required this.total,
    required this.marked,
    required this.present,
    this.halfDay = 0,
  });

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
            style: DS.labelSm.copyWith(
              fontSize: 10,
              letterSpacing: 1.5,
              color: DS.onSurfaceVariant,
            ),
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
                      style: const TextStyle(
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
                          color: DS.warning,
                        ),
                      ),
                    TextSpan(
                      text: '/$total',
                      style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

// ── Attendance Row ──
class _AttendanceRow extends StatelessWidget {
  final Worker worker;

  const _AttendanceRow({required this.worker});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AttendanceProvider>();
    final status = ap.statusOf(worker.workerId);

    Color bgColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    Widget statusIcon;

    switch (status) {
      case AttendanceStatus.present:
        bgColor = DS.green.withAlpha(12);
        borderColor = DS.green;
        statusIcon = _badge(
          DS.green,
          const Icon(Icons.check, color: Colors.white, size: 20),
        );
        break;
      case AttendanceStatus.absent:
        bgColor = DS.error.withAlpha(12);
        borderColor = DS.error;
        statusIcon = _badge(
          DS.error,
          const Icon(Icons.close, color: Colors.white, size: 20),
        );
        break;
      case AttendanceStatus.halfDay:
        bgColor = DS.warning.withAlpha(12);
        borderColor = DS.warning;
        statusIcon = _badge(
          DS.warning,
          const Center(
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
        break;
      default:
        statusIcon = Container(
          width: 36,
          height: 36,
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
        ap.mark(worker.workerId, AttendanceStatus.halfDay);
        return false; // keep the row in place
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: DS.warning.withAlpha(25),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HALF DAY',
              style: TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DS.warning,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DS.warning,
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
        onTap: () => ap.mark(worker.workerId, AttendanceStatus.present),
        onLongPress: () => ap.mark(worker.workerId, AttendanceStatus.absent),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left: BorderSide(
                color: borderColor,
                width: status != null ? 4 : 0,
              ),
            ),
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
                        fontFamily: DS.fontHeadline,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DS.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.type} • ${rupees(worker.dailyWage)}/day',
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

  Widget _badge(Color color, Widget child) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(DS.radiusFull),
    ),
    child: child,
  );
}
