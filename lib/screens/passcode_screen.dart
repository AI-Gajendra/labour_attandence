import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../services/passcode_service.dart';

/// Lock screen that appears on app launch when passcode is enabled.
class PasscodeScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PasscodeScreen({super.key, required this.onUnlocked});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) async {
    if (digit == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _isError = false;
        });
      }
      return;
    }
    if (digit == 'C') {
      setState(() {
        _pin = '';
        _isError = false;
      });
      return;
    }

    if (_pin.length >= 4) return;

    setState(() {
      _pin += digit;
      _isError = false;
    });

    // Auto-submit on 4 digits
    if (_pin.length == 4) {
      final ok = await PasscodeService().verifyPasscode(_pin);
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() {
          _isError = true;
          _pin = '';
        });
        _shakeController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.primaryContainer,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Lock Icon ──
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DS.green.withAlpha(30),
                borderRadius: BorderRadius.circular(DS.radiusFull),
              ),
              child: Icon(
                Icons.lock_outline,
                color: DS.green,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ──
            const Text(
              'Enter Passcode',
              style: TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isError ? 'Incorrect passcode. Try again.' : 'Enter your 4-digit PIN',
              style: TextStyle(
                fontFamily: DS.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isError ? const Color(0xFFFF6B6B) : Colors.white.withAlpha(150),
              ),
            ),

            const SizedBox(height: 40),

            // ── PIN Dots ──
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeAnimation.value * (_shakeController.value < 0.5 ? 1 : -1),
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: filled ? 20 : 16,
                    height: filled ? 20 : 16,
                    decoration: BoxDecoration(
                      color: _isError
                          ? const Color(0xFFFF6B6B)
                          : filled
                              ? DS.green
                              : Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(DS.radiusFull),
                      border: Border.all(
                        color: _isError
                            ? const Color(0xFFFF6B6B)
                            : filled
                                ? DS.green
                                : Colors.white.withAlpha(60),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const Spacer(flex: 1),

            // ── Keypad ──
            _PasscodeKeypad(onDigit: _onDigit),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Keypad for Passcode ──
class _PasscodeKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  const _PasscodeKeypad({required this.onDigit});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                final isAction = key == 'C' || key == '⌫';
                return GestureDetector(
                  onTap: () => onDigit(key),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isAction
                          ? Colors.white.withAlpha(10)
                          : Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(DS.radiusFull),
                      border: Border.all(
                        color: Colors.white.withAlpha(20),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key,
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: isAction ? 16 : 28,
                        fontWeight: FontWeight.w600,
                        color: isAction
                            ? Colors.white.withAlpha(150)
                            : Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
