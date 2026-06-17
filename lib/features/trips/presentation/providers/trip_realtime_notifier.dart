import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';


import '../../domain/trip_realtime_event.dart';
import '../../services/trip_realtime_service.dart';

/// Realtime event UI state
class TripRealtimeUIState {
  const TripRealtimeUIState({
    required this.tripId,
    required this.currentEvent,
    required this.isConnected,
    required this.error,
    required this.lastUpdate,
  });

  final int tripId;
  final TripRealtimeEvent? currentEvent;
  final bool isConnected;
  final String? error;
  final DateTime? lastUpdate;

  // Computed properties for event types
  bool get isDriverAssigned => currentEvent?.isDriverAssigned ?? false;
  bool get isDriverAccepted => currentEvent?.isDriverAccepted ?? false;
  bool get isDriverArrived => currentEvent?.isDriverArrived ?? false;
  bool get isTripStarted => currentEvent?.isTripStarted ?? false;
  bool get isTripCompleted => currentEvent?.isTripCompleted ?? false;
  bool get isTripCancelled => currentEvent?.isTripCancelled ?? false;

  TripRealtimeUIState copyWith({
    int? tripId,
    TripRealtimeEvent? currentEvent,
    bool? isConnected,
    String? error,
    DateTime? lastUpdate,
  }) {
    return TripRealtimeUIState(
      tripId: tripId ?? this.tripId,
      currentEvent: currentEvent ?? this.currentEvent,
      isConnected: isConnected ?? this.isConnected,
      error: error ?? this.error,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Riverpod notifier for managing trip realtime state
class TripRealtimeNotifier
    extends AutoDisposeFamilyAsyncNotifier<TripRealtimeUIState, int> {
  final Logger _logger = Logger();
  late TripRealtimeService _service;
  StreamSubscription<dynamic>? _subscription;

  @override
  Future<TripRealtimeUIState> build(int tripId) async {
    _service = ref.watch(tripRealtimeServiceProvider);

    ref.onDispose(() {
      _logger.i('[TripRealtimeNotifier] Disposing trip $tripId');
      _subscription?.cancel();
    });

    // Initialize with connected state and start listening
    _logger.i('[TripRealtimeNotifier] Starting to watch trip $tripId');

    // Start listening to the stream
    final stream = _service.watchTrip(tripId);
    if (stream != null) {
      _subscription = stream.listen(
        (event) {
          _logger.d(
            '[TripRealtimeNotifier] Received event: ${event.event} for trip ${event.tripId}',
          );
          state = AsyncValue.data(
            state.value?.copyWith(
                  currentEvent: event,
                  isConnected: true,
                  error: null,
                  lastUpdate: DateTime.now(),
                ) ??
                TripRealtimeUIState(
                  tripId: tripId,
                  currentEvent: event,
                  isConnected: true,
                  error: null,
                  lastUpdate: DateTime.now(),
                ),
          );
        },
        onError: (error, stackTrace) {
          _logger.e(
            '[TripRealtimeNotifier] Stream error: $error',
            error: error,
            stackTrace: stackTrace,
          );
          state = AsyncValue.data(
            state.value?.copyWith(
                  isConnected: false,
                  error: error.toString(),
                ) ??
                TripRealtimeUIState(
                  tripId: tripId,
                  currentEvent: null,
                  isConnected: false,
                  error: error.toString(),
                  lastUpdate: null,
                ),
          );
        },
      );
    }

    return TripRealtimeUIState(
      tripId: tripId,
      currentEvent: null,
      isConnected: true,
      error: null,
      lastUpdate: null,
    );
  }
}

/// Provider for TripRealtimeService
final tripRealtimeServiceProvider = Provider<TripRealtimeService>((ref) {
  return TripRealtimeService();
});

/// Provider for trip realtime state (family-based for multiple trips)
final tripRealtimeNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<TripRealtimeNotifier, TripRealtimeUIState, int>(
      TripRealtimeNotifier.new,
    );
