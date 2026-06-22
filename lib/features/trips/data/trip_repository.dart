import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../models/matching/matching_session.dart';
import '../domain/matching_lifecycle_models.dart';
import '../domain/trip_models.dart';

class TripRepository {
  TripRepository(this._api);

  final ApiClient _api;

  Future<Trip> createPassengerTrip(TripRequest request) async {
    final response = await _api.post(
      '/v3/trips/private-car/request',
      data: request.toJson(),
    );
    return Trip.fromJson(response.data);
  }

  Future<MatchingLifecycleSnapshot> requestMatchedTrip(
    TripRequest request,
  ) async {
    return requestPrivateCarTrip(request);
  }

  Future<MatchingLifecycleSnapshot> requestPrivateCarTrip(
    TripRequest request,
  ) async {
    final body = <String, dynamic>{
      'pickup_location': request.pickup.label,
      'pickup_lat': request.pickup.lat,
      'pickup_lng': request.pickup.lng,
      'dropoff_location': request.destination.label,
      'dropoff_lat': request.destination.lat,
      'dropoff_lng': request.destination.lng,
      'car_type_preference': 'sedan',
      if (request.departureTime != null)
        'scheduled_time': request.departureTime!.toIso8601String(),
      'requested_seats': request.seatCount,
    };

    debugPrint('[TripRepository] Sending Private Car request to /v3/trips/private-car/request');
    final response = await _api.post(
      '/v3/trips/private-car/request',
      data: body,
    );
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  Future<MatchingLifecycleSnapshot> requestMotorVehicleTrip(
    TripRequest request,
  ) async {
    final body = <String, dynamic>{
      'pickup_location': request.pickup.label,
      'pickup_lat': request.pickup.lat,
      'pickup_lng': request.pickup.lng,
      'dropoff_location': request.destination.label,
      'dropoff_lat': request.destination.lat,
      'dropoff_lng': request.destination.lng,
      'ride_mode': request.scheduleMode == 'scheduled' ? 'scheduled' : 'instant',
      'payment_method': request.paymentMethod,
      if (request.driverId != null) 'driver_id': request.driverId,
    };

    debugPrint('[TripRepository] Sending request to /v3/trips/motor-vehicle/request');
    final response = await _api.post(
      '/v3/trips/motor-vehicle/request',
      data: body,
    );
    final snapshot = MatchingLifecycleSnapshot.fromJson(response.data);
    final trip = snapshot.trip;
    if (trip == null) return snapshot;
    return snapshot.copyWith(
      trip: Trip(
        id: trip.id,
        status: trip.status,
        pickup: request.pickup,
        destination: request.destination,
        driver: trip.driver,
        vehicle: trip.vehicle,
        fare: trip.fare,
        etaText: trip.etaText,
        paymentStatus: trip.paymentStatus,
        createdAt: trip.createdAt,
      ),
    );
  }

  Future<MatchingLifecycleSnapshot> selectDriver({
    required int tripId,
    required int driverId,
  }) async {
    debugPrint('[TripRepository] Selecting driver $driverId for trip $tripId');
    final response = await _api.post(
      '/v3/trips/$tripId/select-driver',
      data: {'driver_id': driverId},
    );
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  Future<MatchingLifecycleSnapshot> notifyDriver({
    required int tripId,
    required int driverId,
  }) async {
    debugPrint('[TripRepository] Notifying driver $driverId for trip $tripId');
    final response = await _api.post(
      '/v3/trips/$tripId/notify-driver',
    );
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  Future<MatchingSession> matchPassengerDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    List<int> excludedDriverIds = const [],
  }) async {
    debugPrint('[TripRepository] Fetching online drivers for transport_type: $transportType');
    final response = await _api.get('/v3/drivers/online');
    return MatchingSession.fromJson(response.data);
  }

  Future<List<Trip>> passengerTrips() async {
    final response = await _api.get('/passenger/trips');
    final data = response.data;
    if (data is Map && data['trips'] != null) {
      final trips = data['trips'];
      if (trips is List) {
        return trips.map((t) => Trip.fromJson(t)).toList();
      }
    }
    return [];
  }

  Future<Trip?> currentPassengerTrip() async {
    final response = await _api.get('/mobile/trips/current');
    final map = response.data;
    if (map.isEmpty || map['trip'] == null && map['id'] == null) return null;
    return Trip.fromJson(
      map['trip'] is Map<String, dynamic> ? map['trip'] : map,
    );
  }

  Future<MatchingLifecycleSnapshot?> currentPassengerMatching() async {
    final response = await _api.get('/mobile/trips/current');
    final map = response.data;
    if (map.isEmpty || map['trip'] == null && map['id'] == null) return null;
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  Future<Trip> passengerTrip(int id) async {
    final response = await _api.get('/passenger/trips/$id');
    return Trip.fromJson(response.data);
  }

  Future<void> cancelPassengerTrip(int id, {String? reason}) async {
    await _api.post(
      '/v3/trips/$id/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> acknowledgeTripStatus(int tripId, String ackType) async {
    try {
      await _api.post(
        '/trips/$tripId/acknowledge',
        data: {
          'acknowledgement_type': ackType,
          'source': 'flutter',
        },
      );
    } catch (e) {
      debugPrint('[TripRepository] Error acknowledging trip status: $e');
    }
  }

  Future<TripTracking> trackTrip(int id) async {
    debugPrint('[TripRepository] trackTrip called for tripId: $id');
    try {
      // 1. Fetch base trip details for pickup, dropoff, fare, etc.
      Trip? baseTrip;
      try {
        final baseResponse = await _api.get('/passenger/trips/$id');
        baseTrip = Trip.fromJson(baseResponse.data);
      } catch (e) {
        debugPrint('[TripRepository] Error fetching base trip details: $e');
      }

      // 2. Fetch V3 Active Trip & Tracking Status
      final response = await _api.get('/v3/trips/$id/status');
      final data = response.data['data'] ?? response.data;
      
      final statusVal = TripStatusX.parse(data['status']);
      
      // Parse driver info
      TripDriver? driver;
      final driverMap = data['driver'];
      if (driverMap is Map<String, dynamic>) {
        driver = TripDriver.fromJson(driverMap);
      }
      
      // Parse vehicle info
      TripVehicle? vehicle;
      if (driverMap is Map<String, dynamic>) {
        vehicle = TripVehicle.fromJson(driverMap);
      }

      final trip = Trip(
        id: id,
        status: statusVal,
        pickup: baseTrip?.pickup ?? const TripLocation(label: 'Pickup'),
        destination: baseTrip?.destination ?? const TripLocation(label: 'Destination'),
        driver: driver ?? baseTrip?.driver,
        vehicle: vehicle ?? baseTrip?.vehicle,
        fare: baseTrip?.fare ?? 0,
        etaText: data['eta']?.toString() ?? baseTrip?.etaText ?? '',
      );

      // 3. Parse driver location from status as initial fallback
      LatLng? driverLocation;
      double speed = 0.0;
      double heading = 0.0;
      String updatedAt = '';

      final driverLocMap = data['driver_location'];
      if (driverLocMap is Map<String, dynamic>) {
        final lat = _readDouble(driverLocMap, ['lat', 'latitude']);
        final lng = _readDouble(driverLocMap, ['lng', 'longitude']);
        if (lat != null && lng != null) {
          driverLocation = LatLng(lat, lng);
        }
        speed = _readDouble(driverLocMap, ['speed', 'velocity']) ?? 0.0;
        heading = _readDouble(driverLocMap, ['heading', 'bearing']) ?? 0.0;
        updatedAt = _readString(driverLocMap, ['updated_at', 'timestamp']) ?? '';
      }

      // 4. Fetch the driver's exact coordinates in real-time from GET /v3/location/live/{driverUserId}
      final driverUserId = driver?.id ?? baseTrip?.driver?.id;
      if (driverUserId != null && driverUserId > 0) {
        try {
          debugPrint('[TripRepository] Fetching live location for driver user ID: $driverUserId');
          final liveRes = await _api.get('/v3/location/live/$driverUserId');
          final liveData = liveRes.data['data'] ?? liveRes.data;
          if (liveData is Map<String, dynamic>) {
            final lat = _readDouble(liveData, ['latitude', 'lat']);
            final lng = _readDouble(liveData, ['longitude', 'lng']);
            if (lat != null && lng != null) {
              debugPrint('[TripRepository] Driver live location parsed from /v3/location/live: ($lat, $lng)');
              driverLocation = LatLng(lat, lng);
              speed = _readDouble(liveData, ['speed', 'velocity']) ?? speed;
              heading = _readDouble(liveData, ['heading', 'bearing']) ?? heading;
              updatedAt = _readString(liveData, ['updated_at', 'timestamp']) ?? updatedAt;
            }
          }
        } catch (e) {
          debugPrint('[TripRepository] Error fetching live driver location from /v3/location/live/$driverUserId: $e');
        }
      }

      // 5. Fetch actual navigation routes from backend compute-route API
      List<LatLng> driverToPickupRoutePoints = const <LatLng>[];
      if (driverLocation != null && trip.pickup.latLng != null) {
        try {
          final routeRes = await _api.post(
            '/route/compute',
            data: {
              'pickup_lat': driverLocation.latitude,
              'pickup_lng': driverLocation.longitude,
              'dropoff_lat': trip.pickup.latLng!.latitude,
              'dropoff_lng': trip.pickup.latLng!.longitude,
            },
          );
          final routeData = routeRes.data;
          final polylineStr = routeData['polyline'] as String?;
          if (polylineStr != null && polylineStr.isNotEmpty) {
            final polylinePoints = PolylinePoints().decodePolyline(polylineStr);
            driverToPickupRoutePoints = polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
          }
        } catch (e) {
          debugPrint('[TripRepository] Error fetching driver to pickup route: $e');
        }
        if (driverToPickupRoutePoints.isEmpty) {
          driverToPickupRoutePoints = [driverLocation, trip.pickup.latLng!];
        }
      }

      List<LatLng> pickupToDropoffRoutePoints = const <LatLng>[];
      if (trip.destination.latLng != null) {
        final originLat = (statusVal == TripStatus.inProgress && driverLocation != null)
            ? driverLocation.latitude
            : (trip.pickup.latLng?.latitude ?? 0.0);
        final originLng = (statusVal == TripStatus.inProgress && driverLocation != null)
            ? driverLocation.longitude
            : (trip.pickup.latLng?.longitude ?? 0.0);

        if (originLat != 0.0 && originLng != 0.0) {
          try {
            final routeRes = await _api.post(
              '/route/compute',
              data: {
                'pickup_lat': originLat,
                'pickup_lng': originLng,
                'dropoff_lat': trip.destination.latLng!.latitude,
                'dropoff_lng': trip.destination.latLng!.longitude,
              },
            );
            final routeData = routeRes.data;
            final polylineStr = routeData['polyline'] as String?;
            if (polylineStr != null && polylineStr.isNotEmpty) {
              final polylinePoints = PolylinePoints().decodePolyline(polylineStr);
              pickupToDropoffRoutePoints = polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
            }
          } catch (e) {
            debugPrint('[TripRepository] Error fetching pickup/driver to dropoff route: $e');
          }
        }
        if (pickupToDropoffRoutePoints.isEmpty && trip.pickup.latLng != null) {
          pickupToDropoffRoutePoints = [
            LatLng(originLat, originLng),
            trip.destination.latLng!,
          ];
        }
      }

      return TripTracking(
        trip: trip,
        driverLocation: driverLocation,
        route: pickupToDropoffRoutePoints,
        driverToPickupRoute: driverToPickupRoutePoints,
        etaText: data['eta']?.toString() ?? '',
        distanceText: data['distance_remaining']?.toString() ?? '',
        speed: speed,
        heading: heading,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('[TripRepository] Error in trackTrip for tripId $id: $e');
      rethrow;
    }
  }

  Future<List<Trip>> passengerTripsV3() async {
    final response = await _api.get('/v3/trips');
    final data = response.data['data'] ?? response.data;
    if (data is List) {
      return data.map((t) => Trip.fromJson(Map<String, dynamic>.from(t as Map))).toList();
    }
    return [];
  }

  Future<MatchingLifecycleSnapshot> getMatchingStatusV3(int tripId) async {
    final response = await _api.get('/v3/trips/$tripId/matching-status');
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  Future<MatchingLifecycleSnapshot> lifecycleSnapshotForTrip(
    int id, {
    MatchingLifecycleSnapshot? previous,
  }) async {
    final snapshots = <MatchingLifecycleSnapshot>[];
    ApiException? lastError;

    for (final loader in <Future<MatchingLifecycleSnapshot> Function()>[
      () => _endpointSnapshot('/v3/trips/$id/status'),
    ]) {
      try {
        final snapshot = await loader();
        snapshots.add(snapshot);
        if (_hasActionableProgress(snapshot)) break;
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode == 401) continue;
      }
    }

    if (snapshots.isEmpty) {
      if (previous != null) return previous;
      throw lastError ?? ApiException(message: 'Unable to load trip status.');
    }

    return _mergeSnapshots(snapshots, previous: previous);
  }

  Future<MatchingLifecycleSnapshot> _endpointSnapshot(String path) async {
    final response = await _api.get(path);
    return MatchingLifecycleSnapshot.fromJson(response.data);
  }

  bool _hasActionableProgress(MatchingLifecycleSnapshot snapshot) {
    return snapshot.status != MatchingLifecycleStatus.tripRequested &&
        snapshot.status != MatchingLifecycleStatus.searchingCandidates &&
        snapshot.status != MatchingLifecycleStatus.mlMatching;
  }

  MatchingLifecycleSnapshot _mergeSnapshots(
    List<MatchingLifecycleSnapshot> snapshots, {
    MatchingLifecycleSnapshot? previous,
  }) {
    final ordered = [if (previous != null) previous, ...snapshots];
    var best = ordered.first;
    for (final snapshot in ordered.skip(1)) {
      best = _newerSnapshot(best, snapshot);
    }

    final trip = snapshots.reversed
        .map((snapshot) => snapshot.trip)
        .whereType<Trip>()
        .cast<Trip?>()
        .firstWhere((trip) => trip != null, orElse: () => previous?.trip);
    return best.copyWith(
      trip: trip,
      selectedDriver: best.selectedDriver ?? previous?.selectedDriver,
      candidates:
          best.candidates.isNotEmpty ? best.candidates : previous?.candidates,
      attempts: best.attempts.isNotEmpty ? best.attempts : previous?.attempts,
      message: best.message.isNotEmpty ? best.message : previous?.message,
    );
  }

  MatchingLifecycleSnapshot _newerSnapshot(
    MatchingLifecycleSnapshot current,
    MatchingLifecycleSnapshot candidate,
  ) {
    final currentRank = MatchingLifecycleStatusX.progressRank(current.status);
    final candidateRank = MatchingLifecycleStatusX.progressRank(
      candidate.status,
    );
    if (candidateRank >= currentRank) return candidate;
    return current;
  }

  Future<MatchingLifecycleSnapshot> matchingSnapshotForTrip(int id) async {
    return lifecycleSnapshotForTrip(id);
  }

  Future<void> createPayment({
    required int tripId,
    required double amount,
    required String method,
  }) async {
    await _api.post(
      '/v3/trips/$tripId/pay',
      data: {
        'trip_id': tripId,
        'payment_method': method,
        'amount': amount,
      },
    );
  }

  Future<void> storePublicTransportFeedback({
    required int tripId,
    required int rating,
    String? comment,
  }) async {
    await _api.post(
      '/v3/trips/$tripId/rate',
      data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    // FCM/Push notification services are removed under V3
  }

  Future<List<Trip>> incomingDriverTrips() async {
    final response = await _api.get('/v3/driver/trips');
    final data = response.data;
    if (data is Map) {
      final trips = data['trips'] ?? data['history'] ?? data['data'];
      if (trips is List) {
        return trips
            .map((t) => Trip.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList();
      }
    }
    if (data is List) {
      return data
          .map((t) => Trip.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
    }
    return [];
  }

  Future<Trip> acceptDriverTrip(int id) async {
    final response = await _api.post('/v3/trips/$id/accept');
    return Trip.fromJson(response.data);
  }

  Future<void> rejectDriverTrip(int id) async {
    await _api.post('/v3/trips/$id/reject');
  }

  Future<Trip> startDriverTrip(int id) async {
    final response = await _api.put('/v3/trips/$id/start');
    return Trip.fromJson(response.data);
  }

  Future<Trip> startTripV3(int id) async {
    final response = await _api.post('/v3/trips/$id/start');
    return Trip.fromJson(response.data);
  }

  Future<Trip> completeDriverTrip(int id) async {
    final response = await _api.put('/v3/trips/$id/complete');
    return Trip.fromJson(response.data);
  }

  Future<void> markDriverArrivedV3(int id) async {
    try {
      await _api.post('/v3/trips/$id/arrived');
    } catch (_) {
      await _api.put('/v3/trips/$id/arrived');
    }
  }

  Future<void> updateDriverStatus(bool isOnline) async {
    await _api.post('/v3/mobile/drivers/status', data: {'is_online': isOnline});
  }

  Future<void> uploadDriverLocation({
    required LatLng position,
    int? tripId,
    double? heading,
    double? speed,
  }) async {
    final payload = {
      'lat': position.latitude,
      'lng': position.longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    };
    await _api.post('/v3/driver/location', data: payload);
  }

  Future<List<Trip>> driverTripHistory() async {
    final response = await _api.get('/v3/driver/trips');
    final data = response.data;
    if (data is Map) {
      final trips = data['trips'] ?? data['history'] ?? data['data'];
      if (trips is List) {
        return trips
            .map((t) => Trip.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> driverEarnings() async {
    final response = await _api.get('/v3/driver/earnings');
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Future<List<LatLng>> computeRoute(LatLng origin, LatLng dest) async {
    try {
      final routeRes = await _api.post(
        '/route/compute',
        data: {
          'pickup_lat': origin.latitude,
          'pickup_lng': origin.longitude,
          'dropoff_lat': dest.latitude,
          'dropoff_lng': dest.longitude,
        },
      );
      final routeData = routeRes.data;
      final polylineStr = routeData['polyline'] as String?;
      if (polylineStr != null && polylineStr.isNotEmpty) {
        final polylinePoints = PolylinePoints().decodePolyline(polylineStr);
        return polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
      }
    } catch (e) {
      debugPrint('[TripRepository] Error computing route: $e');
    }
    return [origin, dest];
  }

  static double? _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
