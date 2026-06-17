import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_initializer.dart';
import 'core/firebase/firebase_initializer.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/data/models/auth_response.dart' show User;
import 'pages/driver/driver_dashboard.dart';
import 'pages/passenger/passenger_dashboard.dart';
import 'screens/driver/driver_navigation_screen.dart';

// ── Passenger screens ──────────────────────────────────────────────────────
import 'screens/passenger/transport_selection_screen.dart';
import 'screens/passenger/bus_corridors_screen.dart';
import 'screens/passenger/bus_stops_screen.dart';
import 'screens/passenger/active_buses_screen.dart';
import 'screens/passenger/bus_booking_screen.dart';
import 'screens/passenger/bus_ticket_screen.dart';
import 'screens/passenger/private_car_request_screen.dart';
import 'screens/passenger/driver_selection_screen.dart';
import 'screens/passenger/motorcycle_request_screen.dart';
import 'screens/passenger/searching_driver_screen.dart';
import 'screens/passenger/trip_tracking_screen.dart';
import 'screens/passenger/live_driver_map_screen.dart';
import 'screens/passenger/my_trips_screen.dart';
import 'screens/passenger/trip_details_screen.dart';
import 'screens/passenger/rate_driver_screen.dart';
import 'screens/passenger/payments_screen.dart';
import 'screens/passenger/notifications_screen.dart';

// ── Services ───────────────────────────────────────────────────────────────
import 'services/app_theme_service.dart';
import 'services/driver_preferences_service.dart';
import 'services/passenger_preferences_service.dart';
import 'services/passenger_language_service.dart';
import 'services/driver_language_service.dart';
import 'services/fcm_service.dart';
import 'services/heartbeat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app-level services
  await AppThemeService.init();
  await DriverPreferencesService.init();
  await PassengerPreferencesService.init();
  await PassengerLanguageService.instance.init();
  await DriverLanguageService.instance.ensureInitialized();
  await FcmService.instance.initialize();

  // Initialize Firebase (RTDB only, no Firestore) and auth
  await AppInitializer.initialize();

  assert(() {
    // Ensure debug baseline overlays are off in dev mode.
    debugPaintBaselinesEnabled = false;
    return true;
  }());

  runApp(const ProviderScope(child: RideConnectApp()));
}

class RideConnectApp extends ConsumerStatefulWidget {
  const RideConnectApp({super.key});

  @override
  ConsumerState<RideConnectApp> createState() => _RideConnectAppState();
}

class _RideConnectAppState extends ConsumerState<RideConnectApp> {
  @override
  void initState() {
    super.initState();
    // Check auth status on startup
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
    });

    // Initialize Heartbeat Service
    HeartbeatService().initialize();

    // Listen to theme changes
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
    HeartbeatService().dispose();
    FirebaseInitializer.instance.dispose();
    super.dispose();
  }

  void _onThemeOrLanguageChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeService.themeModeNotifier.value;
    final authState = ref.watch(authProvider);

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
      home: _buildHome(authState),
      // ── Static named routes (no arguments required) ────────────────────
      routes: {
        '/transport': (_) => const TransportSelectionScreen(),
        '/bus/corridors': (_) => const BusCorridorsScreen(),
        '/trips': (_) => const MyTripsScreen(),
        '/payments': (_) => const PaymentsScreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
      // ── Dynamic routes (require arguments or path segments) ────────────
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Widget _buildHome(AuthState authState) {
    if (authState.isLoading) {
      return const LoadingScreen();
    }

    if (authState.isAuthenticated && authState.user != null) {
      // User is authenticated - show appropriate dashboard
      final user = authState.user!;

      if (user.isPassenger) {
        return PassengerDashboard(
          passengerName: user.name,
          passengerEmail: user.email ?? '',
        );
      } else {
        return DriverDashboard(
          driverName: user.name,
          driverEmail: user.email ?? '',
        );
      }
    }

    // Not authenticated - show login
    return const LoginPage();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Screen - shown while checking auth status
// ─────────────────────────────────────────────────────────────────────────────
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            const SizedBox(height: 20),
            Text(
              'Initializing...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic route generator
// Parses routes like /trips/42, /trip/map/5, /trip/rate/7, /driver/navigate/3
// Arguments can also carry an 'args' Map via RouteSettings.arguments.
// ─────────────────────────────────────────────────────────────────────────────
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  if (uri == null) return null;

  final segments = uri.pathSegments; // e.g. ['trips', '42']

  // Helper: extract int from path segment OR the args map
  int? extractId(int segIndex, [String argKey = 'tripId']) {
    Map<String, dynamic>? argsMap;
    if (settings.arguments is Map<String, dynamic>) {
      argsMap = settings.arguments as Map<String, dynamic>;
    }
    if (segIndex < segments.length) {
      final parsed = int.tryParse(segments[segIndex]);
      if (parsed != null) return parsed;
    }
    if (argsMap != null) {
      final v = argsMap[argKey];
      if (v is int) return v;
      if (v != null) return int.tryParse(v.toString());
    }
    return null;
  }

  Map<String, dynamic>? getArgs() {
    if (settings.arguments is Map<String, dynamic>) {
      return settings.arguments as Map<String, dynamic>;
    }
    return null;
  }

  // ── /bus/corridors/:id  (3 segments, last is numeric) ────────────────────
  if (segments.length == 3 &&
      segments[0] == 'bus' &&
      segments[1] == 'corridors' &&
      segments[2] != 'stops' &&
      segments[2] != 'buses') {
    final id = int.tryParse(segments[2]);
    if (id != null) return _slide(BusStopsScreen(corridorId: id), settings);
  }

  // ── /bus/corridors/:id/stops ─────────────────────────────────────────────
  if (segments.length == 4 &&
      segments[0] == 'bus' &&
      segments[1] == 'corridors' &&
      segments[3] == 'stops') {
    final id = int.tryParse(segments[2]);
    if (id != null) return _slide(BusStopsScreen(corridorId: id), settings);
  }

  // ── /bus/corridors/:id/buses ─────────────────────────────────────────────
  if (segments.length == 4 &&
      segments[0] == 'bus' &&
      segments[1] == 'corridors' &&
      segments[3] == 'buses') {
    final id = int.tryParse(segments[2]);
    if (id != null) {
      final args = getArgs();
      return _slide(
        ActiveBusesScreen(
          corridorId: id,
          boardingStopId: args?['boarding_stop_id'] as int?,
          destinationStopId: args?['destination_stop_id'] as int?,
        ),
        settings,
      );
    }
  }

  // ── /bus/book ────────────────────────────────────────────────────────────
  if (segments.length == 2 && segments[0] == 'bus' && segments[1] == 'book') {
    final args = getArgs();
    return _slide(
      BusBookingScreen(
        corridorId: args?['corridor_id'] as int? ?? args?['corridorId'] as int?,
        boardingStopId:
            args?['boarding_stop_id'] as int? ??
            args?['boardingStopId'] as int?,
        destinationStopId:
            args?['destination_stop_id'] as int? ??
            args?['destinationStopId'] as int?,
        busAssignmentId:
            args?['bus_assignment_id'] as int? ??
            args?['busAssignmentId'] as int?,
      ),
      settings,
    );
  }

  // ── /bus/ticket/:ticketId ────────────────────────────────────────────────
  if (segments.length == 3 && segments[0] == 'bus' && segments[1] == 'ticket') {
    return _slide(BusTicketScreen(ticketId: segments[2]), settings);
  }

  // ── /car/request ─────────────────────────────────────────────────────────
  if (segments.length == 2 &&
      segments[0] == 'car' &&
      segments[1] == 'request') {
    return _slide(const PrivateCarRequestScreen(), settings);
  }

  // ── /car/drivers  ────────────────────────────────────────────────────────
  // DriverSelectionScreen reads args itself via ModalRoute — no constructor params
  if (segments.length == 2 &&
      segments[0] == 'car' &&
      segments[1] == 'drivers') {
    return _slide(const DriverSelectionScreen(), settings);
  }

  // ── /moto/request ────────────────────────────────────────────────────────
  if (segments.length == 2 &&
      segments[0] == 'moto' &&
      segments[1] == 'request') {
    return _slide(const MotorcycleRequestScreen(), settings);
  }

  // /trip/searching/:id
  if (segments.length == 3 &&
      segments[0] == 'trip' &&
      segments[1] == 'searching') {
    final id = extractId(2);
    if (id != null) {
      return _slide(SearchingDriverScreen(tripId: id), settings);
    }
  }

  // /trips/:id
  if (segments.length == 2 && segments[0] == 'trips') {
    final id = extractId(1, 'tripId');
    if (id != null) {
      return _slide(TripDetailsScreen(tripId: id), settings);
    }
  }

  // /trip/track/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'track') {
    final id = extractId(2);
    if (id != null) {
      return _slide(TripTrackingScreen(tripId: id), settings);
    }
  }

  // /trip/map/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'map') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        LiveDriverMapScreen(
          tripId: id,
          isMotorVehicle: args?['isMotorVehicle'] as bool? ?? true,
        ),
        settings,
      );
    }
  }

  // /trip/rate/:id
  if (segments.length == 3 && segments[0] == 'trip' && segments[1] == 'rate') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        RateDriverScreen(
          tripId: id,
          isMotorVehicle: args?['isMotorVehicle'] as bool? ?? true,
        ),
        settings,
      );
    }
  }

  // /driver/navigate/:id
  if (segments.length == 3 &&
      segments[0] == 'driver' &&
      segments[1] == 'navigate') {
    final id = extractId(2);
    if (id != null) {
      final args = getArgs();
      return _slide(
        DriverNavigationScreen(
          tripId: id,
          passengerLat: (args?['passengerLat'] as num?)?.toDouble(),
          passengerLng: (args?['passengerLng'] as num?)?.toDouble(),
          dropoffLat: (args?['dropoffLat'] as num?)?.toDouble(),
          dropoffLng: (args?['dropoffLng'] as num?)?.toDouble(),
          passengerName: args?['passengerName']?.toString() ?? 'Passenger',
          passengerPhone: args?['passengerPhone']?.toString() ?? '',
          pickupAddress: args?['pickupAddress']?.toString() ?? 'Pickup',
          dropoffAddress: args?['dropoffAddress']?.toString() ?? 'Dropoff',
          estimatedFare: (args?['estimatedFare'] as num?)?.toDouble(),
        ),
        settings,
      );
    }
  }

  return null; // falls back to 404/unknown route
}

/// Slide-in page transition (right-to-left).
PageRouteBuilder<dynamic> _slide(Widget page, RouteSettings settings) {
  return PageRouteBuilder<dynamic>(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}
