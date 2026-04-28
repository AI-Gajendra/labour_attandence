import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing passcode authentication via Firestore.
/// Stores passcode as a simple hash in `settings/passcode` document.
class PasscodeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final PasscodeService _instance = PasscodeService._internal();

  factory PasscodeService() => _instance;
  PasscodeService._internal();

  static const String _collection = 'settings';
  static const String _docId = 'passcode';

  /// Simple hash for a 4-digit PIN (base64 of UTF-8 bytes).
  /// Not cryptographically strong, but sufficient for a local-use labor app.
  String _hashPin(String pin) {
    final bytes = utf8.encode('labour_mgr_salt_$pin');
    return base64Encode(bytes);
  }

  /// Check if passcode is enabled.
  Future<bool> isPasscodeEnabled() async {
    final doc = await _db.collection(_collection).doc(_docId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    return data?['enabled'] == true;
  }

  /// Verify a passcode attempt.
  Future<bool> verifyPasscode(String pin) async {
    final doc = await _db.collection(_collection).doc(_docId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data?['enabled'] != true) return true; // not enabled = always pass
    return data?['hash'] == _hashPin(pin);
  }

  /// Set or update the passcode.
  Future<void> setPasscode(String pin) async {
    await _db.collection(_collection).doc(_docId).set({
      'hash': _hashPin(pin),
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Disable the passcode (keeps hash for re-enable).
  Future<void> disablePasscode() async {
    await _db.collection(_collection).doc(_docId).update({
      'enabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Enable the passcode (uses existing hash).
  Future<void> enablePasscode() async {
    final doc = await _db.collection(_collection).doc(_docId).get();
    if (!doc.exists || doc.data()?['hash'] == null) {
      throw Exception('No passcode set. Set a passcode first.');
    }
    await _db.collection(_collection).doc(_docId).update({
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Change passcode (requires old PIN verification).
  Future<bool> changePasscode(String oldPin, String newPin) async {
    final isValid = await verifyPasscode(oldPin);
    if (!isValid) return false;
    await setPasscode(newPin);
    return true;
  }
}
