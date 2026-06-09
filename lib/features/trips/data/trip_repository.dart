import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../models/matching/matching_session.dart';
import '../domain/matching_lifecycle_models.dart';
import '../domain/trip_models.dart';

class TripRepository {
  TripRepository(this._api);

  final ApiClient _api;

  Future<Trip> createPassengerTrip(TripRequest request) async {
    final response = await _api.post(
      '/mobile/trips/request',
      body: request.toJson(),
    );
    return Trip.fromJson(response.dataMap);
  }

  Future<MatchingLifecycleSnapshot> requestMatchedTrip(
    TripRequest request,
  ) async {
    final body = request.toJson();
    debugPrint('[TripRepository] Sending request to /mobile/trips/request');
    debugPrint('[TripRepository] Request body: ${jsonEncode(body)}');
    debugPrint(
      '[TripRepository] Pickup fields: ${body.keys.where((k) => k.contains("pickup"))}',
    );
    debugPrint(
      '[TripRepository] Dropoff fields: ${body.keys.where((k) => k.contains("dropoff"))}',
    );

    try {
      final response = await _api.post('/mobile/trips/request', body: body);
      debugPrint('[TripRepository] Response status: ${response.statusCode}');
      debugPrint(
        '[TripRepository] Response envelope: ${jsonEncode(response.envelope)}',
      );

      // Check if the response indicates an error
      if (response.envelope['success'] == false) {
        debugPrint(
          '[TripRepository] API returned error: ${response.envelope['message']}',
        );
        debugPrint(
          '[TripRepository] Error code: ${response.envelope['error_code']}',
        );
      }

      final snapshot = MatchingLifecycleSnapshot.fromJson(response.envelope);
      if (snapshot.trip != null ||
          snapshot.candidates.isNotEmpty ||
          snapshot.selectedDriver != null) {
        return snapshot;
      }
      return MatchingLifecycleSnapshot.fromTrip(
        Trip.fromJson(response.dataMap),
      );
    } catch (e, stackTrace) {
      debugPrint('[TripRepository] Exception occurred: $e');
      debugPrint('[TripRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<MatchingLifecycleSnapshot> requestMotorVehicleTrip(
    TripRequest request,
  ) async {
    final body = <String, dynamic>{
      'pickup_location': request.pickup.label,
      'dropoff_location': request.destination.label,
      if (request.pickup.lat != null) 'pickup_lat': request.pickup.lat,
      if (request.pickup.lng != null) 'pickup_lng': request.pickup.lng,
      if (request.destination.lat != null)
        'dropoff_lat': request.destination.lat,
      if (request.destination.lng != null)
        'dropoff_lng': request.destination.lng,
      'transport_type': 'MOTORCYCLE',
      'seats': 1,
      if (request.paymentMethod.trim().isNotEmpty)
        'payment_method': request.paymentMethod,
      if (request.notes != null && request.notes!.trim().isNotEmpty)
        'notes': request.notes!.trim(),
      if (request.departureTime != null)
        'scheduled_at': request.departureTime!.toIso8601String(),
    };

    debugPrint(
      '[TripRepository] Sending request to /passenger/motor-vehicle/trip-requests',
    );
    debugPrint('[TripRepository] Moto request body: ${jsonEncode(body)}');

    final response = await _api.post(
      '/passenger/motor-vehicle/trip-requests',
      body: body,
    );
    debugPrint(
      '[TripRepository] Moto response envelope: ${jsonEncode(response.envelope)}',
    );
    final snapshot = MatchingLifecycleSnapshot.fromJson(response.envelope);
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

  Future<MatchingSession> matchPassengerDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    List<int> excludedDriverIds = const [],
  }) async {
    debugPrint(
      '[TripRepository] Matching drivers for transport_type: $transportType',
    );
    debugPrint('[TripRepository] Pickup: ($pickupLat, $pickupLng)');
    debugPrint('[TripRepository] Dropoff: ($dropoffLat, $dropoffLng)');

    final response = await _api.get(
      '/passenger/drivers/match',
      query: {
        'transport_type': transportType,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        if (excludedDriverIds.isNotEmpty)
          'excluded_driver_ids': excludedDriverIds.join(','),
      },
    );

    debugPrint(
      '[TripRepository] Match response status: ${response.statusCode}',
    );
    debugPrint('[TripRepository] Match response: ${response.envelope}');

    final session = MatchingSession.fromJson(response.envelope);
    debugPrint('[TripRepository] Found ${session.drivers.length} drivers');
    return session;
  }

  Future<List<Trip>> passengerTrips() async {
    final response = await _api.get('/passenger/trips');
    return response
        .list(['trips', 'items', 'history'])
        .map(Trip.fromJson)
        .toList();
  }

  Future<Trip?> currentPassengerTrip() async {
    final response = await _api.get('/mobile/trips/current');
    final map = response.dataMap;
    if (map.isEmpty || map['trip'] == null && map['id'] == null) return null;
    return Trip.fromJson(
      map['trip'] is Map<String, dynamic> ? map['trip'] : map,
    );
  }

  Future<MatchingLifecycleSnapshot?> currentPassengerMatching() async {
    final response = await _api.get('/mobile/trips/current');
    final map = response.dataMap;
    if (map.isEmpty || map['trip'] == null && map['id'] == null) return null;
    return MatchingLifecycleSnapshot.fromJson(response.envelope);
  }

  Future<Trip> passengerTrip(int id) async {
    final response = await _api.get('/passenger/trips/$id');
    return Trip.fromJson(response.dataMap);
  }

  Future<void> cancelPassengerTrip(int id, {String? reason}) async {
    await _api.put(
      '/mobile/trips/$id/cancel',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<TripTracking> trackTrip(int id) async {
    final response = await _api.get('/mobile/trips/$id/track');
    return TripTracking.fromJson(response.dataMap);
  }

  Future<MatchingLifecycleSnapshot> lifecycleSnapshotForTrip(
    int id, {
    MatchingLifecycleSnapshot? previous,
  }) async {
    final snapshots = <MatchingLifecycleSnapshot>[];
    ApiException? lastError;

    for (final loader in <Future<MatchingLifecycleSnapshot> Function()>[
      () => _trackingSnapshotForTrip(id),
      () => _endpointSnapshot('/passenger/trips/$id/status'),
      () => _endpointSnapshot('/passenger/trips/$id/matching-session'),
      () => _endpointSnapshot('/passenger/motor-vehicle/trip-requests/$id'),
      () => _endpointSnapshot('/passenger/trips/$id'),
      () => _endpointSnapshot('/trip-requests/$id'),
    ]) {
      try {
        final snapshot = await loader();
        snapshots.add(snapshot);
        if (_hasActionableProgress(snapshot)) break;
      } on ApiException catch (e) {
        lastError = e;
        if (e.isUnauthorized) continue;
      }
    }

    if (snapshots.isEmpty) {
      if (previous != null) return previous;
      throw lastError ?? ApiException('Unable to load trip status.', 0, {});
    }

    var merged = _mergeSnapshots(snapshots, previous: previous);
    final notificationSnapshot = await _notificationSnapshotForTrip(id);
    if (notificationSnapshot != null) {
      merged = _mergeSnapshots([
        merged,
        notificationSnapshot,
      ], previous: previous);
    }
    return merged;
  }

  Future<MatchingLifecycleSnapshot> _trackingSnapshotForTrip(int id) async {
    final response = await _api.get('/mobile/trips/$id/track');
    return MatchingLifecycleSnapshot.fromTrackingEnvelope(response.envelope);
  }

  Future<MatchingLifecycleSnapshot> _endpointSnapshot(String path) async {
    final response = await _api.get(path);
    return MatchingLifecycleSnapshot.fromJson(response.envelope);
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

  Future<MatchingLifecycleSnapshot?> _notificationSnapshotForTrip(
    int id,
  ) async {
    try {
      final response = await _api.get('/notifications');
      final notifications = response.list(['notifications', 'items', 'data']);
      for (final notification in notifications) {
        if (!_notificationBelongsToTrip(notification, id)) continue;
        final status = _notificationStatus(notification);
        if (status == null) continue;
        return MatchingLifecycleSnapshot.fromJson({
          'trip_id': id,
          'status': status,
          'message': _notificationMessage(notification),
          if (notification['driver'] is Map<String, dynamic>)
            'driver': notification['driver'],
        });
      }
    } on ApiException catch (_) {
      return null;
    }
    return null;
  }

  bool _notificationBelongsToTrip(Map<String, dynamic> notification, int id) {
    final nested = notification['data'];
    final data = nested is Map<String, dynamic> ? nested : notification;
    final value = data['trip_id'] ?? data['tripId'] ?? data['request_id'];
    if (value is int) return value == id;
    if (value is num) return value.toInt() == id;
    return int.tryParse(value?.toString() ?? '') == id;
  }

  String? _notificationStatus(Map<String, dynamic> notification) {
    final nested = notification['data'];
    final data = nested is Map<String, dynamic> ? nested : notification;
    final raw =
        data['status'] ??
        data['trip_status'] ??
        data['event'] ??
        data['type'] ??
        notification['type'];
    if (raw == null) return null;
    final text = raw.toString().toUpperCase();
    if (text.contains('DRIVER_ASSIGNED')) return 'DRIVER_ASSIGNED';
    if (text.contains('DRIVER_ACCEPTED')) return 'PASSENGER_WAITING';
    if (text.contains('DRIVER_ARRIVED')) return 'DRIVER_ARRIVED';
    if (text.contains('TRIP_STARTED')) return 'IN_PROGRESS';
    if (text.contains('TRIP_COMPLETED')) return 'COMPLETED';
    if (text.contains('NO_DRIVER')) return 'NO_DRIVERS_AVAILABLE';
    return text;
  }

  String _notificationMessage(Map<String, dynamic> notification) {
    final nested = notification['data'];
    final data = nested is Map<String, dynamic> ? nested : notification;
    return (data['message'] ??
            data['body'] ??
            notification['message'] ??
            notification['body'] ??
            '')
        .toString();
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
      '/passenger/payments',
      body: {'trip_id': tripId, 'amount': amount, 'payment_method': method},
    );
  }

  Future<void> storePublicTransportFeedback({
    required int tripId,
    required int rating,
    String? comments,
  }) async {
    await _api.post(
      '/passenger/trips/$tripId/feedback',
      body: {
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
    await _api.post(
      '/devices/push-token',
      body: {
        'device_token': token,
        'platform': platform,
        'device_id': deviceId,
      },
    );
  }

  Future<List<Trip>> incomingDriverTrips() async {
    final response = await _api.get('/mobile/drivers/trips');
    return response
        .list(['trips', 'requests', 'items'])
        .map(Trip.fromJson)
        .toList();
  }

  Future<Trip> acceptDriverTrip(int id) async {
    final response = await _api.post('/mobile/drivers/trips/$id/accept');
    return Trip.fromJson(response.dataMap);
  }

  Future<void> rejectDriverTrip(int id) async {
    await _api.post('/mobile/drivers/trips/$id/reject');
  }

  Future<Trip> startDriverTrip(int id) async {
    final response = await _api.put('/mobile/drivers/trips/$id/start');
    return Trip.fromJson(response.dataMap);
  }

  Future<Trip> completeDriverTrip(int id) async {
    final response = await _api.put('/mobile/drivers/trips/$id/complete');
    return Trip.fromJson(response.dataMap);
  }

  Future<void> updateDriverStatus(bool isOnline) async {
    await _api.post('/mobile/drivers/status', body: {'is_online': isOnline});
  }

  Future<void> uploadDriverLocation({
    required LatLng position,
    int? tripId,
    double? heading,
    double? speed,
  }) async {
    final payload = {
      if (tripId != null) 'trip_id': tripId,
      'lat': position.latitude,
      'lng': position.longitude,
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    };
    try {
      await _api.post('/mobile/drivers/live-location', body: payload);
    } on ApiException {
      await _api.post('/mobile/driver/live-location', body: payload);
    }
  }

  Future<List<Trip>> driverTripHistory() async {
    final response = await _api.get('/driver/trips');
    return response
        .list(['trips', 'history', 'items'])
        .map(Trip.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> driverEarnings() async {
    final response = await _api.get('/driver/earnings');
    return response.dataMap;
  }
}
