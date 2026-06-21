import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    final response = await _api.get('/v1/mobile/trips/current');
    final map = response.data;
    if (map.isEmpty || map['trip'] == null && map['id'] == null) return null;
    return Trip.fromJson(
      map['trip'] is Map<String, dynamic> ? map['trip'] : map,
    );
  }

  Future<MatchingLifecycleSnapshot?> currentPassengerMatching() async {
    final response = await _api.get('/v1/mobile/trips/current');
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
    final response = await _api.get('/v1/mobile/trips/$id/track');
    return TripTracking.fromJson(response.data);
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
      data: {'amount': amount, 'payment_method': method},
    );
  }

  Future<void> storePublicTransportFeedback({
    required int tripId,
    required int rating,
    String? comments,
  }) async {
    await _api.post(
      '/v3/trips/$tripId/rate',
      data: {
        'rating': rating,
        if (comments != null && comments.trim().isNotEmpty)
          'comments': comments.trim(),
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
    final response = await _api.get('/v3/driver/trips/incoming');
    final data = response.data;
    if (data is Map && data['trips'] != null) {
      final trips = data['trips'];
      if (trips is List) {
        return trips.map((t) => Trip.fromJson(t)).toList();
      }
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

  Future<Trip> completeDriverTrip(int id) async {
    final response = await _api.put('/v3/trips/$id/complete');
    return Trip.fromJson(response.data);
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
    final response = await _api.get('/driver/trips');
    final data = response.data;
    if (data is Map && data['trips'] != null) {
      final trips = data['trips'];
      if (trips is List) {
        return trips.map((t) => Trip.fromJson(t)).toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> driverEarnings() async {
    final response = await _api.get('/driver/earnings');
    return response.data;
  }
}
