import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip_model.dart';
import '../../models/location_model.dart';
import '../../models/user_model.dart';
import 'http_client.dart';

/// API Repository for all API calls
class ApiRepository {
  final HttpClient _httpClient;
  final Logger _logger;

  ApiRepository({required HttpClient httpClient, Logger? logger})
    : _httpClient = httpClient,
      _logger = logger ?? Logger();

  // ──────────────────────────────────────────────────────────────────────
  // AUTHENTICATION ENDPOINTS
  // ──────────────────────────────────────────────────────────────────────

  /// Login user
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _httpClient.post(
        AppConstants.authLoginEndpoint,
        data: request.toJson(),
      );
      return AuthResponse.fromJson(response);
    } catch (e) {
      _logger.e('Login error', error: e);
      rethrow;
    }
  }

  /// Register user
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _httpClient.post(
        AppConstants.authRegisterEndpoint,
        data: request.toJson(),
      );
      return AuthResponse.fromJson(response);
    } catch (e) {
      _logger.e('Register error', error: e);
      rethrow;
    }
  }

  /// Refresh token
  /// REMOVED: Sanctum tokens do NOT auto-refresh
  /// Solution: Use validateToken() and redirect to login if invalid

  /// Logout user
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _httpClient.post(AppConstants.authLogoutEndpoint);
      return response;
    } catch (e) {
      _logger.e('Logout error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // PASSENGER ENDPOINTS - PUBLIC BUS
  // ──────────────────────────────────────────────────────────────────────

  /// Create public bus trip request
  Future<TripResponseDto> createPublicBusTrip(TripRequestDto request) async {
    try {
      final response = await _httpClient.post(
        AppConstants.passengerPublicBusRequestEndpoint,
        data: request.toJson(),
      );
      return TripResponseDto.fromJson(response);
    } catch (e) {
      _logger.e('Create public bus trip error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // PASSENGER ENDPOINTS - MOTORCYCLE
  // ──────────────────────────────────────────────────────────────────────

  /// Create motorcycle trip request
  Future<TripResponseDto> createMotorcycleTrip(TripRequestDto request) async {
    try {
      final response = await _httpClient.post(
        AppConstants.passengerMotorVehicleRequestEndpoint,
        data: request.toJson(),
      );
      return TripResponseDto.fromJson(response);
    } catch (e) {
      _logger.e('Create motorcycle trip error', error: e);
      rethrow;
    }
  }

  /// Cancel motorcycle trip - POST method
  Future<Map<String, dynamic>> cancelMotorcycleTrip(
    int tripId,
    String reason,
  ) async {
    try {
      final request = TripActionRequest(reason: reason);
      final endpoint = AppConstants.passengerCancelMotorVehicleTripEndpoint
          .replaceFirst('{id}', tripId.toString());
      final response = await _httpClient.post(
        endpoint,
        data: request.toJson(),
      ); // POST, not PUT
      return response;
    } catch (e) {
      _logger.e('Cancel motorcycle trip error', error: e);
      rethrow;
    }
  }

  /// Get passenger trips
  Future<List<TripDetails>> getPassengerTrips({
    int page = 1,
    int perPage = AppConstants.pageSize,
  }) async {
    try {
      final response = await _httpClient.get(
        AppConstants.passengerTripsEndpoint,
        queryParameters: {'page': page, 'per_page': perPage},
      );

      if (response is List) {
        return response.map((trip) => TripDetails.fromJson(trip)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Get passenger trips error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // DRIVER ENDPOINTS
  // ──────────────────────────────────────────────────────────────────────

  /// Accept trip
  Future<TripStatusResponse> acceptTrip(int tripId) async {
    try {
      final endpoint = AppConstants.driverAcceptTripEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.post(endpoint);
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Accept trip error', error: e);
      rethrow;
    }
  }

  /// Reject trip
  Future<TripStatusResponse> rejectTrip(int tripId, {String? reason}) async {
    try {
      final request = TripActionRequest(reason: reason);
      final endpoint = AppConstants.driverRejectTripEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.post(endpoint, data: request.toJson());
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Reject trip error', error: e);
      rethrow;
    }
  }

  /// Driver arrived at pickup
  Future<TripStatusResponse> driverArrived(int tripId) async {
    try {
      final endpoint = AppConstants.driverArrivedEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.post(endpoint);
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Driver arrived error', error: e);
      rethrow;
    }
  }

  /// Start trip - PUT method (private car)
  Future<TripStatusResponse> startTrip(int tripId) async {
    try {
      final endpoint = AppConstants.driverStartTripEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.put(endpoint); // PUT, not POST
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Start trip error', error: e);
      rethrow;
    }
  }

  /// Complete trip - PUT method (private car)
  Future<TripStatusResponse> completeTrip(int tripId) async {
    try {
      final endpoint = AppConstants.driverCompleteTripEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.put(endpoint); // PUT, not POST
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Complete trip error', error: e);
      rethrow;
    }
  }

  /// Update driver location
  Future<Map<String, dynamic>> updateDriverLocation(
    int tripId,
    double latitude,
    double longitude,
  ) async {
    try {
      final request = DriverLocationUpdateRequest(
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
      );
      final response = await _httpClient.post(
        AppConstants.driverLocationUpdateEndpoint,
        data: request.toJson(),
      );
      return response;
    } catch (e) {
      _logger.e('Update driver location error', error: e);
      rethrow;
    }
  }

  /// Update driver availability (status: ONLINE/OFFLINE)
  /// Uses POST to /mobile/drivers/status with { "status": "ONLINE" | "OFFLINE" }
  Future<Map<String, dynamic>> updateDriverAvailability(
    bool isAvailable,
  ) async {
    try {
      final request = DriverAvailabilityRequest(isAvailable: isAvailable);
      final response = await _httpClient.post(
        // POST, not PUT
        AppConstants.driverStatusEndpoint,
        data: request.toJson(),
      );
      return response;
    } catch (e) {
      _logger.e('Update driver availability error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // TRIP STATUS ENDPOINTS
  // ──────────────────────────────────────────────────────────────────────

  /// Get trip status
  Future<TripStatusResponse> getTripStatus(int tripId) async {
    try {
      final endpoint = AppConstants.getTripStatusEndpoint.replaceFirst(
        '{id}',
        tripId.toString(),
      );
      final response = await _httpClient.get(endpoint);
      return TripStatusResponse.fromJson(response);
    } catch (e) {
      _logger.e('Get trip status error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // ROUTE ENDPOINTS
  // ──────────────────────────────────────────────────────────────────────

  /// Get route between two points
  Future<RouteModel> getRoute({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    try {
      final response = await _httpClient.post(
        AppConstants.getRouteEndpoint,
        data: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
        },
      );
      return RouteModel.fromJson(response);
    } catch (e) {
      _logger.e('Get route error', error: e);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ──────────────────────────────────────────────────────────────────────

  /// Set authorization token
  void setAuthToken(String token) {
    _httpClient.setToken(token);
  }

  /// Clear authorization token
  void clearAuthToken() {
    _httpClient.clearToken();
  }
}
