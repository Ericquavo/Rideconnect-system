import 'package:flutter/foundation.dart';

@immutable
class TripRealtimeEvent {
  const TripRealtimeEvent({
    required this.event,
    required this.tripId,
    required this.timestamp,
    required this.payload,
  });

  final String event;
  final int tripId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  /// Create from RTDB data snapshot
  static TripRealtimeEvent fromRtdb(
    Map<String, dynamic> data,
    int tripId,
  ) {
    return TripRealtimeEvent(
      event: (data['status'] as String?) ?? 'StatusUpdate',
      tripId: tripId,
      timestamp: _parseTimestamp(data['updated_at']),
      payload: data,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  bool get isDriverAssigned => event == 'DRIVER_ASSIGNED';
  bool get isDriverAccepted => event == 'DRIVER_ACCEPTED';
  bool get isDriverArrived => event == 'ARRIVED_AT_PICKUP';
  bool get isTripStarted => event == 'TRIP_STARTED';
  bool get isTripCompleted => event == 'TRIP_COMPLETED';
  bool get isTripCancelled => event == 'CANCELLED';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripRealtimeEvent &&
          runtimeType == other.runtimeType &&
          event == other.event &&
          tripId == other.tripId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(event, tripId, timestamp);
}
