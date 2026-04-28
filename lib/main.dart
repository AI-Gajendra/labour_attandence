import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/worker_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/summary_provider.dart';
import 'screens/main_screen.dart';
import 'screens/passcode_screen.dart';
import 'services/passcode_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        theme: ThemeData(
          fontFamily: 'Inter',
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFAF9F6),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF121826),
            secondary: Color(0xFF006C49),
            surface: Color(0xFFFAF9F6),
            error: Color(0xFFBA1A1A),
            onPrimary: Color(0xFFFFFFFF),
            onSecondary: Color(0xFFFFFFFF),
            onSurface: Color(0xFF1A1C1A),
            onError: Color(0xFFFFFFFF),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121826),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFFFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const _AppGate(),
      ),
    );
  }
}

/// Gate that shows passcode screen if enabled, otherwise goes straight to main.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _unlocked = false;
  bool? _passcodeEnabled;

  @override
  void initState() {
    super.initState();
    _checkPasscode();
  }

  Future<void> _checkPasscode() async {
    final enabled = await PasscodeService().isPasscodeEnabled();
    if (!mounted) return;
    setState(() {
      _passcodeEnabled = enabled;
      _unlocked = !enabled; // auto-unlock if passcode is disabled
    });
  }

  @override
  Widget build(BuildContext context) {
    // Still loading
    if (_passcodeEnabled == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121826),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    // Passcode enabled and not yet unlocked
    if (!_unlocked) {
      return PasscodeScreen(
        onUnlocked: () => setState(() => _unlocked = true),
      );
    }

    // Unlocked — show main app
    return const MainScreen();
  }
}
