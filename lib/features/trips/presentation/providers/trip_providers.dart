import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/trip_lifecycle_service.dart';
import '../../data/trip_repository.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_lifecycle_state.dart';
import '../../domain/trip_models.dart';
import '../../services/trip_matching_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.read(apiClientProvider)),
);

final tripLifecycleServiceProvider = Provider<TripLifecycleService>(
  (ref) => TripLifecycleService(ref.read(tripRepositoryProvider)),
);

final motorVehicleTripMatchingServiceProvider = Provider<TripMatchingService>(
  (ref) => TripMatchingService(),
);

final motorVehicleTripMatchingProvider = AutoDisposeAsyncNotifierProviderFamily<
    MotorVehicleTripMatchingNotifier,
    TripLifecycleState,
    int>(
  MotorVehicleTripMatchingNotifier.new,
);

final passengerTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) {
  return ref.read(tripRepositoryProvider).passengerTrips();
});

final driverTripHistoryProvider = FutureProvider.autoDispose<List<Trip>>((ref) {
  return ref.read(tripRepositoryProvider).driverTripHistory();
});

final incomingDriverTripsProvider = FutureProvider.autoDispose<List<Trip>>((
  ref,
) {
  return ref.read(tripRepositoryProvider).incomingDriverTrips();
});

final activeMatchingProvider = AsyncNotifierProvider.autoDispose<
  ActiveMatchingNotifier,
  MatchingLifecycleSnapshot?
>(ActiveMatchingNotifier.new);

final tripMatchingProvider = AsyncNotifierProvider.autoDispose
    .family<TripMatchingNotifier, MatchingLifecycleSnapshot, int>(
      TripMatchingNotifier.new,
    );

final driverEarningsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    return ref.read(tripRepositoryProvider).driverEarnings();
  },
);

final tripTrackingProvider = AsyncNotifierProvider.autoDispose
    .family<TripTrackingNotifier, TripTracking, int>(TripTrackingNotifier.new);

class TripTrackingNotifier
    extends AutoDisposeFamilyAsyncNotifier<TripTracking, int> {
  Timer? _timer;

  @override
  Future<TripTracking> build(int arg) async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
    return ref.read(tripRepositoryProvider).trackTrip(arg);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(tripRepositoryProvider).trackTrip(arg),
    );
  }
}

class ActiveMatchingNotifier
    extends AutoDisposeAsyncNotifier<MatchingLifecycleSnapshot?> {
  Timer? _timer;

  @override
  Future<MatchingLifecycleSnapshot?> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    return ref.read(tripRepositoryProvider).currentPassengerMatching();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(tripRepositoryProvider).currentPassengerMatching(),
    );
  }
}

class TripMatchingNotifier
    extends AutoDisposeFamilyAsyncNotifier<MatchingLifecycleSnapshot, int> {
  Timer? _timer;

  @override
  Future<MatchingLifecycleSnapshot> build(int arg) async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    return ref.read(tripLifecycleServiceProvider).snapshot(arg);
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final result = await AsyncValue.guard(
      () => ref
          .read(tripLifecycleServiceProvider)
          .snapshot(arg, previous: previous),
    );
    if (result.hasError && previous != null) {
      state = AsyncValue.data(previous);
      return;
    }
    state = result;
    final snapshot = result.valueOrNull;
    if (snapshot != null && snapshot.status.isTerminal) {
      _timer?.cancel();
    }
  }
}

class MotorVehicleTripMatchingNotifier
    extends AutoDisposeFamilyAsyncNotifier<TripLifecycleState, int> {
  StreamSubscription<TripLifecycleState>? _subscription;

  TripMatchingService get _service =>
      ref.read(motorVehicleTripMatchingServiceProvider);

  @override
  Future<TripLifecycleState> build(int tripId) async {
    ref.onDispose(() {
      _subscription?.cancel();
      _service.dispose();
    });

    _service.startPolling(tripId);
    _subscription = _service.stream.listen((nextState) {
      state = AsyncValue.data(nextState);
      if (nextState.isTerminal) {
        _subscription?.cancel();
      }
    });

    return _service.latest ?? TripLifecycleState.initial(tripId: tripId);
  }

  void pause() {
    _service.pause();
  }

  void resume() {
    _service.resume();
  }
}
