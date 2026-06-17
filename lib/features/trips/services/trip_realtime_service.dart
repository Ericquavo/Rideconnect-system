import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';

import 'realtime_event_router.dart';
import '../domain/trip_realtime_event.dart';

/// Real-time service using Firebase Realtime Database (RTDB).
/// Listens to RTDB nodes for active trip updates and driver events.
class TripRealtimeService {
  TripRealtimeService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final Map<int, StreamSubscription<DatabaseEvent>> _subscriptions = {};
  StreamController<TripRealtimeEvent>? _controller;

  bool get isConnected => _subscriptions.isNotEmpty;
  bool get isRealtimeEnabled => true;

  /// Watch a trip's realtime events via RTDB path `active_trips/{tripId}`.
  Stream<TripRealtimeEvent>? watchTrip(int tripId) {
    _controller ??= StreamController<TripRealtimeEvent>.broadcast();
    final ref = FirebaseDatabase.instance.ref('active_trips').child(tripId.toString());
    _logger.i('[TripRealtimeService] Watching RTDB path: active_trips/$tripId');

    _subscriptions[tripId]?.cancel();
    final subscription = ref.onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        if (data != null && data is Map<dynamic, dynamic>) {
          // Add cast to ensure type safety
          final Map<String, dynamic> typedData = Map<String, dynamic>.from(data);
          final realtimeEvent = TripRealtimeEvent.fromRtdb(typedData, tripId);
          if (!_controller!.isClosed) _controller!.add(realtimeEvent);
        }
      } catch (e) {
        _logger.e('[TripRealtimeService] Error parsing RTDB event: $e');
      }
    }, onError: (error) {
      _logger.e('[TripRealtimeService] RTDB subscribe error: $error');
      _scheduleRecovery(tripId);
    });

    _subscriptions[tripId] = subscription;
    return _controller!.stream;
  }

  void _scheduleRecovery(int tripId) {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_subscriptions.containsKey(tripId)) {
        timer.cancel();
        return;
      }
      _logger.d('[TripRealtimeService] Attempting RTDB reconnection...');
    });
  }

  Future<void> dispose() async {
    _logger.i('[TripRealtimeService] Disposing RTDB subscriptions');
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
    _controller = null;
  }

  void handleRealtimeEvent(TripRealtimeEvent event) {
    final payload = {
      'event': event.event,
      'trip_id': event.tripId,
      ...event.payload,
    };
    RideConnectEventRouter.handle(event.event, payload);
  }
}
