import 'package:flutter/material.dart';
import '../design_tokens.dart';
import 'home_screen.dart';
import 'worker_list_screen.dart';
import 'advance_screen.dart';
import 'summary_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const WorkerListScreen(),
    const AdvanceScreen(),
    const SummaryScreen(),
  ];

  void setIndex(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(240),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF151B29).withAlpha(15),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home, label: 'HOME', isActive: _currentIndex == 0, onTap: () => setIndex(0)),
              _NavItem(icon: Icons.engineering, label: 'WORKERS', isActive: _currentIndex == 1, onTap: () => setIndex(1)),
              _NavItem(icon: Icons.receipt_long, label: 'PAYROLL', isActive: _currentIndex == 2, onTap: () => setIndex(2)),
              _NavItem(icon: Icons.assessment, label: 'REPORTS', isActive: _currentIndex == 3, onTap: () => setIndex(3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav Item ──
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? DS.green.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(DS.radiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? DS.green : DS.outline,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: DS.fontBody,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: isActive ? DS.green : DS.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
