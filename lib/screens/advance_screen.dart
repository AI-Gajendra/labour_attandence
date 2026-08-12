import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../services/firestore_service.dart';
import '../services/sync_status.dart';
import '../providers/worker_provider.dart';
import '../models/worker.dart';
import '../models/advance.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import 'main_screen.dart';

class AdvanceScreen extends StatefulWidget {
  const AdvanceScreen({super.key});

  @override
  State<AdvanceScreen> createState() => _AdvanceScreenState();
}

class _AdvanceScreenState extends State<AdvanceScreen> {
  Worker? _selectedWorker;
  String _amount = '';
  DateTime _selectedDate = DateTime.now();
  List<Advance> _recentAdvances = [];
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadRecentAdvances();
  }

  Future<void> _loadRecentAdvances() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final advances = await FirestoreService().getAdvancesForMonth(
        monthKey(DateTime.now()),
      );
      // Newest first — the list is a running log, not an arbitrary dump.
      advances.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _recentAdvances = advances;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = 'Could not load this month\'s advances.';
        _loadingHistory = false;
      });
    }
  }

  String _getWorkerName(String workerId) =>
      context.read<WorkerProvider>().nameOf(workerId);

  Future<void> _saveAdvance() async {
    final worker = _selectedWorker;
    if (worker == null) {
      _toast('Choose a worker first', DS.warning);
      return;
    }
    final value = int.tryParse(_amount);
    if (value == null || value <= 0) {
      _toast('Enter an amount', DS.warning);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      // Audit logging now happens inside FirestoreService, linked to the real
      // document id — this screen used to log it separately with an empty id.
      await SyncStatus.instance.track(
        FirestoreService().addAdvance(
          worker.workerId,
          value,
          dateKey(_selectedDate),
          monthKey(_selectedDate),
        ),
        description: 'Recording advance',
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Advance of ${rupees(value)} recorded for ${worker.name}',
          ),
          backgroundColor: DS.green,
        ),
      );
      setState(() {
        _amount = '';
        _selectedWorker = null;
      });
      _loadRecentAdvances();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not record the advance: $e'),
          backgroundColor: DS.error,
        ),
      );
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _appendDigit(String digit) {
    setState(() {
      if (digit == '⌫') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (digit == 'C') {
        _amount = '';
      } else {
        if (_amount.length < 7) _amount += digit;
      }
    });
  }

  Future<void> _editAdvance(Advance adv) async {
    String editAmount = '${adv.amount}';
    DateTime editDate = parseDateKey(adv.date) ?? DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final dateStr = displayDayMonth(editDate);

            return Dialog(
              backgroundColor: DS.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.radiusXl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Advance', style: DS.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      'Worker: ${_getWorkerName(adv.workerId)}',
                      style: DS.bodySm,
                    ),
                    const SizedBox(height: 20),

                    // Amount field
                    Text(
                      'AMOUNT',
                      style: DS.labelSm.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: DS.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '₹',
                            style: TextStyle(
                              fontFamily: DS.fontHeadline,
                              fontSize: 20,
                              color: DS.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: editAmount,
                              keyboardType: TextInputType.number,
                              style: DS.titleLg.copyWith(fontSize: 20),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                              onChanged: (val) => editAmount = val,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: editDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => editDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DS.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: DS.tertiary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              dateStr,
                              style: DS.titleMd.copyWith(fontSize: 14),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: DS.outlineVariant,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, null),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: DS.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  DS.radiusMd,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'CANCEL',
                                style: DS.labelLg.copyWith(
                                  color: DS.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final val = int.tryParse(editAmount);
                              if (val == null || val <= 0) return;
                              Navigator.pop(ctx, {
                                'amount': val,
                                'date': editDate,
                              });
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: DS.ctaGradient,
                                borderRadius: BorderRadius.circular(
                                  DS.radiusMd,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'SAVE',
                                style: TextStyle(
                                  fontFamily: DS.fontHeadline,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    if (!mounted) return;
    final newAmount = result['amount'] as int;
    final newDate = result['date'] as DateTime;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await SyncStatus.instance.track(
        FirestoreService().updateAdvance(
          adv.advanceId,
          newAmount,
          dateKey(newDate),
          monthKey(newDate),
        ),
        description: 'Updating advance',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Advance updated'),
          backgroundColor: DS.green,
        ),
      );
      _loadRecentAdvances();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update the advance: $e'),
          backgroundColor: DS.error,
        ),
      );
    }
  }

  Future<void> _deleteAdvance(Advance adv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Advance?'),
        content: Text(
          'Delete the ${rupees(adv.amount)} advance for ${_getWorkerName(adv.workerId)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: DS.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await SyncStatus.instance.track(
        FirestoreService().deleteAdvance(adv.advanceId),
        description: 'Deleting advance',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Advance deleted'),
          backgroundColor: DS.error,
        ),
      );
      _loadRecentAdvances();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not delete the advance: $e'),
          backgroundColor: DS.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = displayDayMonth(_selectedDate);

    return Scaffold(
      backgroundColor: DS.surface,
      body: Column(
        children: [
          // ── Dark Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            decoration: const BoxDecoration(color: DS.primaryContainer),
            child: Row(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Advance',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PAYROLL ADJUSTMENT',
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
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Worker Picker ──
                  Container(
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
                          'SELECT WORKER',
                          style: DS.labelSm.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer<WorkerProvider>(
                          builder: (context, wp, _) {
                            final workers = wp.workers;
                            if (workers.isEmpty) {
                              return Text(
                                'No workers available',
                                style: DS.bodySm,
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: workers.map((w) {
                                final isSelected =
                                    _selectedWorker?.workerId == w.workerId;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedWorker = w),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? DS.green.withAlpha(25)
                                          : DS.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(
                                        DS.radiusFull,
                                      ),
                                      border: isSelected
                                          ? Border.all(
                                              color: DS.green.withAlpha(80),
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: DS.green,
                                              size: 16,
                                            ),
                                          ),
                                        Text(
                                          w.name,
                                          style: TextStyle(
                                            fontFamily: DS.fontHeadline,
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? DS.green
                                                : DS.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Amount Display ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: DS.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(DS.radiusLg),
                      boxShadow: DS.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ADVANCE AMOUNT',
                          style: DS.labelSm.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '₹',
                              style: TextStyle(
                                fontFamily: DS.fontHeadline,
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: DS.outline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _amount.isEmpty ? '0' : _amount,
                              style: TextStyle(
                                fontFamily: DS.fontHeadline,
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: _amount.isEmpty
                                    ? DS.outlineVariant
                                    : DS.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Date Selector ──
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: DS.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(DS.radiusLg),
                        boxShadow: DS.cardShadowLight,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: DS.tertiary.withAlpha(25),
                              borderRadius: BorderRadius.circular(DS.radiusLg),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: DS.tertiary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DATE',
                                style: DS.labelSm.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateDisplay,
                                style: DS.titleMd.copyWith(fontSize: 15),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: DS.outlineVariant,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Calculator Keypad ──
                  _Keypad(onDigit: _appendDigit),

                  const SizedBox(height: 20),

                  // ── Save Button ──
                  GestureDetector(
                    onTap: _saveAdvance,
                    child: Container(
                      width: double.infinity,
                      height: DS.buttonHeight,
                      decoration: BoxDecoration(
                        gradient: DS.ctaGradient,
                        borderRadius: BorderRadius.circular(DS.radiusXl),
                        boxShadow: DS.buttonShadow,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'RECORD ADVANCE',
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

                  const SizedBox(height: 28),

                  // ── Recent Advances (This Month) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT ADVANCES',
                        style: DS.labelSm.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadRecentAdvances,
                        child: Icon(Icons.refresh, size: 18, color: DS.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_loadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: DS.green,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_historyError != null)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: DS.error.withAlpha(15),
                        borderRadius: BorderRadius.circular(DS.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: DS.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _historyError!,
                              style: DS.bodySm.copyWith(color: DS.error),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadRecentAdvances,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    )
                  else if (_recentAdvances.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: DS.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(DS.radiusLg),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 36,
                              color: DS.outlineVariant,
                            ),
                            const SizedBox(height: 8),
                            Text('No advances this month', style: DS.bodySm),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recentAdvances.map((adv) {
                      final workerName = _getWorkerName(adv.workerId);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DS.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(DS.radiusLg),
                          boxShadow: DS.cardShadowLight,
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: DS.warning.withAlpha(20),
                                borderRadius: BorderRadius.circular(
                                  DS.radiusMd,
                                ),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                color: DS.warning,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workerName,
                                    style: DS.titleMd.copyWith(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayDateKey(adv.date),
                                    style: DS.bodySm.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            Text(
                              rupees(adv.amount),
                              style: DS.titleMd.copyWith(
                                fontSize: 16,
                                color: DS.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Edit
                            GestureDetector(
                              onTap: () => _editAdvance(adv),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: DS.tertiary.withAlpha(15),
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusMd,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: DS.tertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Delete
                            GestureDetector(
                              onTap: () => _deleteAdvance(adv),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: DS.error.withAlpha(15),
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusMd,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: DS.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calculator Keypad ──
class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  const _Keypad({required this.onDigit});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              final isAction = key == 'C' || key == '⌫';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onDigit(key),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: isAction
                            ? DS.surfaceContainerHigh
                            : DS.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(DS.radiusLg),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        key,
                        style: TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: isAction ? 16 : 22,
                          fontWeight: FontWeight.w700,
                          color: isAction ? DS.onSurfaceVariant : DS.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
