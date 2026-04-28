import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../providers/worker_provider.dart';
import '../models/worker.dart';
import 'main_screen.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showForm({Worker? worker}) {
    final nameCtrl = TextEditingController(text: worker?.name ?? '');
    final typeCtrl = TextEditingController(text: worker?.type ?? '');
    final wageCtrl = TextEditingController(text: worker?.dailyWage.toStringAsFixed(0) ?? '');
    final isEdit = worker != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(c).viewInsets.bottom + MediaQuery.of(c).padding.bottom + 24),
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
              isEdit ? 'EDIT WORKER' : 'ADD WORKER',
              style: DS.labelSm.copyWith(fontSize: 11, letterSpacing: 1.5, color: DS.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              isEdit ? 'Update Information' : 'New Team Member',
              style: DS.headlineMd,
            ),
            const SizedBox(height: 24),
            _FormField(ctrl: nameCtrl, label: 'NAME', hint: 'Worker name'),
            const SizedBox(height: 16),
            _FormField(ctrl: typeCtrl, label: 'TYPE', hint: 'e.g. Mason, Helper'),
            const SizedBox(height: 16),
            _FormField(ctrl: wageCtrl, label: 'DAILY WAGE (₹)', hint: 'Amount', isNumeric: true),
            const SizedBox(height: 24),
            Row(
              children: [
                if (isEdit)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(c);
                        await context.read<WorkerProvider>().deleteWorker(worker.workerId);
                      },
                      child: Container(
                        height: DS.buttonHeight,
                        decoration: BoxDecoration(
                          color: DS.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(DS.radiusXl),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'DELETE',
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
                      final wage = double.tryParse(wageCtrl.text.trim()) ?? 0;
                      if (name.isEmpty) return;
                      Navigator.pop(c);
                      final wp = context.read<WorkerProvider>();
                      if (isEdit) {
                        await wp.updateWorker(worker.workerId, name, type, wage);
                      } else {
                        await wp.addWorker(name, type, wage);
                      }
                    },
                    child: Container(
                      height: DS.buttonHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
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
    );
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
            decoration: const BoxDecoration(
              color: DS.primaryContainer,
            ),
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
                // ── Search Bar ──
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.white.withAlpha(120), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _query = val.toLowerCase()),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by name or type...',
                            hintStyle: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14),
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

          // ── Total Count Pill (from Provider) ──
          Consumer<WorkerProvider>(
            builder: (context, wp, _) {
              final total = wp.count;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'REGISTERED STAFF',
                      style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DS.green.withAlpha(25),
                        borderRadius: BorderRadius.circular(DS.radiusFull),
                      ),
                      child: Text(
                        '$total',
                        style: DS.labelXs.copyWith(color: DS.green, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Worker List (from Provider) ──
          Expanded(
            child: Consumer<WorkerProvider>(
              builder: (context, wp, _) {
                if (wp.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: DS.green));
                }
                final workers = wp.search(_query);

                if (workers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: DS.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No workers found', style: DS.bodyMd.copyWith(color: DS.outline)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final w = workers[index];
                    return _WorkerCard(
                      worker: w,
                      onTap: () => _showForm(worker: w),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusFull)),
      ),
    );
  }
}

// ── Worker Card (surface-container-lowest on surface) ──
class _WorkerCard extends StatelessWidget {
  final Worker worker;
  final VoidCallback onTap;

  const _WorkerCard({required this.worker, required this.onTap});

  Color _typeBadgeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('mason') || t.contains('mistri') || t.contains('raj')) return const Color(0xFF3980F4);
    if (t.contains('helper') || t.contains('labour')) return const Color(0xFF10B981);
    if (t.contains('carpenter') || t.contains('paint')) return const Color(0xFFF59E0B);
    if (t.contains('electric')) return const Color(0xFF8B5CF6);
    if (t.contains('plumb')) return const Color(0xFF06B6D4);
    return DS.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _typeBadgeColor(worker.type);
    final initial = worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?';

    return GestureDetector(
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
            // Initial Avatar
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
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: DS.titleMd,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(18),
                          borderRadius: BorderRadius.circular(DS.radiusFull),
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
                        '₹${worker.dailyWage.toStringAsFixed(0)}/day',
                        style: DS.bodySm.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: DS.outlineVariant, size: 24),
          ],
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
          style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5, color: DS.onSurfaceVariant),
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
              hintStyle: TextStyle(
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
