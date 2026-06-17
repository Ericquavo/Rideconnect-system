import '../domain/matching_lifecycle_models.dart';
import 'trip_repository.dart';

class TripLifecycleService {
  TripLifecycleService(this._repository);

  final TripRepository _repository;

  Future<MatchingLifecycleSnapshot> snapshot(
    int tripId, {
    MatchingLifecycleSnapshot? previous,
  }) {
    return _repository.lifecycleSnapshotForTrip(tripId, previous: previous);
  }

  Stream<MatchingLifecycleSnapshot> watch(
    int tripId, {
    MatchingLifecycleSnapshot? initial,
    Duration interval = const Duration(seconds: 3),
  }) async* {
    var previous = initial;
    while (true) {
      final snapshot = await this.snapshot(tripId, previous: previous);
      previous = snapshot;
      yield snapshot;
      if (snapshot.status.isTerminal) return;
      await Future<void>.delayed(interval);
    }
  }
}
