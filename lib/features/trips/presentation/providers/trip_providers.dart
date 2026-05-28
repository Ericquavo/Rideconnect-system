import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/trip_repository.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.read(apiClientProvider)),
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
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
    return ref.read(tripRepositoryProvider).matchingSnapshotForTrip(arg);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(tripRepositoryProvider).matchingSnapshotForTrip(arg),
    );
  }
}
