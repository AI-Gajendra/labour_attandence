import 'dart:async';

import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../services/passcode_service.dart';
import 'settings_screen.dart' show PinDots, DialogKeypad;

/// Lock screen shown on launch when the passcode is enabled.
///
/// Adds two things the previous version lacked: a visible **lockout** after
/// repeated failures (a 4-digit PIN has only 10 000 possibilities, so unlimited
/// guessing made it decorative), and optional **biometric unlock** that always
/// leaves the PIN available as a fallback.
class PasscodeScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PasscodeScreen({super.key, required this.onUnlocked});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  final PasscodeService _passcode = PasscodeService();

  String _pin = '';
  bool _isError = false;
  bool _checking = false;
  String _message = '';
  Duration? _lockout;
  Timer? _lockoutTimer;
  bool _biometricEnabled = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 24,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _shakeController.reset();
    });

    _initialise();
  }

  Future<void> _initialise() async {
    final lockout = await _passcode.currentLockout();
    final biometric = await _passcode.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = biometric;
      if (lockout != null) _startLockout(lockout);
    });
    if (biometric) _tryBiometric();
  }

  void _startLockout(Duration duration) {
    _lockout = duration;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining =
          (_lockout ?? Duration.zero) - const Duration(seconds: 1);
      setState(() {
        if (remaining <= Duration.zero) {
          _lockout = null;
          _message = '';
          timer.cancel();
        } else {
          _lockout = remaining;
        }
      });
    });
  }

  Future<void> _tryBiometric() async {
    final ok = await _passcode.authenticateBiometric();
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _onDigit(String digit) async {
    if (_checking || _lockout != null) return;

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

    if (_pin.length < 4) return;

    // PBKDF2 verification runs off the UI isolate but still takes a moment.
    setState(() => _checking = true);
    final attempt = await _passcode.verifyPasscode(_pin);
    if (!mounted) return;

    if (attempt.ok) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _checking = false;
      _isError = true;
      _pin = '';
      if (attempt.isLockedOut) {
        _message = '';
        _startLockout(attempt.lockedFor!);
      } else {
        _message = attempt.attemptsRemaining == 1
            ? '1 attempt left before a timeout'
            : '${attempt.attemptsRemaining} attempts left';
      }
    });
    _shakeController.forward();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  String get _subtitle {
    if (_lockout != null) {
      final seconds = _lockout!.inSeconds;
      final minutes = seconds ~/ 60;
      final remainder = seconds % 60;
      final time = minutes > 0 ? '${minutes}m ${remainder}s' : '${remainder}s';
      return 'Too many attempts. Try again in $time.';
    }
    if (_isError) {
      return _message.isEmpty ? 'Incorrect passcode. Try again.' : _message;
    }
    return 'Enter your 4-digit PIN';
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockout != null;

    return Scaffold(
      backgroundColor: DS.primaryContainer,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (locked ? DS.error : DS.green).withAlpha(30),
                borderRadius: BorderRadius.circular(DS.radiusFull),
              ),
              child: Icon(
                locked ? Icons.lock_clock : Icons.lock_outline,
                color: locked ? DS.error : DS.green,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: DS.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (_isError || locked)
                      ? const Color(0xFFFF6B6B)
                      : Colors.white.withAlpha(150),
                ),
              ),
            ),

            const SizedBox(height: 40),

            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  _shakeAnimation.value *
                      (_shakeController.value < 0.5 ? 1 : -1),
                  0,
                ),
                child: child,
              ),
              child: _checking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: DS.green,
                        strokeWidth: 2,
                      ),
                    )
                  : PinDots(filled: _pin.length, isError: _isError, size: 20),
            ),

            const Spacer(flex: 1),

            Opacity(
              opacity: locked ? 0.35 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: DialogKeypad(onDigit: _onDigit, keySize: 68),
              ),
            ),

            if (_biometricEnabled && !locked)
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint, color: Colors.white70),
                label: const Text(
                  'USE BIOMETRICS',
                  style: TextStyle(
                    fontFamily: DS.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
