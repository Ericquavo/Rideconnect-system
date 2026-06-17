import 'dart:async';
import 'package:logger/logger.dart';

import '../core/services/rtdb_service.dart';
import '../features/trips/domain/trip_realtime_event.dart';
import '../features/trips/services/realtime_event_router.dart';

/// Handles RTDB-based real-time events (RTDB-only, no Firestore)
///
/// Architecture:
/// - Firebase RTDB: Real-time event stream (trip status changes)
/// - NO Firestore, NO WebSockets, NO Reverb, NO Echo, NO Pusher
/// - Only RTDB listeners via RTDBService
class RealtimeEventHandler {
  static final RealtimeEventHandler _instance =
      RealtimeEventHandler._internal();

  factory RealtimeEventHandler() {
    return _instance;
  }

  RealtimeEventHandler._internal();

  final Logger _logger = Logger();
  final RTDBService _rtdbService = RTDBService();
  final Map<int, StreamSubscription> _subscriptions = {};
  final _eventStreamController = StreamController<dynamic>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  bool get isConnected => _subscriptions.isNotEmpty;
  Stream<dynamic> get eventStream => _eventStreamController.stream;
  Stream<bool> get connectionStream => _connectionStateController.stream;

  /// Subscribe to RTDB for real-time trip events
  Future<void> subscribeToTrip(int tripId) async {
    if (_subscriptions.containsKey(tripId)) return;

    try {
      _logger.i(
        '[RealtimeEventHandler] Subscribing to active_trips/$tripId',
      );
      _connectionStateController.add(true);

      final subscription = _rtdbService
          .getTripStatusStream(tripId)
          .listen(
            (data) {
              try {
                if (data != null) {
                  final event = TripRealtimeEvent.fromRtdb(data, tripId);
                  if (!_eventStreamController.isClosed) {
                    _eventStreamController.add(event);
                    // Route to appropriate handler
                    RideConnectEventRouter.handle(event.event, event.payload);
                  }
                }
              } catch (e) {
                _logger.e('[RealtimeEventHandler] Error parsing event: $e');
              }
            },
            onError: (error) {
              _logger.e('[RealtimeEventHandler] Subscribe error: $error');
              _connectionStateController.add(false);
              _scheduleRecovery(tripId);
            },
          );

      _subscriptions[tripId] = subscription;
    } catch (e) {
      _logger.e('[RealtimeEventHandler] Connection error: $e');
      _connectionStateController.add(false);
      rethrow;
    }
  }

  void _scheduleRecovery(int tripId) {
    Timer(const Duration(seconds: 5), () {
      if (_subscriptions.containsKey(tripId)) {
        _logger.d(
          '[RealtimeEventHandler] Attempting reconnection for trip $tripId',
        );
        subscribeToTrip(tripId);
      }
    });
  }

  /// Unsubscribe from a specific trip
  Future<void> unsubscribeFromTrip(int tripId) async {
    await _subscriptions[tripId]?.cancel();
    _subscriptions.remove(tripId);
    if (_subscriptions.isEmpty) {
      _connectionStateController.add(false);
    }
  }

  /// Disconnect from all RTDB listeners
  Future<void> disconnect() async {
    _logger.i('[RealtimeEventHandler] Disconnecting from all trips');
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _connectionStateController.add(false);
  }

  /// Cleanup on dispose
  Future<void> dispose() async {
    await disconnect();
    if (!_eventStreamController.isClosed) {
      await _eventStreamController.close();
    }
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  /// Subscribe to specific event type
  Stream<T> subscribeToEvent<T>() {
    return _eventStreamController.stream.where((event) => event is T).cast<T>();
  }
}
