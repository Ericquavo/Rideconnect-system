import 'package:logger/logger.dart';

/// Handles explicit Laravel broadcast events from backend
/// Normalizes payload structure and routes to appropriate handlers
class RideConnectEventRouter {
  static final Logger _logger = Logger();

  /// Callback signatures for event handlers
  static void Function(Map<String, dynamic>)? onDriverAssigned;
  static void Function(Map<String, dynamic>)? onDriverAccepted;
  static void Function(Map<String, dynamic>)? onDriverArrived;
  static void Function(Map<String, dynamic>)? onTripStarted;
  static void Function(Map<String, dynamic>)? onTripCompleted;
  static void Function(Map<String, dynamic>)? onTripCancelled;
  static void Function(Map<String, dynamic>)? onTripRequestUpdated;

  /// Route incoming event to appropriate handler
  static void handle(String eventName, Map<String, dynamic> payload) {
    // Log the event
    _logger.d(
      '[RideConnectEventRouter] Event: $eventName, Payload: ${_sanitizePayload(payload)}',
    );

    // Normalize payload structure
    final normalizedPayload = _normalizePayload(payload);

    // Route to appropriate handler
    switch (eventName) {
      case 'DriverAssigned':
        _onDriverAssigned(normalizedPayload);
        onDriverAssigned?.call(normalizedPayload);
        break;

      case 'DriverAccepted':
        _onDriverAccepted(normalizedPayload);
        onDriverAccepted?.call(normalizedPayload);
        break;

      case 'DriverArrived':
        _onDriverArrived(normalizedPayload);
        onDriverArrived?.call(normalizedPayload);
        break;

      case 'TripStarted':
        _onTripStarted(normalizedPayload);
        onTripStarted?.call(normalizedPayload);
        break;

      case 'TripCompleted':
        _onTripCompleted(normalizedPayload);
        onTripCompleted?.call(normalizedPayload);
        break;

      case 'TripCancelled':
        _onTripCancelled(normalizedPayload);
        onTripCancelled?.call(normalizedPayload);
        break;

      case 'TripRequestUpdated':
        _onTripRequestUpdated(normalizedPayload);
        onTripRequestUpdated?.call(normalizedPayload);
        break;

      default:
        _logger.w('[RideConnectEventRouter] Unknown event: $eventName');
    }
  }

  /// Normalize payload to standard structure
  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{};

    // Extract from nested 'data' or 'payload' if present
    final data =
        payload['data'] is Map<String, dynamic>
            ? payload['data'] as Map<String, dynamic>
            : payload['payload'] is Map<String, dynamic>
            ? payload['payload'] as Map<String, dynamic>
            : payload;

    // Copy all relevant fields
    normalized.addAll(data);

    // Ensure standard fields exist
    normalized['trip_id'] ??= payload['trip_id'] ?? data['trip_id'];
    normalized['driver_id'] ??= payload['driver_id'] ?? data['driver_id'];
    normalized['user_id'] ??= payload['user_id'] ?? data['user_id'];
    normalized['event'] ??= payload['event'] ?? data['event'];
    normalized['status'] ??= payload['status'] ?? data['status'];
    normalized['timestamp'] ??= payload['timestamp'] ?? data['timestamp'];

    return normalized;
  }

  /// Sanitize payload for logging (remove sensitive data)
  static Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload);
    sanitized.removeWhere(
      (key, value) =>
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('password') ||
          key.toLowerCase().contains('secret'),
    );
    return sanitized;
  }

  // ========== Event Handlers ==========

  static void _onDriverAssigned(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Driver assigned: driver=${payload['driver_id']} '
      'trip=${payload['trip_id']}',
    );
    // Update trip state to show driver assignment
  }

  static void _onDriverAccepted(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Driver accepted: driver=${payload['driver_id']} '
      'trip=${payload['trip_id']}',
    );
    // Update trip state to show driver accepted
  }

  static void _onDriverArrived(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Driver arrived: driver=${payload['driver_id']} '
      'trip=${payload['trip_id']}',
    );
    // Update trip state to show driver arrived
  }

  static void _onTripStarted(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Trip started: trip=${payload['trip_id']} '
      'driver=${payload['driver_id']}',
    );
    // Update trip state to show in-progress
  }

  static void _onTripCompleted(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Trip completed: trip=${payload['trip_id']} '
      'fare=${payload['fare']}',
    );
    // Update trip state to show completed
  }

  static void _onTripCancelled(Map<String, dynamic> payload) {
    _logger.i(
      '[Event] Trip cancelled: trip=${payload['trip_id']} '
      'reason=${payload['cancellation_reason']}',
    );
    // Update trip state to show cancelled
  }

  static void _onTripRequestUpdated(Map<String, dynamic> payload) {
    _logger.d(
      '[Event] Trip request updated: trip=${payload['trip_id']} '
      'status=${payload['status']}',
    );
    // Update trip request state
  }
}
