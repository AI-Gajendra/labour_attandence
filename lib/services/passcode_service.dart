import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a passcode attempt.
class PasscodeAttempt {
  /// The PIN matched.
  final bool ok;

  /// Non-null when the device is currently locked out; how long remains.
  final Duration? lockedFor;

  /// Failed attempts left before the next lockout. -1 when unknown.
  final int attemptsRemaining;

  const PasscodeAttempt.success()
    : ok = true,
      lockedFor = null,
      attemptsRemaining = _maxAttempts;

  const PasscodeAttempt.failed(this.attemptsRemaining)
    : ok = false,
      lockedFor = null;

  const PasscodeAttempt.lockedOut(Duration remaining)
    : ok = false,
      lockedFor = remaining,
      attemptsRemaining = 0;

  bool get isLockedOut => lockedFor != null;

  static const int _maxAttempts = 5;
}

/// Device-local passcode lock.
///
/// ## What changed and why
///
/// The previous implementation stored `base64(utf8('labour_mgr_salt_' + pin))`
/// in a **world-readable Firestore document**. Base64 is an encoding, not a
/// hash — it reverses in one line — so the PIN was effectively published.
///
/// This version:
/// * derives the verifier with **PBKDF2-HMAC-SHA256** ([_iterations] rounds)
///   over a per-install 16-byte random salt;
/// * keeps everything in **OS-backed secure storage on the device**, never in
///   Firestore — the lock is a device concern and has no business being in a
///   shared database;
/// * **throttles** attempts, so a 4-digit PIN's 10 000-value keyspace cannot be
///   walked in a sitting;
/// * offers **optional biometric unlock** that always falls back to the PIN, so
///   a sensor failure can never lock the owner out of their own payroll.
///
/// On first run it migrates any legacy Firestore passcode (recovering the PIN
/// from the reversible legacy encoding), then deletes the remote document.
class PasscodeService {
  static final PasscodeService _instance = PasscodeService._internal();
  factory PasscodeService() => _instance;
  PasscodeService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Secure-storage keys.
  static const String _kSalt = 'passcode_salt_v2';
  static const String _kHash = 'passcode_hash_v2';
  static const String _kEnabled = 'passcode_enabled_v2';
  static const String _kFailCount = 'passcode_fail_count_v2';
  static const String _kLockUntil = 'passcode_lock_until_v2';
  static const String _kBiometric = 'passcode_biometric_v2';
  static const String _kMigrated = 'passcode_migrated_v2';

  // Legacy (insecure) location, kept only so it can be migrated away.
  static const String _legacyCollection = 'settings';
  static const String _legacyDoc = 'passcode';
  static const String _legacySaltPrefix = 'labour_mgr_salt_';

  static const int _iterations = 50000;
  static const int _keyLength = 32;
  static const int _maxAttempts = PasscodeAttempt._maxAttempts;
  static const Duration _baseLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(minutes: 15);

  bool _initialised = false;

  // ── Lifecycle ──

  /// Prepares the service. Safe to call more than once.
  ///
  /// Attempts the one-time legacy migration; a failure here (offline, rules
  /// denied) is swallowed and retried on the next launch — it must never block
  /// the app from starting.
  ///
  /// [networkTimeout] bounds **only the Firestore read**. It deliberately does
  /// not cover key derivation: PBKDF2 plus an isolate spawn can take several
  /// seconds on a cold low-end device, and an earlier version that timed the
  /// whole migration would give up, let the gate through unlocked, and then
  /// finish migrating in the background — so the very launch that imported the
  /// passcode was the one that didn't enforce it. Local work always completes;
  /// only the network can hang, so only the network is timed.
  Future<void> initialize({
    Duration networkTimeout = const Duration(seconds: 5),
  }) async {
    if (_initialised) return;
    _initialised = true;
    try {
      await _migrateLegacyPasscode(networkTimeout: networkTimeout);
    } catch (e) {
      debugPrint('PasscodeService: legacy migration skipped — $e');
    }
  }

  // ── Queries ──

  /// Whether the lock screen should be shown. Reads local storage only, so it
  /// works offline and cannot hang on the network.
  Future<bool> isPasscodeEnabled() async {
    try {
      final enabled = await _storage.read(key: _kEnabled);
      final hash = await _storage.read(key: _kHash);
      return enabled == 'true' && hash != null && hash.isNotEmpty;
    } catch (e) {
      debugPrint('PasscodeService: enabled-check failed — $e');
      return false; // fail open: never trap the owner behind a broken lock
    }
  }

  /// Whether a passcode has ever been set (independent of enabled state).
  Future<bool> hasPasscode() async {
    final hash = await _storage.read(key: _kHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Remaining lockout, or null when not locked out.
  Future<Duration?> currentLockout() async {
    final raw = await _storage.read(key: _kLockUntil);
    if (raw == null) return null;
    final until = int.tryParse(raw);
    if (until == null) return null;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : null;
  }

  // ── Verification ──

  /// Checks [pin], applying lockout policy.
  Future<PasscodeAttempt> verifyPasscode(String pin) async {
    final lockout = await currentLockout();
    if (lockout != null) return PasscodeAttempt.lockedOut(lockout);

    final storedHash = await _storage.read(key: _kHash);
    final storedSalt = await _storage.read(key: _kSalt);
    if (storedHash == null || storedSalt == null) {
      // No passcode configured — nothing to verify against.
      return const PasscodeAttempt.success();
    }

    final candidate = await _derive(pin, base64Decode(storedSalt));
    if (_constantTimeEquals(candidate, storedHash)) {
      await _resetFailures();
      return const PasscodeAttempt.success();
    }

    return _recordFailure();
  }

  Future<PasscodeAttempt> _recordFailure() async {
    final previous =
        int.tryParse(await _storage.read(key: _kFailCount) ?? '') ?? 0;
    final failures = previous + 1;
    await _storage.write(key: _kFailCount, value: '$failures');

    if (failures < _maxAttempts) {
      return PasscodeAttempt.failed(_maxAttempts - failures);
    }

    // Doubling backoff from the 5th failure onwards, capped.
    final overshoot = failures - _maxAttempts;
    var lock = _baseLockout * pow(2, overshoot).toDouble();
    if (lock > _maxLockout) lock = _maxLockout;

    final until = DateTime.now().add(lock).millisecondsSinceEpoch;
    await _storage.write(key: _kLockUntil, value: '$until');
    return PasscodeAttempt.lockedOut(lock);
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _kFailCount);
    await _storage.delete(key: _kLockUntil);
  }

  // ── Mutation ──

  /// Sets (or replaces) the passcode and enables the lock.
  Future<void> setPasscode(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _derive(pin, salt);
    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _storage.write(key: _kHash, value: hash);
    await _storage.write(key: _kEnabled, value: 'true');
    await _resetFailures();
  }

  /// Turns the lock off but keeps the stored hash so it can be re-enabled.
  Future<void> disablePasscode() async {
    await _storage.write(key: _kEnabled, value: 'false');
    await _resetFailures();
  }

  // Changing a passcode is verify-then-[setPasscode], driven by the Settings
  // screen so the user learns their old PIN was wrong *before* being asked to
  // invent a new one. A combined `changePasscode(old, new)` helper previously
  // existed here but nothing ever called it.

  // ── Biometrics (optional, always falls back to the PIN) ──

  /// Whether this device has usable biometric or device-credential auth.
  Future<bool> biometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('PasscodeService: biometric probe failed — $e');
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _kBiometric)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _kBiometric, value: enabled ? 'true' : 'false');

  /// Prompts for biometric unlock. Returns false on any failure — the caller
  /// simply stays on the PIN pad.
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Labour Manager',
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('PasscodeService: biometric auth failed — $e');
      return false;
    }
  }

  // ── Legacy migration ──

  /// One-time move of the old reversible Firestore passcode onto the device.
  ///
  /// The legacy value was `base64('labour_mgr_salt_' + pin)`, so the PIN can be
  /// recovered and re-derived properly. Afterwards the remote document is
  /// deleted — it should never have existed.
  Future<void> _migrateLegacyPasscode({
    required Duration networkTimeout,
  }) async {
    if (await _storage.read(key: _kMigrated) == 'true') return;
    if (await hasPasscode()) {
      await _storage.write(key: _kMigrated, value: 'true');
      return;
    }

    // The only step that can hang. Everything after this point is local.
    final doc = await _db
        .collection(_legacyCollection)
        .doc(_legacyDoc)
        .get()
        .timeout(networkTimeout);
    if (!doc.exists) {
      await _storage.write(key: _kMigrated, value: 'true');
      return;
    }

    final data = doc.data();
    final legacyHash = data?['hash'] as String?;
    final wasEnabled = data?['enabled'] == true;

    if (legacyHash != null && legacyHash.isNotEmpty) {
      final pin = _recoverLegacyPin(legacyHash);
      if (pin != null) {
        await setPasscode(pin);
        if (!wasEnabled) await disablePasscode();
        debugPrint('PasscodeService: migrated legacy passcode to device.');
      }
    }

    // Remove the world-readable copy regardless of whether recovery worked.
    try {
      await doc.reference.delete();
    } catch (e) {
      debugPrint('PasscodeService: could not delete legacy doc — $e');
    }
    await _storage.write(key: _kMigrated, value: 'true');
  }

  String? _recoverLegacyPin(String legacyHash) {
    try {
      final decoded = utf8.decode(base64Decode(legacyHash));
      if (!decoded.startsWith(_legacySaltPrefix)) return null;
      final pin = decoded.substring(_legacySaltPrefix.length);
      return pin.isEmpty ? null : pin;
    } catch (_) {
      return null;
    }
  }

  // ── Crypto ──

  /// PBKDF2-HMAC-SHA256, returned base64-encoded.
  ///
  /// Run off the UI isolate: [_iterations] rounds is deliberately slow.
  Future<String> _derive(String pin, Uint8List salt) async {
    final bytes = await compute(
      _pbkdf2Worker,
      _Pbkdf2Request(
        pin: pin,
        salt: salt,
        iterations: _iterations,
        length: _keyLength,
      ),
    );
    return base64Encode(bytes);
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// Length-independent comparison, to avoid leaking match length by timing.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

// ── PBKDF2 implementation (top-level so it can run in an isolate) ──

class _Pbkdf2Request {
  final String pin;
  final Uint8List salt;
  final int iterations;
  final int length;

  const _Pbkdf2Request({
    required this.pin,
    required this.salt,
    required this.iterations,
    required this.length,
  });
}

Uint8List _pbkdf2Worker(_Pbkdf2Request request) {
  final hmac = Hmac(sha256, utf8.encode(request.pin));
  final output = <int>[];
  var blockIndex = 1;

  while (output.length < request.length) {
    final block = <int>[
      ...request.salt,
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];

    var u = hmac.convert(block).bytes;
    final accumulated = List<int>.from(u);
    for (var i = 1; i < request.iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < accumulated.length; j++) {
        accumulated[j] ^= u[j];
      }
    }

    output.addAll(accumulated);
    blockIndex++;
  }

  return Uint8List.fromList(output.sublist(0, request.length));
}
