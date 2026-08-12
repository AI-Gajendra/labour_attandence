import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Optional redirect of Firebase traffic to the local Emulator Suite.
///
/// The integration tests previously ran against the **production** Firestore
/// project, writing `__test_`-prefixed documents into live data and leaving
/// orphans behind whenever a run crashed. With this, they can run against
/// `firebase emulators:start` instead:
///
/// ```
/// flutter test integration_test/firestore_test.dart -d <device> \
///   --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Host defaults to `10.0.2.2` — the loopback alias an Android emulator uses to
/// reach the host machine. Pass `--dart-define=FIREBASE_EMULATOR_HOST=<ip>` for
/// a physical device on the same network.
class EmulatorConfig {
  EmulatorConfig._();

  static const bool enabled = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const String host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  static const int firestorePort = 8080;
  static const int authPort = 9099;

  static bool _applied = false;

  /// Points Firestore and Auth at the emulator when enabled. No-op otherwise.
  static Future<void> apply() async {
    if (!enabled || _applied) return;
    _applied = true;
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    debugPrint(
      'Firebase: using emulators at $host '
      '(firestore:$firestorePort, auth:$authPort)',
    );
  }
}
