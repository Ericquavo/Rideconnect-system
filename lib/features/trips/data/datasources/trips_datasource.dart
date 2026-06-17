import 'package:logger/logger.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../models/trip_models.dart';

/// Low-level API calls for trip operations
abstract class ITripsDataSource {
  /// Get current active trip (for matching flow)
  Future<CreateTripResponse> getCurrentTrip();

  /// Get list of trips (recent, completed, etc.)
  Future<TripsListResponse> getTrips({int? limit, int? offset, String? status});

  /// Get specific trip details
  Future<CreateTripResponse> getTrip(int tripId);

  /// Create a new trip request
  Future<CreateTripResponse> createTrip(CreateTripRequest request, String vehicleType);

  /// Compute route and fare estimate
  Future<RouteComputeResponse> computeRoute(RouteComputeRequest request);

  /// Cancel a trip
  Future<CreateTripResponse> cancelTrip(int tripId, {String? reason});

  /// Rate/review a completed trip
  Future<CreateTripResponse> rateTrip(int tripId, RatingRequest request, String vehicleType);

  /// Acknowledge a trip status transition
  Future<void> acknowledgeTripStatus(int tripId, String ackType);

  /// Get trip history (completed trips)
  Future<TripsListResponse> getTripHistory(String vehicleType, {int? page, int? perPage});
}

/// Implementation using ApiClient
class TripsDataSource implements ITripsDataSource {
  final ApiClient _apiClient;
  final Logger _logger;

  TripsDataSource({
    required ApiClient apiClient,
    Logger? logger,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger();

  @override
  Future<CreateTripResponse> getCurrentTrip() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.currentTrip,
      );

      _logger.d('Current trip response: ${response.data}');

      if (response.data == null) {
        throw ApiException(
          message: 'Empty response from server',
          statusCode: response.statusCode,
        );
      }

      return CreateTripResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error getting current trip: $e');
      throw ApiException(
        message: 'Failed to get current trip: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<TripsListResponse> getTrips({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/mobile/trips',
        queryParameters: {
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
          if (status != null) 'status': status,
        },
      );

      return TripsListResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error getting trips: $e');
      throw ApiException(
        message: 'Failed to get trips: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<CreateTripResponse> getTrip(int tripId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.replacePath(ApiEndpoints.tripDetails, {'id': tripId}),
      );

      return CreateTripResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error getting trip: $e');
      throw ApiException(
        message: 'Failed to get trip: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<CreateTripResponse> createTrip(CreateTripRequest request, String vehicleType) async {
    try {
      // Determine endpoint based on vehicle type
      String endpoint;
      switch (vehicleType.toLowerCase()) {
        case 'motorcycle':
        case 'motor-vehicle':
          endpoint = ApiEndpoints.motorVehicleTripRequest;
          break;
        case 'private-car':
        case 'private car':
          endpoint = ApiEndpoints.privateCarTripRequest;
          break;
        case 'public-bus':
        case 'public bus':
          endpoint = ApiEndpoints.publicBusTripRequest;
          break;
        default:
          endpoint = ApiEndpoints.motorVehicleTripRequest;
      }

      // Map request fields to API format
      final requestData = {
        'pickup_location': request.originAddress,
        'pickup_lat': request.originLat,
        'pickup_lng': request.originLng,
        'dropoff_location': request.destinationAddress,
        'dropoff_lat': request.destinationLat,
        'dropoff_lng': request.destinationLng,
        'vehicle_type': vehicleType,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: requestData,
      );

      _logger.d('Create trip response: ${response.data}');

      return CreateTripResponse.fromJson(response.data!);
    } on ActiveTripExistsException {
      rethrow; // Let this propagate for UI handling
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error creating trip: $e');
      throw ApiException(
        message: 'Failed to create trip: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<RouteComputeResponse> computeRoute(RouteComputeRequest request) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.routeCompute,
        data: request.toJson(),
      );

      return RouteComputeResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error computing route: $e');
      throw ApiException(
        message: 'Failed to compute route: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<CreateTripResponse> cancelTrip(int tripId, {String? reason}) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/mobile/trips/$tripId/cancel',
        data: {if (reason != null) 'reason': reason},
      );

      return CreateTripResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error cancelling trip: $e');
      throw ApiException(
        message: 'Failed to cancel trip: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<CreateTripResponse> rateTrip(int tripId, RatingRequest request, String vehicleType) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.passengerRate(vehicleType, tripId),
        data: request.toJson(),
      );

      return CreateTripResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error rating trip: $e');
      throw ApiException(
        message: 'Failed to rate trip: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> acknowledgeTripStatus(int tripId, String ackType) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.tripAcknowledge(tripId),
        data: {
          'acknowledgement_type': ackType,
          'source': 'flutter',
        },
      );
    } catch (e) {
      _logger.d('Error acknowledging trip status (non-fatal): $e');
    }
  }

  @override
  Future<TripsListResponse> getTripHistory(String vehicleType, {int? page, int? perPage}) async {
    try {
      final endpoint = ApiEndpoints.replacePath(
        ApiEndpoints.tripHistory,
        {'type': vehicleType},
      );

      final response = await _apiClient.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );

      return TripsListResponse.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      _logger.e('Error getting trip history: $e');
      throw ApiException(
        message: 'Failed to get trip history: ${e.toString()}',
        originalError: e,
      );
    }
  }
}
