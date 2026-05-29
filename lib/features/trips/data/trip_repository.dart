import 'dart:convert';
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
    print('[TripRepository] Sending request to /mobile/trips/request');
    print('[TripRepository] Request body: ${jsonEncode(body)}');
    print(
      '[TripRepository] Pickup fields: ${body.keys.where((k) => k.contains("pickup"))}',
    );
    print(
      '[TripRepository] Dropoff fields: ${body.keys.where((k) => k.contains("dropoff"))}',
    );

    try {
      final response = await _api.post('/mobile/trips/request', body: body);
      print('[TripRepository] Response status: ${response.statusCode}');
      print(
        '[TripRepository] Response envelope: ${jsonEncode(response.envelope)}',
      );

      // Check if the response indicates an error
      if (response.envelope['success'] == false) {
        print(
          '[TripRepository] API returned error: ${response.envelope['message']}',
        );
        print(
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
      print('[TripRepository] Exception occurred: $e');
      print('[TripRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<MatchingSession> matchPassengerDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    List<int> excludedDriverIds = const [],
  }) async {
    print(
      '[TripRepository] Matching drivers for transport_type: $transportType',
    );
    print('[TripRepository] Pickup: ($pickupLat, $pickupLng)');
    print('[TripRepository] Dropoff: ($dropoffLat, $dropoffLng)');

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

    print('[TripRepository] Match response status: ${response.statusCode}');
    print('[TripRepository] Match response: ${response.envelope}');

    final session = MatchingSession.fromJson(response.envelope);
    print('[TripRepository] Found ${session.drivers.length} drivers');
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

  Future<MatchingLifecycleSnapshot> matchingSnapshotForTrip(int id) async {
    final response = await _api.get('/passenger/trips/$id');
    final snapshot = MatchingLifecycleSnapshot.fromJson(response.envelope);
    if (snapshot.trip != null) return snapshot;
    return MatchingLifecycleSnapshot.fromTrip(Trip.fromJson(response.dataMap));
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
