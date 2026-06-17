import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../models/trip_model.dart';
import '../services/api_repository.dart';
import 'auth_provider.dart';

// ──────────────────────────────────────────────────────────────────────
// TRIP STATE NOTIFIER
// ──────────────────────────────────────────────────────────────────────

class TripStateNotifier extends StateNotifier<AsyncValue<TripDetails?>> {
  final ApiRepository _apiRepository;
  final Logger _logger;

  TripStateNotifier({
    required ApiRepository apiRepository,
    required Logger logger,
  }) : _apiRepository = apiRepository,
       _logger = logger,
       super(const AsyncValue.data(null));

  /// Create public bus trip
  Future<int> createPublicBusTrip({
    required String pickupLocation,
    required String dropoffLocation,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      state = const AsyncValue.loading();

      final request = TripRequestDto(
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        transportType: 'PUBLIC_BUS',
        pickupName: pickupLocation,
        pickupAddress: pickupLocation,
        dropoffName: dropoffLocation,
        dropoffAddress: dropoffLocation,
      );

      final response = await _apiRepository.createPublicBusTrip(request);

      if (!response.success) {
        throw Exception('Failed to create trip: ${response.message}');
      }

      state = AsyncValue.data(response.tripDetails);
      _logger.d('Public bus trip created: ${response.tripId}');

      return response.tripId;
    } catch (e, st) {
      _logger.e('Error creating public bus trip', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Create motorcycle trip
  Future<int> createMotorcycleTrip({
    required String pickupLocation,
    required String dropoffLocation,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      state = const AsyncValue.loading();

      final request = TripRequestDto(
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        transportType: 'MOTORCYCLE',
      );

      final response = await _apiRepository.createMotorcycleTrip(request);

      if (!response.success) {
        throw Exception('Failed to create trip: ${response.message}');
      }

      state = AsyncValue.data(response.tripDetails);
      _logger.d('Motorcycle trip created: ${response.tripId}');

      return response.tripId;
    } catch (e, st) {
      _logger.e('Error creating motorcycle trip', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Get trip status
  Future<void> getTripStatus(int tripId) async {
    try {
      state = const AsyncValue.loading();

      final response = await _apiRepository.getTripStatus(tripId);

      if (!response.success) {
        throw Exception('Failed to get trip status');
      }

      state = AsyncValue.data(response.tripDetails);
      _logger.d('Trip status retrieved: $tripId');
    } catch (e, st) {
      _logger.e('Error getting trip status', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// Update trip details
  void updateTripDetails(TripDetails tripDetails) {
    state = AsyncValue.data(tripDetails);
  }

  /// Clear current trip
  void clearTrip() {
    state = const AsyncValue.data(null);
  }
}

final tripStateProvider = StateNotifierProvider.autoDispose<
  TripStateNotifier,
  AsyncValue<TripDetails?>
>((ref) {
  final apiRepository = ref.watch(apiRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  return TripStateNotifier(apiRepository: apiRepository, logger: logger);
});

// ──────────────────────────────────────────────────────────────────────
// TRIP HISTORY PROVIDER
// ──────────────────────────────────────────────────────────────────────

class TripHistoryNotifier extends StateNotifier<AsyncValue<List<TripDetails>>> {
  final ApiRepository _apiRepository;
  final Logger _logger;

  TripHistoryNotifier({
    required ApiRepository apiRepository,
    required Logger logger,
  }) : _apiRepository = apiRepository,
       _logger = logger,
       super(const AsyncValue.data([]));

  /// Fetch trip history
  Future<void> fetchTripHistory({int page = 1, int perPage = 20}) async {
    try {
      state = const AsyncValue.loading();

      final trips = await _apiRepository.getPassengerTrips(
        page: page,
        perPage: perPage,
      );

      state = AsyncValue.data(trips);
      _logger.d('Fetched ${trips.length} trips from history');
    } catch (e, st) {
      _logger.e('Error fetching trip history', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }
}

final tripHistoryProvider = StateNotifierProvider.autoDispose<
  TripHistoryNotifier,
  AsyncValue<List<TripDetails>>
>((ref) {
  final apiRepository = ref.watch(apiRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  final notifier = TripHistoryNotifier(
    apiRepository: apiRepository,
    logger: logger,
  );

  // Auto-fetch on creation
  notifier.fetchTripHistory();

  return notifier;
});

// ──────────────────────────────────────────────────────────────────────
// TRIP STATUS POLLING PROVIDER
// ──────────────────────────────────────────────────────────────────────

final tripStatusPollingProvider = StreamProvider.autoDispose
    .family<TripStatusResponse, int>((ref, tripId) async* {
      final apiRepository = ref.watch(apiRepositoryProvider);

      // Poll for status updates every 3 seconds
      while (true) {
        try {
          final status = await apiRepository.getTripStatus(tripId);
          yield status;

          // Stop polling if trip is completed or cancelled
          if (['COMPLETED', 'CANCELLED', 'EXPIRED'].contains(status.status)) {
            break;
          }

          // Wait before next poll
          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          // Log error but continue polling
          ref.watch(loggerProvider).e('Error polling trip status', error: e);
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    });

// ──────────────────────────────────────────────────────────────────────
// DRIVER ACTION PROVIDERS
// ──────────────────────────────────────────────────────────────────────

final acceptTripProvider = FutureProvider.autoDispose
    .family<TripStatusResponse, int>((ref, tripId) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      return await apiRepository.acceptTrip(tripId);
    });

final rejectTripProvider = FutureProvider.autoDispose
    .family<TripStatusResponse, (int, String?)>((ref, args) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      final (tripId, reason) = args;
      return await apiRepository.rejectTrip(tripId, reason: reason);
    });

final arriveAtPickupProvider = FutureProvider.autoDispose
    .family<TripStatusResponse, int>((ref, tripId) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      return await apiRepository.driverArrived(tripId);
    });

final startTripProvider = FutureProvider.autoDispose
    .family<TripStatusResponse, int>((ref, tripId) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      return await apiRepository.startTrip(tripId);
    });

final completeTripProvider = FutureProvider.autoDispose
    .family<TripStatusResponse, int>((ref, tripId) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      return await apiRepository.completeTrip(tripId);
    });

final cancelTripProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (int, String)>((ref, args) async {
      final apiRepository = ref.watch(apiRepositoryProvider);
      final (tripId, reason) = args;
      return await apiRepository.cancelMotorcycleTrip(tripId, reason);
    });
