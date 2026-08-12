import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../models/worker.dart';
import '../providers/worker_provider.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import 'main_screen.dart';
import 'worker_profile_screen.dart';

/// Add / edit sheet for a worker.
///
/// Top-level so the worker profile screen can reuse it rather than growing a
/// second, divergent copy of the same form.
Future<void> showWorkerForm(BuildContext context, {Worker? worker}) {
  final nameCtrl = TextEditingController(text: worker?.name ?? '');
  final typeCtrl = TextEditingController(text: worker?.type ?? '');
  final wageCtrl = TextEditingController(
    text: worker == null ? '' : '${worker.dailyWage}',
  );
  final isEdit = worker != null;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(sheetContext).viewInsets.bottom +
            MediaQuery.of(sheetContext).padding.bottom +
            24,
      ),
      decoration: const BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Scrollable so the form still fits once the keyboard takes half the
      // screen — without it the button row overflowed by a few pixels and drew
      // the yellow-and-black overflow stripes over the save button.
      child: SingleChildScrollView(
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
              isEdit ? 'EDIT WORKER' : 'ADD WORKER',
              style: DS.labelSm.copyWith(
                fontSize: 11,
                letterSpacing: 1.5,
                color: DS.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isEdit ? 'Update Information' : 'New Team Member',
              style: DS.headlineMd,
            ),
            const SizedBox(height: 24),
            _FormField(ctrl: nameCtrl, label: 'NAME', hint: 'Worker name'),
            const SizedBox(height: 16),
            _FormField(
              ctrl: typeCtrl,
              label: 'TYPE',
              hint: 'e.g. Mason, Helper',
            ),
            const SizedBox(height: 16),
            _FormField(
              ctrl: wageCtrl,
              label: 'DAILY WAGE (₹)',
              hint: 'Whole rupees',
              isNumeric: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (isEdit)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final wp = context.read<WorkerProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(sheetContext);
                        final confirmed = await _confirmArchive(
                          context,
                          worker,
                        );
                        if (!confirmed) return;
                        try {
                          await wp.archiveWorker(worker.workerId);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('${worker.name} archived'),
                              backgroundColor: DS.onSurfaceVariant,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Could not archive: $e'),
                              backgroundColor: DS.error,
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: DS.buttonHeight,
                        decoration: BoxDecoration(
                          color: DS.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(DS.radiusXl),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'ARCHIVE',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: DS.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isEdit) const SizedBox(width: 12),
                Expanded(
                  flex: isEdit ? 2 : 1,
                  child: GestureDetector(
                    onTap: () async {
                      final name = nameCtrl.text.trim();
                      final type = typeCtrl.text.trim();
                      final wage = int.tryParse(wageCtrl.text.trim()) ?? 0;
                      if (name.isEmpty) return;

                      final wp = context.read<WorkerProvider>();
                      final messenger = ScaffoldMessenger.of(context);

                      // A rate change needs a start date, otherwise it silently
                      // re-prices work already done at the old rate.
                      _WageChange? change;
                      if (isEdit && wage != worker.dailyWage) {
                        change = await _askWageEffectiveFrom(
                          context,
                          worker,
                          wage,
                        );
                        if (change == null) return; // cancelled
                      }

                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);

                      try {
                        if (isEdit) {
                          await wp.updateWorker(
                            worker.workerId,
                            name,
                            type,
                            wage,
                            wageEffectiveFrom: change?.effectiveFrom,
                          );
                        } else {
                          await wp.addWorker(name, type, wage);
                        }
                      } catch (e) {
                        // Firestore rejected the write — say so rather than
                        // letting the sheet close as if it had worked.
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not save $name: $e'),
                            backgroundColor: DS.error,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: DS.buttonHeight,
                      decoration: BoxDecoration(
                        gradient: DS.ctaGradient,
                        borderRadius: BorderRadius.circular(DS.radiusXl),
                        boxShadow: DS.buttonShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isEdit ? 'SAVE CHANGES' : 'ADD WORKER',
                        style: const TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white,
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
    ),
  );
}

/// Chosen start date for a new daily rate. `null` [effectiveFrom] means "this
/// rate has always applied" — a typo correction, not a raise.
class _WageChange {
  final String? effectiveFrom;
  const _WageChange(this.effectiveFrom);
}

/// Asks which days a new rate applies to.
///
/// Without this the app took the new number and applied it to every unsettled
/// day the worker had ever worked, so giving someone a raise quietly rewrote
/// what they had already earned. A rate change is an event with a date.
Future<_WageChange?> _askWageEffectiveFrom(
  BuildContext context,
  Worker worker,
  int newWage,
) {
  final now = DateTime.now();
  final thisMonth = firstOfMonth(now);
  final nextMonth = addMonths(thisMonth, 1);
  final raise = newWage > worker.dailyWage;

  return showDialog<_WageChange>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DS.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      title: Text(
        '${raise ? 'Raise' : 'Change'} ${worker.name}\'s rate',
        style: DS.headlineMd.copyWith(fontSize: 19),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${rupees(worker.dailyWage)} → ${rupees(newWage)} per day.\n'
            'From which day does the new rate apply?',
            style: DS.bodyMd.copyWith(color: DS.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _WageOption(
            title: 'From ${displayMonthLong(thisMonth)}',
            subtitle: 'Earlier months keep ${rupees(worker.dailyWage)}/day',
            recommended: true,
            onTap: () => Navigator.pop(ctx, _WageChange(dateKey(thisMonth))),
          ),
          _WageOption(
            title: 'From today (${displayDayMonth(now)})',
            subtitle:
                'Days already marked keep ${rupees(worker.dailyWage)}/day',
            onTap: () => Navigator.pop(ctx, _WageChange(dateKey(now))),
          ),
          _WageOption(
            title: 'From ${displayMonthLong(nextMonth)}',
            subtitle: 'The whole of this month stays at the old rate',
            onTap: () => Navigator.pop(ctx, _WageChange(dateKey(nextMonth))),
          ),
          _WageOption(
            title: 'Correct a mistake',
            subtitle:
                'The rate was always ${rupees(newWage)} — re-prices all '
                'unsettled past work',
            danger: true,
            onTap: () => Navigator.pop(ctx, const _WageChange(null)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

// ── Wage effective-date option ──
class _WageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool recommended;
  final bool danger;
  final VoidCallback onTap;

  const _WageOption({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? DS.error : DS.green;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: recommended ? accent.withAlpha(18) : DS.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: recommended
              ? Border.all(color: accent.withAlpha(80), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DS.titleMd.copyWith(
                fontSize: 14,
                color: danger ? DS.error : DS.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: DS.bodySm.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Archiving is a soft delete — spell out that history survives, because the
/// old behaviour (a hard delete that orphaned every attendance and advance
/// record) is what people will expect.
Future<bool> _confirmArchive(BuildContext context, Worker worker) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Archive ${worker.name}?'),
      content: const Text(
        'They will be hidden from attendance and advance lists.\n\n'
        'Their past attendance, advances and payments are kept, so old months '
        'still add up correctly. You can restore them at any time.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: DS.error),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Worker Database',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white.withAlpha(120),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) =>
                              setState(() => _query = val.toLowerCase()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name or type...',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Count + archive toggle ──
          Consumer<WorkerProvider>(
            builder: (context, wp, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'REGISTERED STAFF',
                      style: DS.labelSm.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DS.green.withAlpha(25),
                        borderRadius: BorderRadius.circular(DS.radiusFull),
                      ),
                      child: Text(
                        '${wp.count}',
                        style: DS.labelXs.copyWith(
                          color: DS.green,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (wp.archivedCount > 0)
                      TextButton(
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        style: TextButton.styleFrom(
                          foregroundColor: DS.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          _showArchived
                              ? 'HIDE ARCHIVED'
                              : 'ARCHIVED (${wp.archivedCount})',
                          style: DS.labelXs.copyWith(
                            color: DS.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Worker List ──
          Expanded(
            child: Consumer<WorkerProvider>(
              builder: (context, wp, _) {
                if (wp.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: DS.green),
                  );
                }
                if (wp.error != null) {
                  return _ErrorState(message: wp.error!, onRetry: wp.retry);
                }

                final active = wp.search(_query);
                final archived = _showArchived
                    ? wp.archivedWorkers
                          .where(
                            (w) =>
                                _query.isEmpty ||
                                w.name.toLowerCase().contains(_query) ||
                                w.type.toLowerCase().contains(_query),
                          )
                          .toList()
                    : const <Worker>[];

                if (active.isEmpty && archived.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: DS.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No workers found',
                          style: DS.bodyMd.copyWith(color: DS.outline),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    ...active.map(
                      (w) => _WorkerCard(
                        worker: w,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkerProfileScreen(workerId: w.workerId),
                          ),
                        ),
                        onEdit: () => showWorkerForm(context, worker: w),
                      ),
                    ),
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'ARCHIVED',
                          style: DS.labelSm.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      ...archived.map(
                        (w) => _WorkerCard(
                          worker: w,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  WorkerProfileScreen(workerId: w.workerId),
                            ),
                          ),
                          onEdit: () => wp.restoreWorker(w.workerId),
                          editIcon: Icons.unarchive_outlined,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWorkerForm(context),
        backgroundColor: DS.primaryContainer,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ADD WORKER',
          style: TextStyle(
            fontFamily: DS.fontHeadline,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radiusFull),
        ),
      ),
    );
  }
}

// ── Error State ──
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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

// ── Worker Card ──
class _WorkerCard extends StatelessWidget {
  final Worker worker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final IconData editIcon;

  const _WorkerCard({
    required this.worker,
    required this.onTap,
    required this.onEdit,
    this.editIcon = Icons.edit_outlined,
  });

  /// Trade badge colour. Includes the Hindi/Mewari trade words the crew
  /// actually uses ("mistri", "beldar") alongside the English ones.
  static Color typeBadgeColor(String type) {
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
    return DS.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = typeBadgeColor(worker.type);
    final initial = worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?';

    return Opacity(
      opacity: worker.isActive ? 1 : 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: DS.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(DS.radiusLg),
            boxShadow: DS.cardShadowLight,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(DS.radiusLg),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name, style: DS.titleMd),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (worker.type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(18),
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
                        const SizedBox(width: 8),
                        Text(
                          '${rupees(worker.dailyWage)}/day',
                          style: DS.bodySm.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(editIcon, size: 20, color: DS.outline),
                tooltip: worker.isActive ? 'Edit' : 'Restore',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input Field (64px, ghost border) ──
class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool isNumeric;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.isNumeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DS.labelSm.copyWith(
            fontSize: 10,
            letterSpacing: 1.5,
            color: DS.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: DS.inputHeight,
          decoration: BoxDecoration(
            color: DS.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DS.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: ctrl,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: const TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DS.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontFamily: DS.fontBody,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: DS.outline,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
