import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../../models/location_model.dart';
import '../services/api_repository.dart';
import 'auth_provider.dart';

// ──────────────────────────────────────────────────────────────────────
// LOCATION SERVICE
// ──────────────────────────────────────────────────────────────────────

class LocationService {
  final Logger _logger;
  StreamSubscription? _positionStreamSubscription;

  LocationService({Logger? logger}) : _logger = logger ?? Logger();

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();

      final hasPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      _logger.d('Location permission: $permission');

      return hasPermission;
    } catch (e) {
      _logger.e('Error requesting location permission', error: e);
      return false;
    }
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      final hasPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      return hasPermission;
    } catch (e) {
      _logger.e('Error checking location permission', error: e);
      return false;
    }
  }

  /// Get current location
  Future<LocationModel?> getCurrentLocation() async {
    try {
      final hasPermission = await hasLocationPermission();

      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          position.timestamp.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      _logger.e('Error getting current location', error: e);
      return null;
    }
  }

  /// Get location updates stream
  Stream<LocationModel> getLocationUpdates({
    double distanceFilter = 10.0,
    Duration interval = const Duration(seconds: 5),
  }) async* {
    try {
      final hasPermission = await hasLocationPermission();

      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter.toInt(),
          timeLimit: interval,
        ),
      );

      await for (final position in positionStream) {
        yield LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          heading: position.heading,
          speed: position.speed,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            position.timestamp.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error in location updates stream', error: e);
      rethrow;
    }
  }

  /// Dispose location service
  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}

final locationServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return LocationService(logger: logger);
});

// ──────────────────────────────────────────────────────────────────────
// LOCATION STATE NOTIFIER
// ──────────────────────────────────────────────────────────────────────

class LocationNotifier extends StateNotifier<AsyncValue<LocationModel?>> {
  final LocationService _locationService;
  final Logger _logger;
  StreamSubscription? _streamSubscription;

  LocationNotifier({
    required LocationService locationService,
    required Logger logger,
  }) : _locationService = locationService,
       _logger = logger,
       super(const AsyncValue.data(null));

  /// Initialize location
  Future<void> initialize() async {
    try {
      state = const AsyncValue.loading();

      final hasPermission = await _locationService.hasLocationPermission();

      if (!hasPermission) {
        final permissionGranted =
            await _locationService.requestLocationPermission();
        if (!permissionGranted) {
          throw Exception('Location permission denied');
        }
      }

      final location = await _locationService.getCurrentLocation();
      state = AsyncValue.data(location);

      _logger.d(
        'Location initialized: ${location?.latitude}, ${location?.longitude}',
      );
    } catch (e, st) {
      _logger.e('Error initializing location', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Start location tracking
  void startTracking() {
    try {
      _streamSubscription?.cancel();

      _streamSubscription = _locationService
          .getLocationUpdates(
            distanceFilter: 10.0,
            interval: const Duration(seconds: 5),
          )
          .listen(
            (location) {
              state = AsyncValue.data(location);
              _logger.d(
                'Location updated: ${location.latitude}, ${location.longitude}',
              );
            },
            onError: (e, st) {
              _logger.e('Error in location stream', error: e, stackTrace: st);
              state = AsyncValue.error(e, st);
            },
          );

      _logger.d('Location tracking started');
    } catch (e, st) {
      _logger.e('Error starting location tracking', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _streamSubscription?.cancel();
    _logger.d('Location tracking stopped');
  }

  /// Update location manually
  void updateLocation(LocationModel location) {
    state = AsyncValue.data(location);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider.autoDispose<
  LocationNotifier,
  AsyncValue<LocationModel?>
>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  final logger = ref.watch(loggerProvider);

  final notifier = LocationNotifier(
    locationService: locationService,
    logger: logger,
  );

  // Initialize on creation
  notifier.initialize();

  return notifier;
});

// ──────────────────────────────────────────────────────────────────────
// DRIVER LOCATION TRACKING PROVIDER
// ──────────────────────────────────────────────────────────────────────

class DriverLocationTrackerNotifier extends StateNotifier<bool> {
  final ApiRepository _apiRepository;
  final Logger _logger;
  StreamSubscription? _trackingSubscription;

  DriverLocationTrackerNotifier({
    required ApiRepository apiRepository,
    required Logger logger,
  }) : _apiRepository = apiRepository,
       _logger = logger,
       super(false);

  /// Start tracking driver location
  void startTracking({
    required int tripId,
    required LocationService locationService,
  }) {
    try {
      state = true;

      _trackingSubscription = locationService
          .getLocationUpdates(
            distanceFilter: 5.0,
            interval: const Duration(seconds: 5),
          )
          .listen(
            (location) async {
              try {
                await _apiRepository.updateDriverLocation(
                  tripId,
                  location.latitude,
                  location.longitude,
                );
                _logger.d('Driver location updated to server');
              } catch (e) {
                _logger.e('Error updating driver location to server', error: e);
              }
            },
            onError: (e, st) {
              _logger.e(
                'Error in driver location tracking',
                error: e,
                stackTrace: st,
              );
              state = false;
            },
          );

      _logger.d('Driver location tracking started for trip $tripId');
    } catch (e, st) {
      _logger.e(
        'Error starting driver location tracking',
        error: e,
        stackTrace: st,
      );
      state = false;
    }
  }

  /// Stop tracking driver location
  void stopTracking() {
    _trackingSubscription?.cancel();
    state = false;
    _logger.d('Driver location tracking stopped');
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }
}

final driverLocationTrackerProvider =
    StateNotifierProvider.autoDispose<DriverLocationTrackerNotifier, bool>((
      ref,
    ) {
      final apiRepository = ref.watch(apiRepositoryProvider);
      final logger = ref.watch(loggerProvider);

      return DriverLocationTrackerNotifier(
        apiRepository: apiRepository,
        logger: logger,
      );
    });

// ──────────────────────────────────────────────────────────────────────
// LOCATION PERMISSION PROVIDER
// ──────────────────────────────────────────────────────────────────────

final locationPermissionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.hasLocationPermission();
});
