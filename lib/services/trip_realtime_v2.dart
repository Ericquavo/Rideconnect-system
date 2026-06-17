// File: lib/services/trip_realtime_v2.dart
// V2 Realtime Trip Subscription Service
import 'dart:async';

import '../core/services/rtdb_service.dart';
import '../features/trips/services/trip_realtime_service.dart';

typedef NewTripRequestCallback = void Function(Map<String, dynamic> payload);
typedef TripStatusChangeCallback = void Function(int tripId, String status);
typedef DriverLocationUpdateCallback =
    void Function(double latitude, double longitude, double? speedKmh);

enum TripRealtimeEventType { newRequest, statusChanged, driverLocation }

class TripRealtimeV2 {
  TripRealtimeV2({TripRealtimeService? realtimeService})
    : _service = realtimeService ?? TripRealtimeService();

  final TripRealtimeService _service;
  StreamSubscription<dynamic>? _subscription;
  Timer? _mockTimer;
  bool _subscribed = false;
  bool _acceptedNotified = false;

  /// Subscribe as a driver to realtime trip requests.
  /// This is a placeholder until the backend exposes a dedicated driver topic.
  void subscribeAsDriver({
    required int driverId,
    required NewTripRequestCallback onNewTripRequest,
    TripStatusChangeCallback? onStatusChanged,
    DriverLocationUpdateCallback? onDriverLocation,
  }) {
    if (_subscribed) return;
    _subscribed = true;

    _mockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final payload = {
        'tripId': 123,
        'pickupLocation': '123 Main St',
        'dropoffLocation': '456 Market Ave',
        'fare': 1250.0,
        'transportType': 'moto',
        'expiresAt':
            DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
        'passengerName': 'Jane Doe',
        'passengerRating': 4.8,
      };
      onNewTripRequest(payload);
    });
  }

  /// Subscribe as a passenger to realtime trip updates.
  void subscribeAsPassenger({
    required int tripId,
    required void Function(double latitude, double longitude, double? speedKmh)
    onDriverLocation,
    required void Function(Map<String, dynamic> driver) onTripAccepted,
    required void Function(String status) onStatusChanged,
    required void Function() onTripCancelled,
  }) {
    if (_subscribed) return;
    _subscribed = true;
    _acceptedNotified = false;

    // Use new Firestore watchTrip API
    final eventStream = _service.watchTrip(tripId);
    if (eventStream != null) {
      _subscription = eventStream.listen(
        (event) {
          _handlePassengerMessage(
            event.payload,
            onDriverLocation,
            onTripAccepted,
            onStatusChanged,
            onTripCancelled,
          );
        },
        onError: (_) {
          _startMockPassengerSubscription(
            onDriverLocation: onDriverLocation,
            onTripAccepted: onTripAccepted,
            onStatusChanged: onStatusChanged,
          );
        },
      );
    } else {
      // Fallback to mock if realtime unavailable
      _startMockPassengerSubscription(
        onDriverLocation: onDriverLocation,
        onTripAccepted: onTripAccepted,
        onStatusChanged: onStatusChanged,
      );
    }
  }

  void _handlePassengerMessage(
    Map<String, dynamic> payload,
    void Function(double latitude, double longitude, double? speedKmh)
    onDriverLocation,
    void Function(Map<String, dynamic> driver) onTripAccepted,
    void Function(String status) onStatusChanged,
    void Function() onTripCancelled,
  ) {
    final data =
        payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload;

    final status = _normalizeStatus(
      data['status'] ?? data['trip_status'] ?? payload['type'] ?? data['event'],
    );
    if (status != null) {
      onStatusChanged(status);
    }

    final driver = _extractDriver(data);
    if (!_acceptedNotified && status != null && _isAcceptedStatus(status)) {
      _acceptedNotified = true;
      onTripAccepted(driver ?? <String, dynamic>{'status': status});
    }

    final driverLocation = _extractLocation(data);
    if (driverLocation != null) {
      onDriverLocation(
        driverLocation['lat']!,
        driverLocation['lng']!,
        driverLocation['speed'],
      );
    }

    if (status != null && _isCancelledStatus(status)) {
      onTripCancelled();
    }
  }

  Map<String, dynamic>? _extractDriver(dynamic source) {
    if (source is! Map<String, dynamic>) return null;
    final driverData =
        source['driver'] ??
        source['assigned_driver'] ??
        source['driver_info'] ??
        source;
    if (driverData is Map<String, dynamic>) {
      return Map<String, dynamic>.from(driverData);
    }
    return null;
  }

  Map<String, double?>? _extractLocation(Map<String, dynamic> source) {
    double? lat;
    double? lng;
    double? speed;

    if (source.containsKey('driver_lat') || source.containsKey('driver_lng')) {
      lat = _parseDouble(source['driver_lat']);
      lng = _parseDouble(source['driver_lng']);
      speed = _parseDouble(source['driver_speed'] ?? source['speed_kmh']);
    }

    if (lat == null || lng == null) {
      lat = _parseDouble(
        source['current_lat'] ?? source['lat'] ?? source['latitude'],
      );
      lng = _parseDouble(
        source['current_lng'] ?? source['lng'] ?? source['longitude'],
      );
      speed = _parseDouble(source['speed_kmh'] ?? source['speed']);
    }

    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng, 'speed': speed};
  }

  bool _isAcceptedStatus(String status) {
    return status == 'accepted' || status == 'driver_accepted';
  }

  bool _isCancelledStatus(String status) {
    return status == 'cancelled' || status == 'trip_cancelled';
  }

  String? _normalizeStatus(dynamic raw) {
    final value = raw?.toString().trim().toUpperCase();
    if (value == null || value.isEmpty) return null;
    if (value.contains('DRIVER_ACCEPTED') ||
        value.contains('PASSENGER_WAITING') ||
        value.contains('ACCEPT')) {
      return 'accepted';
    }
    if (value.contains('DRIVER_ARRIVING') ||
        value.contains('ENROUTE') ||
        value.contains('ON_THE_WAY')) {
      return 'enroute_to_pickup';
    }
    if (value.contains('DRIVER_ARRIVED') || value.contains('ARRIVED')) {
      return 'arrived_at_pickup';
    }
    if (value.contains('IN_PROGRESS') || value.contains('STARTED')) {
      return 'in_progress';
    }
    if (value.contains('COMPLETED')) {
      return 'completed';
    }
    if (value.contains('CANCEL') || value.contains('REJECT')) {
      return 'cancelled';
    }
    if (value.contains('ASSIGNED') || value.contains('NEW_TRIP_REQUEST')) {
      return 'assigning';
    }
    if (value.contains('REQUEST') || value.contains('SEARCH')) {
      return 'requested';
    }

    return value.toLowerCase();
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void _startMockPassengerSubscription({
    required void Function(double latitude, double longitude, double? speedKmh)
    onDriverLocation,
    required void Function(Map<String, dynamic> driver) onTripAccepted,
    required void Function(String status) onStatusChanged,
  }) {
    if (!_subscribed) return;
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      onDriverLocation(2.0, 30.0, 32.5);
      onTripAccepted({'driver_id': 555, 'name': 'Michael'});
      onStatusChanged('accepted');
    });
  }

  /// Unsubscribe from realtime events.
  void unsubscribe() {
    _mockTimer?.cancel();
    _subscription?.cancel();
    _service.dispose();
    _subscribed = false;
  }
}
