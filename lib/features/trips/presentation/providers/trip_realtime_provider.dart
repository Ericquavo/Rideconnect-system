import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../domain/trip_realtime_event.dart';
import '../../services/trip_realtime_service.dart';

enum RealtimeConnectionStatus { initial, loading, connected, error }

class TripRealtimeState {
  const TripRealtimeState({
    this.status = RealtimeConnectionStatus.initial,
    this.currentEvent,
    this.error,
    this.retryCount = 0,
  });

  final RealtimeConnectionStatus status;
  final TripRealtimeEvent? currentEvent;
  final String? error;
  final int retryCount;

  TripRealtimeState copyWith({
    RealtimeConnectionStatus? status,
    TripRealtimeEvent? currentEvent,
    String? error,
    int? retryCount,
  }) {
    return TripRealtimeState(
      status: status ?? this.status,
      currentEvent: currentEvent ?? this.currentEvent,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

final tripRealtimeServiceProvider = Provider<TripRealtimeService>((ref) {
  return TripRealtimeService();
});

final tripRealtimeStreamProvider = StreamProvider.autoDispose
    .family<TripRealtimeEvent, int>((ref, tripId) {
      final service = ref.watch(tripRealtimeServiceProvider);
      final stream = service.watchTrip(tripId);
      return stream!;
    });
