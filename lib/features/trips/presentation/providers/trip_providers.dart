import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../data/trip_lifecycle_service.dart';
import '../../data/trip_repository.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_lifecycle_state.dart';
import '../../domain/trip_models.dart';
import '../../services/trip_lifecycle_manager.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.read(apiClientProvider)),
);

final tripLifecycleServiceProvider = Provider<TripLifecycleService>(
  (ref) => TripLifecycleService(ref.read(tripRepositoryProvider)),
);

final motorVehicleTripMatchingServiceProvider =
    Provider<TripLifecycleManager>((ref) => TripLifecycleManager());

final motorVehicleTripMatchingProvider = AutoDisposeAsyncNotifierProviderFamily<
  MotorVehicleTripMatchingNotifier,
  TripLifecycleState,
  MotorVehicleTripMatchingRequest
>(MotorVehicleTripMatchingNotifier.new);

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
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
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
    extends
        AutoDisposeFamilyAsyncNotifier<
          TripLifecycleState,
          MotorVehicleTripMatchingRequest
        > {
  StreamSubscription<TripLifecycleState>? _subscription;
  TripLifecycleManager? _manager;

  TripLifecycleManager get _service =>
      _manager ??= TripLifecycleManager();

  @override
  Future<TripLifecycleState> build(
    MotorVehicleTripMatchingRequest request,
  ) async {
    ref.onDispose(() {
      _subscription?.cancel();
      _manager?.dispose();
      _manager = null;
    });

    await _service.start(
      request.tripId,
      initialStatus: request.initialStatus,
      initialMatchingStatus: request.initialMatchingStatus,
      initialData: request.initialData,
    );
    _subscription = _service.stream.listen((nextState) {
      state = AsyncValue.data(nextState);
      if (nextState.isTerminal) {
        _subscription?.cancel();
      }
    });

    return _service.latest ??
        TripLifecycleState.initial(tripId: request.tripId);
  }

  void pause() {
    _service.pause();
  }

  void resume() {
    _service.resume();
  }

  Future<void> refreshTripState() {
    return _service.refreshTripState(reason: 'notifier-refresh');
  }
}

class MotorVehicleTripMatchingRequest {
  const MotorVehicleTripMatchingRequest({
    required this.tripId,
    this.initialStatus,
    this.initialMatchingStatus,
    this.initialData = const <String, dynamic>{},
  });

  final int tripId;
  final String? initialStatus;
  final String? initialMatchingStatus;
  final Map<String, dynamic> initialData;

  @override
  bool operator ==(Object other) {
    return other is MotorVehicleTripMatchingRequest &&
        other.tripId == tripId &&
        other.initialStatus == initialStatus &&
        other.initialMatchingStatus == initialMatchingStatus;
  }

  @override
  int get hashCode => Object.hash(tripId, initialStatus, initialMatchingStatus);
}

final driverLocationProvider = StateNotifierProvider.family.autoDispose<DriverLocationNotifier, AsyncValue<LatLng?>, int>(
  (ref, driverId) => DriverLocationNotifier(ref, driverId),
);

class DriverLocationNotifier extends StateNotifier<AsyncValue<LatLng?>> {
  DriverLocationNotifier(this.ref, this.driverId) : super(const AsyncValue.loading()) {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchLocation());
    fetchLocation();
  }

  final Ref ref;
  final int driverId;
  Timer? _timer;

  Future<void> fetchLocation() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final response = await repo.lifecycleSnapshotForTrip(driverId); // fallback status check or location check
      // We can hit /v3/location/live/{driverId} or status
      final liveRes = await ref.read(apiClientProvider).get('/v3/location/live/$driverId');
      final liveData = liveRes.data['data'] ?? liveRes.data;
      if (liveData is Map<String, dynamic>) {
        final lat = double.tryParse(liveData['latitude']?.toString() ?? liveData['lat']?.toString() ?? '');
        final lng = double.tryParse(liveData['longitude']?.toString() ?? liveData['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          state = AsyncValue.data(LatLng(lat, lng));
          return;
        }
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // Fallback to /v3/location/{userId} if live endpoint fails
      try {
        final res = await ref.read(apiClientProvider).get('/v3/location/$driverId');
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic>) {
          final lat = double.tryParse(data['latitude']?.toString() ?? data['lat']?.toString() ?? '');
          final lng = double.tryParse(data['longitude']?.toString() ?? data['lng']?.toString() ?? '');
          if (lat != null && lng != null) {
            state = AsyncValue.data(LatLng(lat, lng));
            return;
          }
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final routeProvider = FutureProvider.family.autoDispose<List<LatLng>, (LatLng, LatLng)>((ref, coords) async {
  final repo = ref.read(tripRepositoryProvider);
  return repo.computeRoute(coords.$1, coords.$2);
});
