import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design_tokens.dart';
import '../models/monthly_row.dart';
import '../models/settlement.dart';
import '../providers/summary_provider.dart';
import '../providers/worker_provider.dart';
import '../services/export_service.dart';
import '../utils/money.dart';
import 'main_screen.dart';
import 'pdf_preview_screen.dart';
import 'worker_profile_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  /// Worker set this screen last loaded for.
  ///
  /// This tab lives inside the shell's IndexedStack, so it is built while
  /// `WorkerProvider` is still streaming and its first load sees an empty crew.
  /// Watching the signature means the payroll reloads by itself the moment the
  /// workers land — and again whenever one is added or archived — instead of
  /// sitting on an empty month until someone pulls to refresh.
  String? _loadedSignature;

  void _reloadIfWorkersChanged(WorkerProvider wp) {
    if (wp.isLoading) return;
    final signature = wp.workers.map((w) => w.workerId).join(',');
    if (signature == _loadedSignature) return;
    _loadedSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload({bool force = false}) {
    final sp = context.read<SummaryProvider>();
    final workers = context.read<WorkerProvider>().workers;
    sp.loadData(workers, force: force);
  }

  Future<void> _export(bool asPdf) async {
    final sp = context.read<SummaryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final export = ExportService();
    try {
      if (asPdf) {
        // Preview first — the share sheet used to fire before anyone had seen
        // the document.
        final bytes = await export.buildPayrollPdf(
          month: sp.monthStr,
          rows: sp.rows,
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              title: 'Payroll',
              subtitle: sp.displayMonth.toUpperCase(),
              bytes: bytes,
              fileName: 'payroll-${sp.monthStr}.pdf',
              onShare: () => export.sharePdfBytes(
                bytes: bytes,
                fileName: 'payroll-${sp.monthStr}.pdf',
                subject: 'Payroll ${sp.displayMonth}',
              ),
            ),
          ),
        );
      } else {
        // CSV has nothing to preview — straight to the share sheet.
        await export.sharePayrollCsv(month: sp.monthStr, rows: sp.rows);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: DS.error),
      );
    }
  }

  Future<void> _settle(MonthlyRow row) async {
    final sp = context.read<SummaryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<_SettleResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettleSheet(row: row, month: sp.displayMonth),
    );
    if (result == null) return;

    try {
      await sp.settle(row, result.amount, mode: result.mode, note: result.note);
      if (!mounted) return;
      _reload(force: true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${rupees(result.amount)} paid to ${row.worker.name}. '
            'Balance carried forward: ${rupees(row.opening + row.salary - row.advances - result.amount)}',
          ),
          backgroundColor: DS.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not record the payment: $e'),
          backgroundColor: DS.error,
        ),
      );
    }
  }

  Future<void> _reopen(MonthlyRow row) async {
    final sp = context.read<SummaryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reopen ${sp.displayMonth}?'),
        content: Text(
          'This removes the recorded payment for ${row.worker.name} and the '
          'balance carried into next month will change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: DS.error),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await sp.unsettle(row.worker.workerId);
      if (!mounted) return;
      _reload(force: true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not reopen: $e'),
          backgroundColor: DS.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SummaryProvider>();
    final wp = context.watch<WorkerProvider>();

    _reloadIfWorkersChanged(wp);

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
                        final state = context
                            .findAncestorStateOfType<MainScreenState>();
                        if (state != null) {
                          state.setIndex(0);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Summary',
                            style: TextStyle(
                              fontFamily: DS.fontHeadline,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'SALARY REPORTS',
                            style: TextStyle(
                              fontFamily: DS.fontBody,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Export — the app had no way to get data out at all.
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.ios_share,
                        color: Colors.white,
                        size: 22,
                      ),
                      onSelected: (value) => _export(value == 'pdf'),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'pdf',
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf_outlined),
                            title: Text('Share as PDF'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'csv',
                          child: ListTile(
                            leading: Icon(Icons.table_chart_outlined),
                            title: Text('Share as CSV'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Month Navigator ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MonthArrow(
                        icon: Icons.chevron_left,
                        onTap: () {
                          sp.prevMonth();
                          _reload();
                        },
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
                      _MonthArrow(
                        icon: Icons.chevron_right,
                        onTap: () {
                          sp.nextMonth();
                          _reload();
                        },
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
                ? const Center(
                    child: CircularProgressIndicator(color: DS.green),
                  )
                : sp.error != null
                ? _SummaryError(
                    message: sp.error!,
                    onRetry: () => _reload(force: true),
                  )
                : wp.workers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assessment_outlined,
                          size: 64,
                          color: DS.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No data available',
                          style: DS.bodyMd.copyWith(color: DS.outline),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: DS.green,
                    onRefresh: () async => _reload(force: true),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        ...sp.rows.map(
                          (row) => _WorkerSummaryCard(
                            row: row,
                            onOpenProfile: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkerProfileScreen(
                                  workerId: row.worker.workerId,
                                ),
                              ),
                            ),
                            onSettle: () => _settle(row),
                            onReopen: () => _reopen(row),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AggregateFooter(sp: sp),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Month Arrow ──
class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Error State ──
class _SummaryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SummaryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: DS.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DS.bodyMd.copyWith(color: DS.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

// ── Worker Summary Card ──
class _WorkerSummaryCard extends StatelessWidget {
  final MonthlyRow row;
  final VoidCallback onOpenProfile;
  final VoidCallback onSettle;
  final VoidCallback onReopen;

  const _WorkerSummaryCard({
    required this.row,
    required this.onOpenProfile,
    required this.onSettle,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final positive = row.balance >= 0;

    return GestureDetector(
      onTap: onOpenProfile,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.worker.name, style: DS.titleMd),
                      const SizedBox(height: 2),
                      Text(
                        // The rate for *this month*, not today's.
                        '${row.worker.type} • '
                        '${rateLabel(row.ratesApplied, fallback: row.rate)}',
                        style: DS.bodySm,
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
                    color: (positive ? DS.green : DS.error).withAlpha(25),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  child: Text(
                    rupees(row.balance),
                    style: TextStyle(
                      fontFamily: DS.fontHeadline,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: positive ? DS.green : DS.error,
                    ),
                  ),
                ),
              ],
            ),

            // Carry-forward line. Previously each month restarted from zero, so
            // an over-drawn worker's debt silently vanished at the boundary.
            if (row.opening != 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DS.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      row.opening >= 0
                          ? Icons.arrow_downward
                          : Icons.warning_amber_rounded,
                      size: 14,
                      color: row.opening >= 0 ? DS.outline : DS.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Carried from last month',
                        style: DS.bodySm.copyWith(fontSize: 12),
                      ),
                    ),
                    Text(
                      rupees(row.opening),
                      style: DS.titleMd.copyWith(
                        fontSize: 13,
                        color: row.opening >= 0 ? DS.onSurface : DS.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(height: 1, color: DS.surfaceContainerHigh),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatCell('DAYS', formatDays(row.days), DS.tertiary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCell('SALARY', rupees(row.salary), DS.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCell('ADVANCE', rupees(row.advances), DS.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCell(
                    row.isSettled ? 'PAID' : 'BALANCE',
                    rupees(row.isSettled ? row.paid : row.balance),
                    row.isSettled
                        ? DS.tertiary
                        : (positive ? DS.green : DS.error),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: row.isSettled
                  ? OutlinedButton.icon(
                      onPressed: onReopen,
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: const Text('SETTLED — REOPEN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DS.onSurfaceVariant,
                        side: BorderSide(color: DS.outlineVariant),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onSettle,
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('RECORD PAYMENT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DS.primaryContainer,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aggregate Footer ──
class _AggregateFooter extends StatelessWidget {
  final SummaryProvider sp;
  const _AggregateFooter({required this.sp});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Expanded(child: _FooterStat('DAYS', formatDays(sp.totalDays))),
              Expanded(child: _FooterStat('SALARY', rupees(sp.totalSalary))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _FooterStat('ADVANCE', rupees(sp.totalAdvances))),
              Expanded(child: _FooterStat('PAID', rupees(sp.totalPaid))),
            ],
          ),
          const SizedBox(height: 16),
          _FooterStat(
            'STILL OWED',
            rupees(sp.totalBalance),
            valueColor: sp.totalBalance >= 0 ? DS.green : DS.error,
          ),
        ],
      ),
    );
  }
}

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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Settle Sheet ──

class _SettleResult {
  final int amount;
  final String mode;
  final String note;
  const _SettleResult(this.amount, this.mode, this.note);
}

class _SettleSheet extends StatefulWidget {
  final MonthlyRow row;
  final String month;

  const _SettleSheet({required this.row, required this.month});

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  String _mode = Settlement.modeCash;

  @override
  void initState() {
    super.initState();
    // Default to paying off the full balance — the common case.
    _amountCtrl = TextEditingController(
      text: widget.row.balance > 0 ? '${widget.row.balance}' : '0',
    );
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final entered = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final carried = row.opening + row.salary - row.advances - entered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: DS.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: DS.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'RECORD PAYMENT · ${widget.month.toUpperCase()}',
              style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            Text(row.worker.name, style: DS.headlineMd),
            const SizedBox(height: 20),

            _Breakdown(row: row),

            const SizedBox(height: 20),
            Text(
              'AMOUNT PAID (₹)',
              style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            Container(
              height: DS.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: DS.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: DS.fontHeadline,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: DS.onSurface,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'PAID BY',
              style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _modeChip(Settlement.modeCash, 'CASH', Icons.payments_outlined),
                const SizedBox(width: 8),
                _modeChip(Settlement.modeUpi, 'UPI', Icons.qr_code),
                const SizedBox(width: 8),
                _modeChip(
                  Settlement.modeBank,
                  'BANK',
                  Icons.account_balance_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                filled: true,
                fillColor: DS.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (carried == 0 ? DS.green : DS.warning).withAlpha(20),
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    carried == 0 ? Icons.check_circle : Icons.east,
                    size: 16,
                    color: carried == 0 ? DS.green : DS.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      carried == 0
                          ? 'Settled in full — nothing carried forward.'
                          : 'Carried to next month: ${rupees(carried)}',
                      style: DS.bodySm.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
                if (amount < 0) return;
                Navigator.pop(
                  context,
                  _SettleResult(amount, _mode, _noteCtrl.text.trim()),
                );
              },
              child: Container(
                height: DS.buttonHeight,
                decoration: BoxDecoration(
                  gradient: DS.ctaGradient,
                  borderRadius: BorderRadius.circular(DS.radiusXl),
                  boxShadow: DS.buttonShadow,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'SAVE PAYMENT',
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = value),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? DS.green.withAlpha(25) : DS.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: selected
                ? Border.all(color: DS.green.withAlpha(90), width: 2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? DS.green : DS.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: DS.labelXs.copyWith(
                  fontSize: 11,
                  color: selected ? DS.green : DS.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settlement Breakdown ──
class _Breakdown extends StatelessWidget {
  final MonthlyRow row;
  const _Breakdown({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Column(
        children: [
          if (row.opening != 0)
            _line('Carried from last month', rupees(row.opening)),
          _line(
            row.hasMixedRates
                ? '${formatDays(row.days)} days (rate changed)'
                : '${formatDays(row.days)} days × ${rupees(row.rate)}',
            rupees(row.salary),
          ),
          _line('Advances taken', '- ${rupees(row.advances)}'),
          const SizedBox(height: 8),
          Container(height: 1, color: DS.surfaceContainerHighest),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Due now', style: DS.titleMd.copyWith(fontSize: 14)),
              Text(
                rupees(row.opening + row.salary - row.advances),
                style: DS.titleMd.copyWith(fontSize: 16, color: DS.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DS.bodySm.copyWith(fontSize: 12)),
        Text(value, style: DS.bodyMd.copyWith(fontSize: 13)),
      ],
    ),
  );
}
