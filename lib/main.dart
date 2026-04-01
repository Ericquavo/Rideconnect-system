import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'auth/auth_api.dart';
import 'auth/auth_session.dart';
import 'pages/driver/driver_dashboard.dart';
import 'pages/login_page.dart';
import 'pages/passenger/passenger_dashboard.dart';
import 'services/app_theme_service.dart';
import 'services/passenger_language_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeService.init();
  await PassengerLanguageService.instance.init();
  assert(() {
    // Ensure debug baseline overlays are off in dev mode.
    debugPaintBaselinesEnabled = false;
    return true;
  }());
  runApp(const RideConnectApp());
}

class RideConnectApp extends StatelessWidget {
  const RideConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeModeNotifier,
      builder: (_, themeMode, __) {
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
      },
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
          return PassengerDashboard(
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
