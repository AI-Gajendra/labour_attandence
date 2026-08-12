# Labour Attendance (Labour Manager)

A Flutter + Firebase app for a small labour / electrical contractor to run daily workforce
administration from a phone: attendance, advances (*kharchi*), monthly payroll and an audit trail.

Project context, architecture and conventions live in **[CLAUDE.md](CLAUDE.md)** — read that first.
Planned work is in **[improvement.md](improvement.md)**.

## Getting Started

This project relies on Firebase and requires configuration files that are deliberately kept out of
version control.

1. **Firebase configuration**
   Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart` and fill in your real
   Firebase project values.

2. **Android local properties**
   Copy `android/local.properties.example` to `android/local.properties` and set your Android SDK path.

3. **Android keystore** (only for release builds)
   Copy `android/key.properties.example` to `android/key.properties` and fill in your keystore details.

4. **Enable Anonymous authentication**
   Firebase Console → Authentication → Sign-in method → **Anonymous** → Enable.
   The app signs in anonymously at startup and `firestore.rules` requires an authenticated
   principal, so without this every read and write is denied.

Then:

```bash
flutter pub get
flutter run
```

## Common commands

```bash
flutter analyze                 # must stay at zero issues
flutter test                    # unit tests (no Firebase needed)
flutter build apk --release
flutter build appbundle --release

firebase deploy --only firestore:rules
```

### Integration tests

These talk to a real Firestore. Prefer the emulator:

```bash
firebase emulators:start --only firestore,auth
flutter test integration_test/firestore_test.dart -d <deviceId> \
  --dart-define=USE_FIREBASE_EMULATOR=true
```

Without the flag they run against the production project.

## License

This software is **PROPRIETARY AND CONFIDENTIAL**.

It is licensed for **in-house use only**. Commercial use, distribution, reverse engineering, or
selling of this software is strictly prohibited. See [LICENSE](LICENSE) for details.
