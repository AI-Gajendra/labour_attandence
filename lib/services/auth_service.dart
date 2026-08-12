import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Identity for the app.
///
/// The product deliberately has no login screen — one trusted person holds the
/// device. But Firestore still needs *some* authenticated principal so the
/// security rules can stop being `allow read, write: if true`, and the audit
/// trail needs something better than the hardcoded string `'admin_1'`.
///
/// Anonymous auth gives both: a stable per-install uid, no UX change, and a
/// credential that persists across restarts (so a cold start offline still has
/// a signed-in user — only the *first* launch needs network).
///
/// **Known limitation:** anyone holding the APK can also obtain an anonymous
/// credential, so `request.auth != null` alone does not stop a determined
/// attacker. Firebase App Check (Play Integrity) is the next control, and
/// phone auth with a uid allow-list after that. See CLAUDE.md §8.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;
  AuthService._internal();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Value written to `createdBy` / `changedBy`.
  ///
  /// Falls back to `'unknown'` rather than throwing, so a write is never lost
  /// just because sign-in has not completed.
  String get actorId => _auth.currentUser?.uid ?? 'unknown';

  /// Short readable form of an actor id, for the audit log UI.
  static String shortActor(String id) {
    if (id.isEmpty) return 'unknown';
    // Legacy records carry the literal 'admin_1'.
    if (!id.contains(RegExp(r'[A-Za-z0-9]{20,}'))) return id;
    return '${id.substring(0, 6)}…';
  }

  /// Signs in anonymously if there is no current user.
  ///
  /// Returns the signed-in user, or null if sign-in could not complete (no
  /// network on first launch, anonymous provider disabled in the console).
  /// Never throws — callers should degrade rather than block the UI.
  Future<User?> ensureSignedIn({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    try {
      final credential = await _auth.signInAnonymously().timeout(timeout);
      return credential.user;
    } catch (e) {
      debugPrint('AuthService: anonymous sign-in failed — $e');
      return null;
    }
  }
}
