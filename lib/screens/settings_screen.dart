import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../services/passcode_service.dart';
import 'audit_log_screen.dart';

/// Settings screen for passcode management and app configuration.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _passcodeEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPasscodeStatus();
  }

  Future<void> _loadPasscodeStatus() async {
    final enabled = await PasscodeService().isPasscodeEnabled();
    if (!mounted) return;
    setState(() {
      _passcodeEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _togglePasscode(bool value) async {
    if (value) {
      // Enable: ask user to set a new PIN
      final pin = await _showSetPinDialog('Set Passcode');
      if (pin == null) return;
      await PasscodeService().setPasscode(pin);
      if (!mounted) return;
      setState(() => _passcodeEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passcode enabled'),
          backgroundColor: DS.green,
        ),
      );
    } else {
      // Disable: ask for current PIN first
      final pin = await _showVerifyPinDialog();
      if (pin == null) return;
      final ok = await PasscodeService().verifyPasscode(pin);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect passcode'),
            backgroundColor: DS.error,
          ),
        );
        return;
      }
      await PasscodeService().disablePasscode();
      if (!mounted) return;
      setState(() => _passcodeEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passcode disabled'),
          backgroundColor: DS.green,
        ),
      );
    }
  }

  Future<void> _changePasscode() async {
    final oldPin = await _showVerifyPinDialog();
    if (oldPin == null) return;
    final ok = await PasscodeService().verifyPasscode(oldPin);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect current passcode'),
          backgroundColor: DS.error,
        ),
      );
      return;
    }
    final newPin = await _showSetPinDialog('New Passcode');
    if (newPin == null) return;
    await PasscodeService().setPasscode(newPin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passcode changed successfully'),
        backgroundColor: DS.green,
      ),
    );
  }

  /// Dialog to set a new 4-digit PIN.
  Future<String?> _showSetPinDialog(String title) async {
    String pin = '';
    String confirmPin = '';
    bool isConfirming = false;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void onDigit(String digit) {
              if (digit == '⌫') {
                if (!isConfirming && pin.isNotEmpty) {
                  setDialogState(() => pin = pin.substring(0, pin.length - 1));
                } else if (isConfirming && confirmPin.isNotEmpty) {
                  setDialogState(() => confirmPin = confirmPin.substring(0, confirmPin.length - 1));
                }
                return;
              }
              if (digit == 'C') {
                setDialogState(() {
                  if (!isConfirming) {
                    pin = '';
                  } else {
                    confirmPin = '';
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
              } else {
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
            }

            final currentPin = isConfirming ? confirmPin : pin;

            return Dialog(
              backgroundColor: DS.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusXl)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isConfirming ? 'Confirm PIN' : title,
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
                    // PIN Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < currentPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: filled ? 18 : 14,
                          height: filled ? 18 : 14,
                          decoration: BoxDecoration(
                            color: filled ? DS.green : Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(DS.radiusFull),
                            border: Border.all(
                              color: filled ? DS.green : Colors.white.withAlpha(50),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Mini keypad
                    _DialogKeypad(onDigit: onDigit),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
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
          },
        );
      },
    );
  }

  /// Dialog to verify current PIN.
  Future<String?> _showVerifyPinDialog() async {
    String pin = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
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
                if (pin.length == 4) {
                  Navigator.of(ctx).pop(pin);
                }
              }
            }

            return Dialog(
              backgroundColor: DS.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusXl)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter Current PIN',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: filled ? 18 : 14,
                          height: filled ? 18 : 14,
                          decoration: BoxDecoration(
                            color: filled ? DS.green : Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(DS.radiusFull),
                            border: Border.all(
                              color: filled ? DS.green : Colors.white.withAlpha(50),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    _DialogKeypad(onDigit: onDigit),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
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
          },
        );
      },
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
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'APP CONFIGURATION',
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
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: DS.green))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Security Section ──
                        Text(
                          'SECURITY',
                          style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: DS.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(DS.radiusLg),
                            boxShadow: DS.cardShadowLight,
                          ),
                          child: Column(
                            children: [
                              // Toggle passcode
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: DS.tertiary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(DS.radiusMd),
                                  ),
                                  child: const Icon(Icons.lock_outline, color: DS.tertiary, size: 20),
                                ),
                                title: Text('App Lock', style: DS.titleMd.copyWith(fontSize: 15)),
                                subtitle: Text(
                                  _passcodeEnabled ? 'Passcode required on launch' : 'No passcode set',
                                  style: DS.bodySm,
                                ),
                                trailing: Switch.adaptive(
                                  value: _passcodeEnabled,
                                  activeTrackColor: DS.green,
                                  onChanged: _togglePasscode,
                                ),
                              ),
                              if (_passcodeEnabled) ...[
                                const Divider(height: 1, indent: 16, endIndent: 16),
                                // Change passcode
                                ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: DS.secondary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(DS.radiusMd),
                                    ),
                                    child: const Icon(Icons.vpn_key_outlined, color: DS.secondary, size: 20),
                                  ),
                                  title: Text('Change Passcode', style: DS.titleMd.copyWith(fontSize: 15)),
                                  subtitle: Text('Update your 4-digit PIN', style: DS.bodySm),
                                  trailing: const Icon(Icons.chevron_right, color: DS.outlineVariant),
                                  onTap: _changePasscode,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Audit Section ──
                        Text(
                          'DATA',
                          style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: DS.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(DS.radiusLg),
                            boxShadow: DS.cardShadowLight,
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(20),
                                borderRadius: BorderRadius.circular(DS.radiusMd),
                              ),
                              child: const Icon(Icons.history, color: Color(0xFFF59E0B), size: 20),
                            ),
                            title: Text('Edit History', style: DS.titleMd.copyWith(fontSize: 15)),
                            subtitle: Text('View all data changes', style: DS.bodySm),
                            trailing: const Icon(Icons.chevron_right, color: DS.outlineVariant),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── App Info ──
                        Text(
                          'ABOUT',
                          style: DS.labelSm.copyWith(fontSize: 10, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                  color: DS.green.withAlpha(20),
                                  borderRadius: BorderRadius.circular(DS.radiusMd),
                                ),
                                child: const Icon(Icons.construction, color: DS.green, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Labour Manager', style: DS.titleMd.copyWith(fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('Version 0.2.0', style: DS.bodySm),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Compact Keypad for Dialogs ──
class _DialogKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  const _DialogKeypad({required this.onDigit});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

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
                  width: 56,
                  height: 56,
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
                      color: isAction ? Colors.white.withAlpha(120) : Colors.white,
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
