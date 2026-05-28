import 'package:flutter/foundation.dart';

/// Base class for real-time events
@immutable
abstract class RealtimeEvent {
  final String eventType;
  final String matchingSessionId;
  final DateTime receivedAt;

  const RealtimeEvent({
    required this.eventType,
    required this.matchingSessionId,
    required this.receivedAt,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final type = json['event_type'] as String? ?? '';
    final sessionId = json['matching_session_id'] as String? ?? '';
    final receivedAt =
        DateTime.tryParse(json['received_at'] as String? ?? '') ??
        DateTime.now();

    switch (type) {
      case 'DriverTemporarilyLocked':
        return DriverTemporarilyLockedEvent(
          matchingSessionId: sessionId,
          driverId: json['driver_id'] as int? ?? 0,
          lockDurationSeconds: json['lock_duration_seconds'] as int? ?? 300,
          reason: json['reason'] as String? ?? 'Unknown',
          receivedAt: receivedAt,
        );
      case 'DriverAssignmentAccepted':
        return DriverAssignmentAcceptedEvent(
          matchingSessionId: sessionId,
          driverId: json['driver_id'] as int? ?? 0,
          tripId: json['trip_id'] as String? ?? '',
          receivedAt: receivedAt,
        );
      case 'DriverAssignmentRejected':
        return DriverAssignmentRejectedEvent(
          matchingSessionId: sessionId,
          driverId: json['driver_id'] as int? ?? 0,
          reason: json['reason'] as String? ?? 'Unknown',
          receivedAt: receivedAt,
        );
      case 'DriverMatchAvailabilityChanged':
        return DriverMatchAvailabilityChangedEvent(
          matchingSessionId: sessionId,
          driverId: json['driver_id'] as int? ?? 0,
          availabilityStatus:
              json['availability_status'] as String? ?? 'unknown',
          receivedAt: receivedAt,
        );
      default:
        throw UnimplementedError('Unknown event type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

/// Driver is temporarily locked (can't be selected)
@immutable
class DriverTemporarilyLockedEvent extends RealtimeEvent {
  final int driverId;
  final int lockDurationSeconds;
  final String reason;

  const DriverTemporarilyLockedEvent({
    required String matchingSessionId,
    required this.driverId,
    required this.lockDurationSeconds,
    required this.reason,
    required DateTime receivedAt,
  }) : super(
         eventType: 'DriverTemporarilyLocked',
         matchingSessionId: matchingSessionId,
         receivedAt: receivedAt,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'matching_session_id': matchingSessionId,
      'driver_id': driverId,
      'lock_duration_seconds': lockDurationSeconds,
      'reason': reason,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}

/// Driver accepted the assignment
@immutable
class DriverAssignmentAcceptedEvent extends RealtimeEvent {
  final int driverId;
  final String tripId;

  const DriverAssignmentAcceptedEvent({
    required String matchingSessionId,
    required this.driverId,
    required this.tripId,
    required DateTime receivedAt,
  }) : super(
         eventType: 'DriverAssignmentAccepted',
         matchingSessionId: matchingSessionId,
         receivedAt: receivedAt,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'matching_session_id': matchingSessionId,
      'driver_id': driverId,
      'trip_id': tripId,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}

/// Driver rejected the assignment
@immutable
class DriverAssignmentRejectedEvent extends RealtimeEvent {
  final int driverId;
  final String reason;

  const DriverAssignmentRejectedEvent({
    required String matchingSessionId,
    required this.driverId,
    required this.reason,
    required DateTime receivedAt,
  }) : super(
         eventType: 'DriverAssignmentRejected',
         matchingSessionId: matchingSessionId,
         receivedAt: receivedAt,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'matching_session_id': matchingSessionId,
      'driver_id': driverId,
      'reason': reason,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}

/// Driver availability changed (went offline, busy, etc)
@immutable
class DriverMatchAvailabilityChangedEvent extends RealtimeEvent {
  final int driverId;
  final String availabilityStatus; // 'online', 'offline', 'busy'

  const DriverMatchAvailabilityChangedEvent({
    required String matchingSessionId,
    required this.driverId,
    required this.availabilityStatus,
    required DateTime receivedAt,
  }) : super(
         eventType: 'DriverMatchAvailabilityChanged',
         matchingSessionId: matchingSessionId,
         receivedAt: receivedAt,
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'matching_session_id': matchingSessionId,
      'driver_id': driverId,
      'availability_status': availabilityStatus,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}
