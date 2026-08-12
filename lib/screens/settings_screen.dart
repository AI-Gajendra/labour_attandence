import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../design_tokens.dart';
import '../services/auth_service.dart';
import '../services/passcode_service.dart';
import 'audit_log_screen.dart';

/// Settings: app lock, biometrics, audit trail and build info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PasscodeService _passcode = PasscodeService();

  bool _passcodeEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _passcode.isPasscodeEnabled();
    final bioAvailable = await _passcode.biometricAvailable();
    final bioEnabled = await _passcode.isBiometricEnabled();

    // Read the version from the build rather than hardcoding it — the old
    // Settings screen said "Version 0.2.0" while pubspec said 0.1.0.
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      version = 'unknown';
    }

    if (!mounted) return;
    setState(() {
      _passcodeEnabled = enabled;
      _biometricAvailable = bioAvailable;
      _biometricEnabled = bioEnabled;
      _version = version;
      _loading = false;
    });
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _togglePasscode(bool value) async {
    if (value) {
      final pin = await _showSetPinDialog('Set Passcode');
      if (pin == null) return;
      await _passcode.setPasscode(pin);
      if (!mounted) return;
      setState(() => _passcodeEnabled = true);
      _toast('Passcode enabled', DS.green);
      return;
    }

    final pin = await _showVerifyPinDialog();
    if (pin == null) return;
    final attempt = await _passcode.verifyPasscode(pin);
    if (!attempt.ok) {
      _toast(
        attempt.isLockedOut
            ? 'Too many attempts. Try again in ${attempt.lockedFor!.inSeconds}s.'
            : 'Incorrect passcode',
        DS.error,
      );
      return;
    }
    await _passcode.disablePasscode();
    if (!mounted) return;
    setState(() {
      _passcodeEnabled = false;
      _biometricEnabled = false;
    });
    await _passcode.setBiometricEnabled(false);
    _toast('Passcode disabled', DS.green);
  }

  Future<void> _changePasscode() async {
    final oldPin = await _showVerifyPinDialog();
    if (oldPin == null) return;

    final attempt = await _passcode.verifyPasscode(oldPin);
    if (!attempt.ok) {
      _toast(
        attempt.isLockedOut
            ? 'Too many attempts. Try again in ${attempt.lockedFor!.inSeconds}s.'
            : 'Incorrect current passcode',
        DS.error,
      );
      return;
    }

    final newPin = await _showSetPinDialog('New Passcode');
    if (newPin == null) return;
    await _passcode.setPasscode(newPin);
    _toast('Passcode changed successfully', DS.green);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Prove the sensor works before relying on it, so enabling it can never
      // strand the owner outside their own payroll.
      final ok = await _passcode.authenticateBiometric();
      if (!ok) {
        _toast('Could not verify biometrics. Not enabled.', DS.warning);
        return;
      }
    }
    await _passcode.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  // ── PIN dialogs ──

  Future<String?> _showSetPinDialog(String title) async {
    String pin = '';
    String confirmPin = '';
    bool isConfirming = false;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onDigit(String digit) {
            if (digit == '⌫') {
              setDialogState(() {
                if (!isConfirming && pin.isNotEmpty) {
                  pin = pin.substring(0, pin.length - 1);
                } else if (isConfirming && confirmPin.isNotEmpty) {
                  confirmPin = confirmPin.substring(0, confirmPin.length - 1);
                }
              });
              return;
            }
            if (digit == 'C') {
              setDialogState(() {
                if (isConfirming) {
                  confirmPin = '';
                } else {
                  pin = '';
                }
                errorText = null;
              });
              return;
            }

            if (!isConfirming) {
              if (pin.length < 4) {
                setDialogState(() {
                  pin += digit;
                  errorText = null;
                });
                if (pin.length == 4) {
                  setDialogState(() => isConfirming = true);
                }
              }
              return;
            }

            if (confirmPin.length < 4) {
              setDialogState(() {
                confirmPin += digit;
                errorText = null;
              });
              if (confirmPin.length == 4) {
                if (pin == confirmPin) {
                  Navigator.of(ctx).pop(pin);
                } else {
                  setDialogState(() {
                    errorText = 'PINs do not match';
                    confirmPin = '';
                    isConfirming = false;
                    pin = '';
                  });
                }
              }
            }
          }

          return _PinDialog(
            title: isConfirming ? 'Confirm PIN' : title,
            errorText: errorText,
            filled: (isConfirming ? confirmPin : pin).length,
            onDigit: onDigit,
            onCancel: () => Navigator.of(ctx).pop(null),
          );
        },
      ),
    );
  }

  Future<String?> _showVerifyPinDialog() async {
    String pin = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onDigit(String digit) {
            if (digit == '⌫') {
              if (pin.isNotEmpty) {
                setDialogState(() => pin = pin.substring(0, pin.length - 1));
              }
              return;
            }
            if (digit == 'C') {
              setDialogState(() => pin = '');
              return;
            }
            if (pin.length < 4) {
              setDialogState(() => pin += digit);
              if (pin.length == 4) Navigator.of(ctx).pop(pin);
            }
          }

          return _PinDialog(
            title: 'Enter Current PIN',
            errorText: null,
            filled: pin.length,
            onDigit: onDigit,
            onCancel: () => Navigator.of(ctx).pop(null),
          );
        },
      ),
    );
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'APP CONFIGURATION',
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
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: DS.green),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('SECURITY'),
                        const SizedBox(height: 12),
                        _Card(
                          children: [
                            ListTile(
                              leading: const _TileIcon(
                                icon: Icons.lock_outline,
                                color: DS.tertiary,
                              ),
                              title: Text(
                                'App Lock',
                                style: DS.titleMd.copyWith(fontSize: 15),
                              ),
                              subtitle: Text(
                                _passcodeEnabled
                                    ? 'Passcode required on launch'
                                    : 'No passcode set',
                                style: DS.bodySm,
                              ),
                              trailing: Switch.adaptive(
                                value: _passcodeEnabled,
                                activeTrackColor: DS.green,
                                onChanged: _togglePasscode,
                              ),
                            ),
                            if (_passcodeEnabled) ...[
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              ListTile(
                                leading: const _TileIcon(
                                  icon: Icons.vpn_key_outlined,
                                  color: DS.secondary,
                                ),
                                title: Text(
                                  'Change Passcode',
                                  style: DS.titleMd.copyWith(fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Update your 4-digit PIN',
                                  style: DS.bodySm,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: DS.outlineVariant,
                                ),
                                onTap: _changePasscode,
                              ),
                              if (_biometricAvailable) ...[
                                const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                ListTile(
                                  leading: const _TileIcon(
                                    icon: Icons.fingerprint,
                                    color: DS.green,
                                  ),
                                  title: Text(
                                    'Unlock with Biometrics',
                                    style: DS.titleMd.copyWith(fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    'Fingerprint or face, with the PIN as fallback',
                                    style: DS.bodySm,
                                  ),
                                  trailing: Switch.adaptive(
                                    value: _biometricEnabled,
                                    activeTrackColor: DS.green,
                                    onChanged: _toggleBiometric,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),

                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'The passcode is stored only on this phone, hashed '
                            'with PBKDF2. It is never sent to the cloud.',
                            style: DS.bodySm.copyWith(fontSize: 11),
                          ),
                        ),

                        const SizedBox(height: 24),
                        _SectionLabel('DATA'),
                        const SizedBox(height: 12),
                        _Card(
                          children: [
                            ListTile(
                              leading: const _TileIcon(
                                icon: Icons.history,
                                color: DS.warning,
                              ),
                              title: Text(
                                'Edit History',
                                style: DS.titleMd.copyWith(fontSize: 15),
                              ),
                              subtitle: Text(
                                'Every change to workers, attendance, advances and payments',
                                style: DS.bodySm,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: DS.outlineVariant,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuditLogScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _SectionLabel('ABOUT'),
                        const SizedBox(height: 12),
                        _Card(
                          children: [
                            ListTile(
                              leading: const _TileIcon(
                                icon: Icons.construction,
                                color: DS.green,
                              ),
                              title: Text(
                                'Labour Manager',
                                style: DS.titleMd.copyWith(fontSize: 15),
                              ),
                              subtitle: Text(
                                'Version $_version',
                                style: DS.bodySm,
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const _TileIcon(
                                icon: Icons.badge_outlined,
                                color: DS.onSurfaceVariant,
                              ),
                              title: Text(
                                'This device',
                                style: DS.titleMd.copyWith(fontSize: 15),
                              ),
                              subtitle: Text(
                                AuthService().isSignedIn
                                    ? 'Signed in · ${AuthService.shortActor(AuthService().actorId)}'
                                    : 'Not signed in — changes may be rejected',
                                style: DS.bodySm.copyWith(
                                  color: AuthService().isSignedIn
                                      ? DS.onSurfaceVariant
                                      : DS.error,
                                ),
                              ),
                            ),
                          ],
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

// ── Section Label ──
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5));
}

// ── Card ──
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DS.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadowLight,
      ),
      child: Column(children: children),
    );
  }
}

// ── Tile Icon ──
class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _TileIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── PIN Dialog ──
class _PinDialog extends StatelessWidget {
  final String title;
  final String? errorText;
  final int filled;
  final void Function(String) onDigit;
  final VoidCallback onCancel;

  const _PinDialog({
    required this.title,
    required this.errorText,
    required this.filled,
    required this.onDigit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DS.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: DS.fontHeadline,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (errorText != null)
              Text(
                errorText!,
                style: const TextStyle(
                  fontFamily: DS.fontBody,
                  fontSize: 13,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            const SizedBox(height: 20),
            PinDots(filled: filled, isError: errorText != null),
            const SizedBox(height: 24),
            DialogKeypad(onDigit: onDigit),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancel,
              child: Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: DS.fontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(150),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PIN Dots (shared with the lock screen) ──
class PinDots extends StatelessWidget {
  final int filled;
  final bool isError;
  final double size;

  const PinDots({
    super.key,
    required this.filled,
    this.isError = false,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isFilled = i < filled;
        final color = isError
            ? const Color(0xFFFF6B6B)
            : isFilled
            ? DS.green
            : Colors.white.withAlpha(30);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? size : size - 4,
          height: isFilled ? size : size - 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DS.radiusFull),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFF6B6B)
                  : isFilled
                  ? DS.green
                  : Colors.white.withAlpha(50),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

// ── Compact Keypad (shared with the lock screen) ──
class DialogKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  final double keySize;

  const DialogKeypad({super.key, required this.onDigit, this.keySize = 56});

  static const List<List<String>> keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              final isAction = key == 'C' || key == '⌫';
              return GestureDetector(
                onTap: () => onDigit(key),
                child: Container(
                  width: keySize,
                  height: keySize,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(isAction ? 8 : 12),
                    borderRadius: BorderRadius.circular(DS.radiusFull),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    key,
                    style: TextStyle(
                      fontFamily: DS.fontHeadline,
                      fontSize: isAction ? 14 : 22,
                      fontWeight: FontWeight.w600,
                      color: isAction
                          ? Colors.white.withAlpha(120)
                          : Colors.white,
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
