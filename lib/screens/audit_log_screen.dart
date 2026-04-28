import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_tokens.dart';
import '../services/audit_service.dart';

/// Screen to display the full edit history / audit trail.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAuditLog();
  }

  Future<void> _loadAuditLog() async {
    final entries = await AuditService().getAuditLog(limit: 100);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Just now';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }

  IconData _getActionIcon(String action) {
    if (action.contains('created')) return Icons.add_circle_outline;
    if (action.contains('updated')) return Icons.edit_outlined;
    if (action.contains('deleted')) return Icons.delete_outline;
    return Icons.info_outline;
  }

  Color _getActionColor(String action) {
    if (action.contains('created')) return DS.green;
    if (action.contains('updated')) return const Color(0xFFF59E0B);
    if (action.contains('deleted')) return DS.error;
    return DS.tertiary;
  }

  String _getActionLabel(String action) {
    if (action.contains('advance')) {
      if (action.contains('created')) return 'Advance Recorded';
      if (action.contains('updated')) return 'Advance Edited';
      if (action.contains('deleted')) return 'Advance Deleted';
    }
    if (action.contains('attendance')) {
      if (action.contains('created')) return 'Attendance Marked';
      if (action.contains('updated')) return 'Attendance Changed';
    }
    return action.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.surface,
      body: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            decoration: const BoxDecoration(color: DS.primaryContainer),
            child: Row(
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
                      'Edit History',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AUDIT TRAIL',
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
                  onTap: () {
                    setState(() => _loading = true);
                    _loadAuditLog();
                  },
                  child: const Icon(Icons.refresh, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // ── Entries List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: DS.green))
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 64, color: DS.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No edit history yet',
                              style: DS.titleMd.copyWith(color: DS.outline),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Changes will appear here',
                              style: DS.bodySm,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final action = entry['action'] ?? '';
                          final actionColor = _getActionColor(action);
                          final before = entry['before'] as Map<String, dynamic>?;
                          final after = entry['after'] as Map<String, dynamic>?;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: DS.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(DS.radiusLg),
                              boxShadow: DS.cardShadowLight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: actionColor.withAlpha(20),
                                        borderRadius: BorderRadius.circular(DS.radiusMd),
                                      ),
                                      child: Icon(_getActionIcon(action), color: actionColor, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getActionLabel(action),
                                            style: DS.titleMd.copyWith(fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatTimestamp(entry['changedAt']),
                                            style: DS.bodySm.copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Diff details
                                if (before != null || after != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: DS.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(DS.radiusMd),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (before != null && after != null) ...[
                                          // Update: show diff
                                          ..._buildDiffRows(before, after),
                                        ] else if (after != null) ...[
                                          // Create: show new values
                                          ...after.entries
                                              .where((e) => e.key != 'createdBy' && e.key != 'workerId')
                                              .map((e) => _buildDetailRow('${e.key}:', '${e.value}')),
                                        ] else if (before != null) ...[
                                          // Delete: show removed values
                                          ...before.entries
                                              .where((e) => e.key != 'createdBy' && e.key != 'workerId')
                                              .map((e) => _buildDetailRow('${e.key}:', '${e.value}', isDeleted: true)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDiffRows(Map<String, dynamic> before, Map<String, dynamic> after) {
    final List<Widget> rows = [];
    final allKeys = {...before.keys, ...after.keys}
        .where((k) => k != 'createdBy' && k != 'workerId');
    for (final key in allKeys) {
      final oldVal = before[key];
      final newVal = after[key];
      if (oldVal != newVal) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '$key: ',
                  style: DS.bodySm.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '$oldVal',
                  style: DS.bodySm.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: DS.error,
                    fontSize: 12,
                  ),
                ),
                const Text(' → ', style: TextStyle(fontSize: 12, color: DS.outline)),
                Text(
                  '$newVal',
                  style: DS.bodySm.copyWith(
                    color: DS.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildDetailRow(String label, String value, {bool isDeleted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: DS.bodySm.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: DS.bodySm.copyWith(
              fontSize: 12,
              color: isDeleted ? DS.error : DS.onSurface,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
