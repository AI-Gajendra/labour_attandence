import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'design_tokens.dart';
import 'providers/worker_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/summary_provider.dart';
import 'screens/main_screen.dart';
import 'screens/passcode_screen.dart';
import 'services/auth_service.dart';
import 'services/emulator_config.dart';
import 'services/passcode_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Offline persistence is the default on mobile, but state it explicitly:
    // this app is expected to run all day on sites with no signal, and the
    // cache is what makes that work.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // No-op unless built with --dart-define=USE_FIREBASE_EMULATOR=true.
    await EmulatorConfig.apply();
  } catch (e) {
    // A failed Firebase init must show an explanation, not a blank crash.
    startupError = e;
    debugPrint('Firebase init failed: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  final Object? startupError;
  const MyApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkerProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => SummaryProvider()),
      ],
      child: MaterialApp(
        title: 'Labour Manager',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: startupError == null
            ? const _AppGate()
            : _StartupFailure(error: startupError!),
      ),
    );
  }

  static ThemeData get _theme => ThemeData(
    fontFamily: DS.fontBody,
    brightness: Brightness.light,
    scaffoldBackgroundColor: DS.surface,
    colorScheme: const ColorScheme.light(
      primary: DS.primaryContainer,
      secondary: DS.secondary,
      surface: DS.surface,
      error: DS.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: DS.onSurface,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DS.primaryContainer,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: DS.fontHeadline,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DS.green,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radiusLg),
        ),
        textStyle: const TextStyle(
          fontFamily: DS.fontHeadline,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: DS.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusLg),
      ),
    ),
  );
}

/// Startup gate: signs in, migrates the legacy passcode, then either shows the
/// lock screen or the app.
///
/// Every step here is bounded and failure-tolerant. The previous version awaited
/// a Firestore read with no `catch` and no timeout, so a cold start with no
/// network and no cache left the app on a spinner **forever** — which is
/// exactly the situation this app is built for.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

enum _GateState { loading, locked, unlocked, failed }

class _AppGateState extends State<_AppGate> {
  _GateState _state = _GateState.loading;
  String _failureDetail = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _state = _GateState.loading);
    try {
      // Anonymous sign-in: needed so Firestore rules can require auth. Never
      // throws; returns null if it could not complete.
      await AuthService().ensureSignedIn(timeout: const Duration(seconds: 6));

      // One-time move of any legacy Firestore passcode onto the device. The
      // timeout bounds the Firestore read only — see PasscodeService.initialize.
      await PasscodeService().initialize(
        networkTimeout: const Duration(seconds: 4),
      );

      // Local read — cannot hang on the network.
      final locked = await PasscodeService().isPasscodeEnabled();

      if (!mounted) return;
      setState(() => _state = locked ? _GateState.locked : _GateState.unlocked);
    } catch (e) {
      debugPrint('_AppGate bootstrap failed: $e');
      if (!mounted) return;
      setState(() {
        _failureDetail = '$e';
        _state = _GateState.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return const _SplashScaffold(
          child: CircularProgressIndicator(color: DS.green),
        );

      case _GateState.failed:
        return _SplashScaffold(
          child: _GateFailure(
            detail: _failureDetail,
            onRetry: _bootstrap,
            onContinue: () => setState(() => _state = _GateState.unlocked),
          ),
        );

      case _GateState.locked:
        return PasscodeScreen(
          onUnlocked: () => setState(() => _state = _GateState.unlocked),
        );

      case _GateState.unlocked:
        return const MainScreen();
    }
  }
}

// ── Splash Scaffold ──
class _SplashScaffold extends StatelessWidget {
  final Widget child;
  const _SplashScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.primaryContainer,
      body: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: child),
      ),
    );
  }
}

// ── Gate Failure ──
class _GateFailure extends StatelessWidget {
  final String detail;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  const _GateFailure({
    required this.detail,
    required this.onRetry,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, color: Colors.white54, size: 56),
        const SizedBox(height: 20),
        const Text(
          'Could not finish starting up',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: DS.fontHeadline,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: DS.fontBody,
            fontSize: 12,
            color: Colors.white.withAlpha(140),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onContinue,
          child: Text(
            'CONTINUE OFFLINE',
            style: TextStyle(
              fontFamily: DS.fontBody,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(160),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Startup Failure (Firebase init) ──
class _StartupFailure extends StatelessWidget {
  final Object error;
  const _StartupFailure({required this.error});

  @override
  Widget build(BuildContext context) {
    return _SplashScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: DS.warning, size: 56),
          const SizedBox(height: 20),
          const Text(
            'Firebase could not start',
            style: TextStyle(
              fontFamily: DS.fontHeadline,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check that lib/firebase_options.dart holds valid values.\n\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DS.fontBody,
              fontSize: 12,
              color: Colors.white.withAlpha(140),
            ),
          ),
        ],
      ),
    );
  }
}
