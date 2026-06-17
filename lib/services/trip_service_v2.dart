// File: lib/services/trip_service_v2.dart
// V2 Trip Service with production-grade error handling
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../config/dio_config.dart';
import '../exceptions/trip_exceptions.dart';
import '../models/trip_model.dart';
import '../utils/validation_helper.dart';

class TripServiceV2 {
  final Dio _dio;

  TripServiceV2({String? authToken, Dio? dio})
    : _dio = dio ?? DioConfig.createDioClient(authToken: authToken);

  /// Create a new trip request
  /// Returns TripModel on success
  Future<TripModel> createTrip({
    required int passengerId,
    required String pickupLocation,
    required double pickupLat,
    required double pickupLng,
    required String dropoffLocation,
    required double dropoffLat,
    required double dropoffLng,
    required String transportType,
    required String paymentMethod,
    required String idempotencyKey,
    String? pickupZone,
    String? dropoffZone,
    String? pickupPlaceName,
    String? dropoffPlaceName,
  }) async {
    try {
      if (!ValidationHelper.isValidLocation(pickupLat, pickupLng) ||
          !ValidationHelper.isValidLocation(dropoffLat, dropoffLng)) {
        throw ArgumentError('Invalid pickup or dropoff coordinates.');
      }

      final payload = {
        'passenger_id': passengerId,
        'pickup_location': pickupLocation,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_location': dropoffLocation,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'transport_type': transportType.toLowerCase(),
        'payment_method': paymentMethod.toLowerCase(),
        'idempotency_key': idempotencyKey,
        'pickup_zone': pickupZone,
        'dropoff_zone': dropoffZone,
        'pickup_place_name': pickupPlaceName,
        'dropoff_place_name': dropoffPlaceName,
      };

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.requestTrip),
        data: payload,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return TripModel.fromJson(data);
      }

      throw TripException('Failed to create trip: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get trip details by ID
  Future<TripModel> getTripDetails(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.get(
        ApiConfig.getUrl(ApiEndpoints.tripDetail(tripId)),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return TripModel.fromJson(data);
      }

      throw TripException('Failed to fetch trip details');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get current active trip for the user (trip recovery)
  Future<TripModel?> getCurrentTrip() async {
    try {
      final response = await _dio.get(
        ApiConfig.getUrl(ApiEndpoints.currentTrip),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data == null) return null;
        return TripModel.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleDioException(e);
    }
  }

  /// Accept a trip (driver action)
  Future<Map<String, dynamic>> acceptTrip(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.driverAccept(tripId)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripAlreadyAssignedException(
        'Trip already assigned or not available',
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Reject a trip (driver action)
  Future<Map<String, dynamic>> rejectTrip({
    required int tripId,
    required String reason,
  }) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.driverReject(tripId)),
        data: {'reason': reason},
      );

      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to reject trip');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Generic respond to trip method
  Future<Map<String, dynamic>> respondToTrip({
    required int tripId,
    required String action,
    String? reason,
  }) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final payload = {
        'action': action.toLowerCase(),
        if (reason != null) 'reason': reason,
      };

      final endpoint =
          action == 'accept'
              ? ApiConfig.getUrl(ApiEndpoints.driverAccept(tripId))
              : ApiConfig.getUrl(ApiEndpoints.driverReject(tripId));
      final response = await _dio.post(endpoint, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to respond to trip');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update trip status (driver action during active trip)
  Future<Map<String, dynamic>> updateTripStatus({
    required int tripId,
    required String status,
  }) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.put(
        ApiConfig.getUrl(ApiEndpoints.tripStatus(tripId)),
        data: {'status': status.toLowerCase()},
      );

      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to update trip status');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update driver location during active trip
  Future<Map<String, dynamic>> updateDriverLocation({
    required int tripId,
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? heading,
    double? accuracy,
  }) async {
    try {
      ValidationHelper.assertValidTripId(tripId);
      if (!ValidationHelper.isValidLocation(latitude, longitude)) {
        throw ArgumentError('Invalid driver location coordinates.');
      }

      final payload = {
        'latitude': latitude,
        'longitude': longitude,
        'speed_kmh': speedKmh ?? 0.0,
        'heading': heading ?? 0.0,
        'accuracy': accuracy ?? 0.0,
      };

      final response = await _dio.post(
        ApiConfig.getUrl('/mobile/drivers/live-location'),
        data: payload,
      );

      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to update driver location');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Cancel trip (passenger action)
  Future<Map<String, dynamic>> cancelTrip(int tripId, {String? reason}) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final payload = {if (reason != null) 'reason': reason};

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.cancelTrip(tripId)),
        data: payload,
      );

      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to cancel trip');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Driver arrived at pickup
  Future<Map<String, dynamic>> arriveTrip(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.driverArrived(tripId)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to mark trip as arrived');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Start trip (driver action)
  Future<Map<String, dynamic>> startTrip(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.driverStart(tripId)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to start trip');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Complete trip (driver action - marks trip as completed)
  Future<Map<String, dynamic>> completeTrip(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.driverComplete(tripId)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }

      throw TripException('Failed to complete trip');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Acknowledge a trip status transition
  Future<void> acknowledgeTripStatus(int tripId, String ackType) async {
    try {
      await _dio.post(
        ApiConfig.getUrl(ApiEndpoints.tripAcknowledge(tripId)),
        data: {
          'acknowledgement_type': ackType,
          'source': 'flutter'
        }
      );
    } catch (_) {
      // Best effort
    }
  }

  /// Get trip status
  Future<String> getTripStatus(int tripId) async {
    try {
      ValidationHelper.assertValidTripId(tripId);

      final response = await _dio.get(
        ApiConfig.getUrl(ApiEndpoints.tripStatus(tripId)),
      );

      if (response.statusCode == 200) {
        return response.data['data']['status'] as String;
      }

      throw TripException('Failed to get trip status');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Handle Dio exceptions with proper typing
  TripException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TripException('Request timeout: ${error.message}');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final data = error.response?.data as Map<String, dynamic>?;
        return _handleHttpError(statusCode, data);

      case DioExceptionType.cancel:
        return TripException('Request cancelled');

      default:
        return TripException('Network error: ${error.message}');
    }
  }

  /// Handle HTTP-specific errors
  TripException _handleHttpError(int statusCode, Map<String, dynamic>? data) {
    final message = data?['message'] as String? ?? 'Unknown error';

    switch (statusCode) {
      case 400:
        return TripException(message);
      case 404:
        return TripNotFoundException('Trip not found');
      case 409:
        return TripAlreadyAssignedException(message);
      case 422:
        return TripNotAvailableException(message);
      case 401:
        return UnauthorizedTripException(message);
      default:
        return TripException('Error ($statusCode): $message');
    }
  }
}
