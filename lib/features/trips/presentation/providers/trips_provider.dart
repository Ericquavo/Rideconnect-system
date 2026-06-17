import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/trips_datasource.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/models/trip_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/api_client.dart';

/// Trips Data Source Provider - Uses authenticated Dio
final tripsDataSourceProvider = Provider<ITripsDataSource>((ref) {
  return TripsDataSource(apiClient: ApiClient());
});

/// Trips Repository Provider
final tripsRepositoryProvider = Provider<ITripsRepository>((ref) {
  final dataSource = ref.watch(tripsDataSourceProvider);
  return TripsRepository(dataSource: dataSource);
});

/// Get recent trips (with pagination)
final tripsProvider =
    FutureProvider.family<List<TripData>, ({int? limit, int? offset})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(tripsRepositoryProvider);
      return repository.getTrips(
        limit: params.limit ?? 10,
        offset: params.offset ?? 0,
      );
    });

/// Get specific trip details
final tripDetailsProvider = FutureProvider.family<TripData, int>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripsRepositoryProvider);
  return repository.getTrip(tripId);
});

/// Compute route and get fare estimate
final routeComputeProvider =
    FutureProvider.family<RouteData, RouteComputeRequest>((ref, request) async {
      final repository = ref.watch(tripsRepositoryProvider);
      return repository.computeRoute(request);
    });

/// Create trip provider with state management
final createTripProvider = StateNotifierProvider.family<
  CreateTripNotifier,
  AsyncValue<TripData>,
  CreateTripRequest
>((ref, request) {
  final repository = ref.watch(tripsRepositoryProvider);
  return CreateTripNotifier(repository: repository, request: request);
});

/// Create Trip State Notifier
class CreateTripNotifier extends StateNotifier<AsyncValue<TripData>> {
  final ITripsRepository _repository;
  final CreateTripRequest _request;

  CreateTripNotifier({
    required ITripsRepository repository,
    required CreateTripRequest request,
  }) : _repository = repository,
       _request = request,
       super(const AsyncValue.loading());

  /// Create trip
  Future<void> createTrip() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.createTrip(_request, _request.transportType));
  }

  /// Reset state
  void reset() {
    state = const AsyncValue.loading();
  }
}

/// Cancel trip provider
final cancelTripProvider = FutureProvider.family<void, int>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripsRepositoryProvider);
  return repository.cancelTrip(tripId);
});

/// Rate trip provider
final rateTripProvider = FutureProvider.family<void, (int, RatingRequest, String)>((
  ref,
  params,
) async {
  final repository = ref.read(tripsRepositoryProvider);
  return repository.rateTrip(params.$1, params.$2, params.$3);
});

/// Get trip history provider
final tripHistoryProvider =
    FutureProvider.family<List<TripData>, ({int? limit, int? offset})?>((
      ref,
      params,
    ) async {
      final repository = ref.watch(tripsRepositoryProvider);
      return repository.getTripHistory(
        'moto',
        page: params?.offset != null ? (params!.offset! ~/ 20) + 1 : 1,
        perPage: params?.limit ?? 20,
      );
    });
