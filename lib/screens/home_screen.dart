import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_tokens.dart';
import '../providers/worker_provider.dart';
import 'attendance_screen.dart';
import 'main_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            decoration: const BoxDecoration(
              color: DS.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.menu, color: Colors.white, size: 24),
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
                          border: Border.all(color: Colors.white.withAlpha(50), width: 2),
                          color: DS.onPrimaryContainer,
                        ),
                        child: const Icon(Icons.settings, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Main Content Canvas ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editorial Context Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMMAND CENTER',
                          style: DS.labelSm.copyWith(color: DS.onSurfaceVariant),
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

                  // ── Stat Cards Row (from Provider) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer<WorkerProvider>(
                      builder: (context, wp, _) {
                        final count = wp.count;
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
                                label: 'TODAY',
                                value: '— / $count',
                                accentDot: true,
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
                                iconBgColor: const Color(0xFF10B981).withAlpha(25),
                                iconColor: const Color(0xFF10B981),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.engineering,
                                title: 'Worker\nDatabase',
                                subtitle: 'MANAGE STAFF',
                                iconBgColor: const Color(0xFF3980F4).withAlpha(25),
                                iconColor: const Color(0xFF3980F4),
                                onTap: () {
                                  context.findAncestorStateOfType<MainScreenState>()?.setIndex(1);
                                },
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
                                subtitle: 'PAYROLL ADJUSTMENT',
                                iconBgColor: const Color(0xFFF59E0B).withAlpha(25),
                                iconColor: const Color(0xFFF59E0B),
                                onTap: () {
                                  context.findAncestorStateOfType<MainScreenState>()?.setIndex(2);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.assessment,
                                title: 'Monthly\nSummary',
                                subtitle: 'REPORTS',
                                iconBgColor: const Color(0xFF8B5CF6).withAlpha(25),
                                iconColor: const Color(0xFF8B5CF6),
                                onTap: () {
                                  context.findAncestorStateOfType<MainScreenState>()?.setIndex(3);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Recent Alerts ──
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: DS.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(DS.radiusLg),
                      boxShadow: DS.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Alerts',
                              style: DS.headlineMd.copyWith(fontSize: 18),
                            ),
                            Text(
                              'VIEW ALL',
                              style: DS.labelXs.copyWith(color: DS.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _AlertRow(
                          dotColor: DS.error,
                          title: 'Pending Attendance',
                          subtitle: 'Workers not marked yet today',
                        ),
                        const SizedBox(height: 12),
                        _AlertRow(
                          dotColor: DS.green,
                          title: 'System Active',
                          subtitle: 'All services running normally',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card (matches dashboard screenshot: icon, label, bold value) ──
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
          Text(
            value,
            style: const TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: DS.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Tile (matches dashboard 2x2 grid with icon bubbles) ──
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBgColor,
    required this.iconColor,
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
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
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

  const _AlertRow({required this.dotColor, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
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
      ],
    );
  }
}

