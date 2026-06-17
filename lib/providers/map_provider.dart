import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../../models/trip_model.dart' as trip_model;
import '../services/api_repository.dart';
import 'auth_provider.dart';

// ──────────────────────────────────────────────────────────────────────
// MAP SERVICE
// ──────────────────────────────────────────────────────────────────────

class MapService {
  final PolylinePoints _polylinePoints;
  final Logger _logger;

  MapService({PolylinePoints? polylinePoints, Logger? logger})
    : _polylinePoints = polylinePoints ?? PolylinePoints(),
      _logger = logger ?? Logger();

  /// Decode polyline to list of points
  Future<List<LatLng>> decodePolyline(String polyline) async {
    try {
      final result = _polylinePoints.decodePolyline(polyline);

      final points =
          result.map((p) => LatLng(p.latitude, p.longitude)).toList();

      _logger.d('Decoded polyline with ${points.length} points');
      return points;
    } catch (e) {
      _logger.e('Error decoding polyline', error: e);
      return [];
    }
  }

  /// Create markers for pickup, dropoff, and driver
  Set<Marker> createMarkers({
    required LatLng pickupLocation,
    required LatLng dropoffLocation,
    LatLng? driverLocation,
    String pickupLabel = 'Pickup',
    String dropoffLabel = 'Dropoff',
    String driverLabel = 'Driver',
    BitmapDescriptor? pickupIcon,
    BitmapDescriptor? dropoffIcon,
    BitmapDescriptor? driverIcon,
  }) {
    final markers = <Marker>{};

    // Pickup marker
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLocation,
        infoWindow: InfoWindow(title: pickupLabel),
        icon:
            pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // Dropoff marker
    markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: dropoffLocation,
        infoWindow: InfoWindow(title: dropoffLabel),
        icon:
            dropoffIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Driver marker
    if (driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation,
          infoWindow: InfoWindow(title: driverLabel),
          icon:
              driverIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: 0,
        ),
      );
    }

    return markers;
  }

  /// Create polylines for routes
  Set<Polyline> createPolylines({
    required List<LatLng> routePoints,
    String polylineId = 'route',
    Color color = Colors.blue,
    double width = 5,
  }) {
    if (routePoints.isEmpty) {
      return {};
    }

    return {
      Polyline(
        polylineId: PolylineId(polylineId),
        points: routePoints,
        color: color,
        width: width.toInt(),
        geodesic: true,
      ),
    };
  }

  /// Calculate camera bounds for multiple points
  CameraUpdate calculateCameraBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return CameraUpdate.newLatLngZoom(const LatLng(0, 0), 15);
    }

    if (points.length == 1) {
      return CameraUpdate.newLatLngZoom(points.first, 15);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    return CameraUpdate.newLatLngBounds(bounds, 50);
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;
}

final mapServiceProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return MapService(logger: logger);
});

// ──────────────────────────────────────────────────────────────────────
// MAP STATE NOTIFIER
// ──────────────────────────────────────────────────────────────────────

class MapStateNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final ApiRepository _apiRepository;
  final MapService _mapService;
  final Logger _logger;

  MapStateNotifier({
    required ApiRepository apiRepository,
    required MapService mapService,
    required Logger logger,
  }) : _apiRepository = apiRepository,
       _mapService = mapService,
       _logger = logger,
       super(const AsyncValue.data({}));

  /// Load route from API
  Future<void> loadRoute({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      state = const AsyncValue.loading();

      final route = await _apiRepository.getRoute(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );

      final polylinePoints = await _mapService.decodePolyline(route.polyline);

      state = AsyncValue.data({
        'route': route,
        'polylinePoints': polylinePoints,
        'markers': _mapService.createMarkers(
          pickupLocation: LatLng(pickupLat, pickupLng),
          dropoffLocation: LatLng(dropoffLat, dropoffLng),
        ),
        'polylines': _mapService.createPolylines(routePoints: polylinePoints),
        'cameraBounds': _mapService.calculateCameraBounds(polylinePoints),
      });

      _logger.d('Route loaded successfully');
    } catch (e, st) {
      _logger.e('Error loading route', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Update driver location on map
  void updateDriverLocation(LatLng driverLocation) {
    state.whenData((mapData) {
      final markers = mapData['markers'] as Set<Marker>;
      final newMarkers = <Marker>{};

      for (final marker in markers) {
        if (marker.markerId.value == 'driver') {
          newMarkers.add(marker.copyWith(positionParam: driverLocation));
        } else {
          newMarkers.add(marker);
        }
      }

      state = AsyncValue.data({
        ...mapData,
        'markers': newMarkers,
        'driverLocation': driverLocation,
      });
    });
  }

  /// Clear map
  void clearMap() {
    state = const AsyncValue.data({});
  }
}

final mapStateProvider = StateNotifierProvider.autoDispose<
  MapStateNotifier,
  AsyncValue<Map<String, dynamic>>
>((ref) {
  final apiRepository = ref.watch(apiRepositoryProvider);
  final mapService = ref.watch(mapServiceProvider);
  final logger = ref.watch(loggerProvider);

  return MapStateNotifier(
    apiRepository: apiRepository,
    mapService: mapService,
    logger: logger,
  );
});

// ──────────────────────────────────────────────────────────────────────
// ROUTE PROVIDER
// ──────────────────────────────────────────────────────────────────────

final routeProvider = FutureProvider.autoDispose
    .family<trip_model.RouteModel, (double, double, double, double)>((
      ref,
      args,
    ) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      final (pickupLat, pickupLng, dropoffLat, dropoffLng) = args;

      return await apiRepository.getRoute(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
    });

// ──────────────────────────────────────────────────────────────────────
// POLYLINE DECODER PROVIDER
// ──────────────────────────────────────────────────────────────────────

final polylineDecoderProvider = FutureProvider.autoDispose
    .family<List<LatLng>, String>((ref, polyline) async {
      final mapService = ref.watch(mapServiceProvider);
      return await mapService.decodePolyline(polyline);
    });
