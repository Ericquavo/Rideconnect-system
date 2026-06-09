import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth/auth_api.dart';
import 'auth/auth_session.dart';
import 'pages/driver/driver_dashboard.dart';
import 'pages/login_page.dart';
import 'pages/passenger/passenger_dashboard.dart';
import 'features/trips/presentation/pages/trip_matching_page.dart';
import 'features/trips/services/trip_lifecycle_manager.dart';
import 'services/app_theme_service.dart';
import 'services/driver_preferences_service.dart';
import 'services/passenger_preferences_service.dart';
import 'services/passenger_language_service.dart';
import 'services/driver_language_service.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeService.init();
  await DriverPreferencesService.init();
  await PassengerPreferencesService.init();
  await PassengerLanguageService.instance.init();
  await DriverLanguageService.instance.ensureInitialized();
  await FcmService.instance.initialize();
  assert(() {
    // Ensure debug baseline overlays are off in dev mode.
    debugPaintBaselinesEnabled = false;
    return true;
  }());
  runApp(const ProviderScope(child: RideConnectApp()));
}

class RideConnectApp extends StatefulWidget {
  const RideConnectApp({super.key});

  @override
  State<RideConnectApp> createState() => _RideConnectAppState();
}

class _RideConnectAppState extends State<RideConnectApp> {
  @override
  void initState() {
    super.initState();
    AppThemeService.themeModeNotifier.addListener(_onThemeOrLanguageChanged);
    PassengerLanguageService.instance.languageNotifier.addListener(
      _onThemeOrLanguageChanged,
    );
    DriverLanguageService.instance.languageNotifier.addListener(
      _onThemeOrLanguageChanged,
    );
  }

  @override
  void dispose() {
    AppThemeService.themeModeNotifier.removeListener(_onThemeOrLanguageChanged);
    PassengerLanguageService.instance.languageNotifier.removeListener(
      _onThemeOrLanguageChanged,
    );
    DriverLanguageService.instance.languageNotifier.removeListener(
      _onThemeOrLanguageChanged,
    );
    super.dispose();
  }

  void _onThemeOrLanguageChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeService.themeModeNotifier.value;
    return MaterialApp(
      title: 'RideConnect',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4C57D6),
          secondary: Color(0xFF2D8CFF),
          surface: Color(0xFFF5F7FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F5FF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF0A0E1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      ),
      home: const AppEntryPage(),
    );
  }
}

class AppEntryPage extends StatefulWidget {
  const AppEntryPage({super.key});

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  late final Future<AuthSessionData?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _resolveSession();
  }

  Future<AuthSessionData?> _resolveSession() async {
    final session = await AuthSession.load();
    if (session == null) return null;

    final token = session.token;
    if (token == null || token.trim().isEmpty) {
      await AuthSession.clear();
      return null;
    }

    final isValid = await AuthApi.validateToken(token: token);
    if (!isValid) {
      await AuthSession.clear();
      return null;
    }

    return session;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSessionData?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF),
            body: Center(
              child: const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
          );
        }

        final session = snapshot.data;
        if (session == null) {
          return const LoginPage();
        }

        final normalizedRole = session.role.trim().toLowerCase();
        final isPassenger =
            normalizedRole == 'passenger' || normalizedRole == 'rider';
        final isDriver = normalizedRole == 'driver';

        if (isPassenger) {
          return PassengerStartupGate(
            passengerName: session.name,
            passengerEmail: session.email,
          );
        }

        if (isDriver) {
          return DriverDashboard(
            driverName: session.name,
            driverEmail: session.email,
          );
        }

        return const LoginPage();
      },
    );
  }
}

class PassengerStartupGate extends StatefulWidget {
  const PassengerStartupGate({
    super.key,
    required this.passengerName,
    required this.passengerEmail,
  });

  final String passengerName;
  final String passengerEmail;

  @override
  State<PassengerStartupGate> createState() => _PassengerStartupGateState();
}

class _PassengerStartupGateState extends State<PassengerStartupGate> {
  late final Future<int?> _activeTripFuture;

  @override
  void initState() {
    super.initState();
    _activeTripFuture = _restoreActiveTripId();
  }

  Future<int?> _restoreActiveTripId() async {
    final restored = await TripLifecycleManager.restoreSnapshot();
    if (restored == null || restored.isTerminal) return null;
    return restored.tripId;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _activeTripFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
          );
        }

        final tripId = snapshot.data;
        if (tripId != null && tripId > 0) {
          return TripMatchingPage(tripId: tripId);
        }

        return PassengerDashboard(
          passengerName: widget.passengerName,
          passengerEmail: widget.passengerEmail,
        );
      },
    );
  }
}
