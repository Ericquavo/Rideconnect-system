import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:rideconnect_app/models/matching/matching_session.dart';
import 'package:rideconnect_app/services/matching/matching_repository.dart';

/// Provider for MatchingRepository singleton
final matchingRepositoryProvider = Provider((ref) {
  return MatchingRepository();
});

/// Current matching session state
final matchingSessionProvider =
    StateNotifierProvider<MatchingSessionNotifier, MatchingSession?>((ref) {
      return MatchingSessionNotifier(ref.read(matchingRepositoryProvider));
    });

class MatchingSessionNotifier extends StateNotifier<MatchingSession?> {
  final MatchingRepository _repository;

  MatchingSessionNotifier(this._repository) : super(null);

  /// Fetch drivers for matching
  Future<void> fetchDrivers({
    required String transportType,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    List<int>? excludedDriverIds,
  }) async {
    try {
      final session = await _repository.getAvailableDrivers(
        transportType: transportType,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        excludedDriverIds: excludedDriverIds,
      );
      state = session;
    } catch (e) {
      rethrow;
    }
  }

  /// Clear session (on timeout or error)
  void clearSession() {
    state = null;
  }

  /// Update session (for realtime updates)
  void updateSession(MatchingSession session) {
    state = session;
  }
}

/// Selected driver state
final selectedDriverProvider =
    StateNotifierProvider<SelectedDriverNotifier, DriverMatch?>((ref) {
      return SelectedDriverNotifier();
    });

class SelectedDriverNotifier extends StateNotifier<DriverMatch?> {
  SelectedDriverNotifier() : super(null);

  void selectDriver(DriverMatch driver) {
    state = driver;
  }

  void clearSelection() {
    state = null;
  }

  bool isSelected(int driverId) {
    return state?.driverId == driverId;
  }
}

/// Idempotency key generator
final idempotencyKeyProvider = Provider((ref) {
  return const Uuid().v4();
});

/// Loading state for driver selection flow
final driverSelectionLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Error state for driver selection flow
final driverSelectionErrorProvider = StateProvider<String?>((ref) {
  return null;
});

/// Filter unavailable drivers from matching session
final availableDriversProvider = Provider<List<DriverMatch>>((ref) {
  final session = ref.watch(matchingSessionProvider);
  if (session == null) return [];
  return session.drivers.where((d) => d.canSelect).toList();
});

/// Check if matching session is expired
final matchingSessionExpiredProvider = Provider<bool>((ref) {
  final session = ref.watch(matchingSessionProvider);
  if (session == null) return false;
  return session.isExpired;
});

/// Get seconds remaining in matching session
final matchingSessionSecondsRemainingProvider = Provider<int>((ref) {
  final session = ref.watch(matchingSessionProvider);
  if (session == null) return 0;
  return session.secondsRemaining;
});

/// Locked drivers (from realtime events)
final lockedDriversProvider = StateProvider<Set<int>>((ref) {
  return {};
});

/// Rejected drivers (from realtime events)
final rejectedDriversProvider = StateProvider<Set<int>>((ref) {
  return {};
});

/// Check if specific driver is locked
final isDriverLockedProvider = StateProvider.family<bool, int>((ref, driverId) {
  final locked = ref.watch(lockedDriversProvider);
  return locked.contains(driverId);
});

/// Check if specific driver is rejected
final isDriverRejectedProvider = StateProvider.family<bool, int>((
  ref,
  driverId,
) {
  final rejected = ref.watch(rejectedDriversProvider);
  return rejected.contains(driverId);
});
