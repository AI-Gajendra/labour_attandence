import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../providers/attendance_provider.dart';
import '../providers/worker_provider.dart';
import '../services/sync_status.dart';
import 'attendance_screen.dart';
import 'main_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceProvider>().refreshToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.surface,
      body: Column(
        children: [
          // ── At-A-Glance Header (asymmetric padding per DESIGN.md) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
            decoration: const BoxDecoration(color: DS.primaryContainer),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LABOUR MANAGER',
                  style: TextStyle(
                    fontFamily: DS.fontHeadline,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 2,
                      ),
                      color: DS.onPrimaryContainer,
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content Canvas ──
          Expanded(
            child: RefreshIndicator(
              color: DS.green,
              onRefresh: () =>
                  context.read<AttendanceProvider>().refreshToday(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Editorial Context Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMMAND CENTER',
                          style: DS.labelSm.copyWith(
                            color: DS.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Daily Insight',
                          style: TextStyle(
                            fontFamily: DS.fontHeadline,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: DS.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Stat Cards Row ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer2<WorkerProvider, AttendanceProvider>(
                      builder: (context, wp, ap, _) {
                        final count = wp.count;
                        // Previously this card rendered a literal '— / count':
                        // today's attendance was never fetched. It is now real.
                        final marked = ap.todayLoaded
                            ? '${ap.todayMarked}'
                            : '—';
                        return Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.groups,
                                label: 'TOTAL WORKERS',
                                value: '$count',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.how_to_reg,
                                label: 'MARKED TODAY',
                                value: '$marked / $count',
                                accentDot:
                                    ap.todayLoaded &&
                                    count > 0 &&
                                    ap.todayMarked >= count,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Action Grid (2x2) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.checklist_rtl,
                                title: 'Mark\nAttendance',
                                subtitle: 'DAILY LOG',
                                accent: DS.green,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AttendanceScreen(),
                                    ),
                                  );
                                  if (context.mounted) {
                                    context
                                        .read<AttendanceProvider>()
                                        .refreshToday();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.engineering,
                                title: 'Worker\nDatabase',
                                subtitle: 'MANAGE STAFF',
                                accent: DS.tertiary,
                                onTap: () => context
                                    .findAncestorStateOfType<MainScreenState>()
                                    ?.setIndex(1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.receipt_long,
                                title: 'Advance\nPayment',
                                subtitle: 'KHARCHI',
                                accent: DS.warning,
                                onTap: () => context
                                    .findAncestorStateOfType<MainScreenState>()
                                    ?.setIndex(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.assessment,
                                title: 'Monthly\nSummary',
                                subtitle: 'REPORTS',
                                accent: DS.reports,
                                onTap: () => context
                                    .findAncestorStateOfType<MainScreenState>()
                                    ?.setIndex(3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Status (live, not hardcoded) ──
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _StatusCard(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Card ──
//
// Replaces the two hardcoded "Recent Alerts" rows ("Pending Attendance",
// "System Active") that were rendered from string literals and never reflected
// anything. Every row here is derived from live state.
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Consumer2<WorkerProvider, AttendanceProvider>(
        builder: (context, wp, ap, _) {
          final total = wp.count;
          final marked = ap.todayMarked;
          final unmarked = (total - marked).clamp(0, total);

          final rows = <Widget>[];

          if (wp.error != null) {
            rows.add(
              _AlertRow(
                dotColor: DS.error,
                title: 'Cannot reach the database',
                subtitle: 'Tap to retry',
                onTap: wp.retry,
              ),
            );
          } else if (total == 0) {
            rows.add(
              const _AlertRow(
                dotColor: DS.warning,
                title: 'No workers yet',
                subtitle: 'Add your crew from the Workers tab',
              ),
            );
          } else if (!ap.todayLoaded) {
            rows.add(
              const _AlertRow(
                dotColor: DS.outline,
                title: 'Checking today\'s attendance…',
                subtitle: 'Pull down to refresh',
              ),
            );
          } else if (unmarked > 0) {
            rows.add(
              _AlertRow(
                dotColor: DS.error,
                title: '$unmarked of $total not marked today',
                subtitle: 'Tap to mark attendance',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ),
              ),
            );
          } else {
            rows.add(
              _AlertRow(
                dotColor: DS.green,
                title: 'All $total marked today',
                subtitle:
                    '${ap.todayPresent} full day'
                    '${ap.halfDayCount > 0 ? ', ${ap.halfDayCount} half day' : ''}',
              ),
            );
          }

          rows.add(const SizedBox(height: 12));
          rows.add(const _SyncRow());

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: DS.headlineMd.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              ...rows,
            ],
          );
        },
      ),
    );
  }
}

// ── Sync Row ──
class _SyncRow extends StatelessWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SyncStatus.instance,
      builder: (context, _) {
        final status = SyncStatus.instance;
        if (status.isOffline) {
          return _AlertRow(
            dotColor: DS.warning,
            title: 'Working offline',
            subtitle: status.pending > 0
                ? '${status.pending} change(s) will sync when back online'
                : 'Everything is saved on this phone',
          );
        }
        if (status.pending > 0) {
          return _AlertRow(
            dotColor: DS.tertiary,
            title: 'Syncing',
            subtitle: '${status.pending} change(s) in flight',
          );
        }
        return const _AlertRow(
          dotColor: DS.green,
          title: 'Synced',
          subtitle: 'All changes saved to the cloud',
        );
      },
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accentDot;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accentDot = false,
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
              Icon(icon, size: 24, color: DS.onSurfaceVariant),
              if (accentDot)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DS.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: DS.labelSm.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: DS.onSurfaceVariant,
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
                fontSize: 32,
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

// ── Action Tile ──
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DS.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          boxShadow: DS.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(25),
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DS.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: DS.labelSm.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: DS.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alert Row ──
class _AlertRow extends StatelessWidget {
  final Color dotColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AlertRow({
    required this.dotColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DS.titleMd.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: DS.bodySm),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 20, color: DS.outlineVariant),
        ],
      ),
    );
  }
}
