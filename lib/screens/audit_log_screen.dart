import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../utils/dates.dart';

/// Full edit history.
///
/// Now covers workers, attendance, advances **and** settlements — previously
/// only advances were audited, and the list silently truncated at 100 entries
/// with no way to see older ones. This pages instead.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _entries = [];
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AuditService().getAuditLog();
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.entries);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the edit history.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AuditService().getAuditLog(startAfter: _cursor);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
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
                        'Edit History',
                        style: TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'AUDIT TRAIL',
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
                GestureDetector(
                  onTap: _refresh,
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: DS.green),
                  )
                : _error != null
                ? _EmptyOrError(
                    icon: Icons.cloud_off,
                    title: _error!,
                    subtitle: 'Pull down to try again',
                    onRetry: _refresh,
                  )
                : _entries.isEmpty
                ? const _EmptyOrError(
                    icon: Icons.history,
                    title: 'No edit history yet',
                    subtitle: 'Changes will appear here',
                  )
                : RefreshIndicator(
                    color: DS.green,
                    onRefresh: _refresh,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index >= _entries.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: DS.green,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _AuditEntry(entry: _entries[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Error ──
class _EmptyOrError extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _EmptyOrError({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: DS.outlineVariant),
          const SizedBox(height: 16),
          Text(title, style: DS.titleMd.copyWith(color: DS.outline)),
          const SizedBox(height: 4),
          Text(subtitle, style: DS.bodySm),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ],
      ),
    );
  }
}

// ── Audit Entry ──
class _AuditEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _AuditEntry({required this.entry});

  static IconData _icon(String action) {
    if (action.contains('created')) return Icons.add_circle_outline;
    if (action.contains('updated')) return Icons.edit_outlined;
    if (action.contains('deleted')) return Icons.delete_outline;
    return Icons.info_outline;
  }

  static Color _color(String action) {
    if (action.contains('created')) return DS.green;
    if (action.contains('updated')) return DS.warning;
    if (action.contains('deleted')) return DS.error;
    return DS.tertiary;
  }

  static String _label(String action) {
    const nouns = {
      'advances': 'Advance',
      'attendance': 'Attendance',
      'workers': 'Worker',
      'settlements': 'Payment',
    };
    const verbs = {
      'created': 'recorded',
      'updated': 'changed',
      'deleted': 'deleted',
    };
    for (final noun in nouns.entries) {
      if (!action.startsWith(noun.key)) continue;
      for (final verb in verbs.entries) {
        if (action.endsWith(verb.key)) return '${noun.value} ${verb.value}';
      }
    }
    return action.replaceAll('_', ' ').toUpperCase();
  }

  static String _formatTimestamp(dynamic value) {
    if (value == null) return 'Just now';
    if (value is Timestamp) return displayTimestamp(value.toDate());
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final action = (entry['action'] as String?) ?? '';
    final color = _color(action);
    final before = entry['before'] as Map<String, dynamic>?;
    final after = entry['after'] as Map<String, dynamic>?;
    final changedBy = (entry['changedBy'] as String?) ?? '';

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Icon(_icon(action), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(action),
                      style: DS.titleMd.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTimestamp(entry['changedAt'])}'
                      '${changedBy.isEmpty ? '' : ' · ${AuthService.shortActor(changedBy)}'}',
                      style: DS.bodySm.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (before != null || after != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DS.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _detailRows(before, after),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _detailRows(
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    bool visible(String key) => key != 'createdBy' && key != 'workerId';

    if (before != null && after != null) {
      final keys = {...before.keys, ...after.keys}.where(visible);
      final rows = <Widget>[];
      for (final key in keys) {
        final oldValue = before[key];
        final newValue = after[key];
        if (oldValue == newValue) continue;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$key: ',
                  style: DS.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$oldValue',
                  style: DS.bodySm.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: DS.error,
                    fontSize: 12,
                  ),
                ),
                const Text(
                  ' → ',
                  style: TextStyle(fontSize: 12, color: DS.outline),
                ),
                Text(
                  '$newValue',
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
      return rows.isEmpty
          ? [Text('No field changes', style: DS.bodySm.copyWith(fontSize: 12))]
          : rows;
    }

    final data = after ?? before;
    final deleted = after == null;
    if (data == null) return const [];

    return data.entries.where((e) => visible(e.key)).map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(
              '${e.key}: ',
              style: DS.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Text(
                '${e.value}',
                style: DS.bodySm.copyWith(
                  fontSize: 12,
                  color: deleted ? DS.error : DS.onSurface,
                  decoration: deleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
