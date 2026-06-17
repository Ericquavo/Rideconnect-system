// File: lib/services/trip_service.dart
// Production Trip Service with proper error handling and URL configuration
// Last Updated: May 29, 2026

import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../exceptions/trip_exceptions.dart';
import '../utils/validation_helper.dart';

class TripResponse {
  final int? tripId;
  final String? tripState;
  final int? driverId;
  final String? acceptedAt;
  final String? pickupLocation;
  final String? dropoffLocation;
  final double? fare;

  TripResponse({
    this.tripId,
    this.tripState,
    this.driverId,
    this.acceptedAt,
    this.pickupLocation,
    this.dropoffLocation,
    this.fare,
  });

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return TripResponse(
      tripId: data?['id'] ?? data?['trip_id'],
      tripState: data?['status'] ?? data?['trip_state'],
      driverId: data?['driver_id'],
      acceptedAt: data?['accepted_at'],
      pickupLocation: data?['pickup_location'],
      dropoffLocation: data?['dropoff_location'],
      fare: (data?['fare'] ?? 0.0).toDouble(),
    );
  }
}

class TripErrorResponse {
  final String type;
  final String message;
  final String code;
  final String? currentStatus;
  final int? assignedDriverId;
  final int httpCode;

  TripErrorResponse({
    required this.type,
    required this.message,
    required this.code,
    this.currentStatus,
    this.assignedDriverId,
    required this.httpCode,
  });

  factory TripErrorResponse.fromJson(Map<String, dynamic> json) {
    return TripErrorResponse(
      type: json['type'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? 'An unexpected error occurred',
      code: json['code'] ?? 'ERROR',
      currentStatus: json['current_status'],
      assignedDriverId: json['assigned_driver_id'],
      httpCode: json['http_code'] ?? 500,
    );
  }

  String get userFriendlyMessage {
    switch (type) {
      case 'TRIP_NOT_FOUND':
        return 'Trip not found. It may have been cancelled.';
      case 'TRIP_NOT_AVAILABLE':
        return 'This trip is no longer available. Current status: $currentStatus.';
      case 'TRIP_ALREADY_ASSIGNED':
        return 'Another driver already accepted this trip.';
      case 'TRIP_RACE_CONDITION':
        return 'Another driver just accepted this trip. Please try another one.';
      case 'TRIP_CANNOT_BE_REJECTED':
        return 'Cannot reject this trip. Status: $currentStatus.';
      case 'DRIVER_NOT_FOUND':
        return 'Driver profile not found. Please complete registration.';
      case 'POLICY_VIOLATION':
        return message;
      default:
        return message;
    }
  }
}

class TripService {
  final Dio dio;

  TripService({required this.dio});

  /// Accept a trip request - with trip ID validation
  Future<TripResponse> acceptTrip(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.post(
        ApiEndpoints.driverAccept(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return TripResponse.fromJson(response.data);
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException(
          'Trip $validTripId not found or was cancelled',
        );
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get trip details - with trip ID validation
  Future<TripResponse> getTripDetails(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.get(
        ApiEndpoints.tripDetail(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return TripResponse.fromJson(response.data);
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Start a trip - with trip ID validation
  Future<TripResponse> startTrip(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.put(
        ApiEndpoints.driverStart(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return TripResponse.fromJson(response.data);
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Complete a trip - with trip ID validation
  Future<TripResponse> completeTrip(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.put(
        ApiEndpoints.driverComplete(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return TripResponse.fromJson(response.data);
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel a trip - with trip ID validation
  Future<void> cancelTrip(
    int tripId, {
    String reason = 'User cancelled',
  }) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.put(
        ApiEndpoints.cancelTrip(validTripId),
        data: {'reason': reason},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get trip status - with trip ID validation
  Future<Map<String, dynamic>> getTripStatus(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.get(
        ApiEndpoints.tripStatus(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data'] ?? response.data;
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Track trip driver location - with trip ID validation
  Future<Map<String, dynamic>> trackTrip(int tripId) async {
    final validTripId = ValidationHelper.assertValidTripId(tripId);

    try {
      final response = await dio.get(
        ApiEndpoints.trackTrip(validTripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data'] ?? response.data;
      }

      if (response.statusCode == 404) {
        throw TripNotFoundException('Trip $validTripId not found');
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Request a new trip
  Future<TripResponse> requestTrip({
    required double pickupLat,
    required double pickupLng,
    required String pickupLocation,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffLocation,
    String? transportType,
    double? fare,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.requestTrip,
        data: {
          'pickup_location': pickupLocation,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_location': dropoffLocation,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          if (transportType != null) 'transport_type': transportType,
          if (fare != null) 'fare': fare,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TripResponse.fromJson(response.data);
      }

      throw _handleErrorResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Handle error responses
  TripException _handleErrorResponse(Response response) {
    final statusCode = response.statusCode ?? 500;

    try {
      final errorData = response.data as Map<String, dynamic>?;
      final errorResponse = TripErrorResponse.fromJson(errorData ?? {});
      return TripException(
        errorResponse.userFriendlyMessage,
        code: errorResponse.code,
        httpStatusCode: statusCode,
      );
    } catch (e) {
      return TripException(
        'Request failed with status code: $statusCode',
        code: 'HTTP_ERROR',
        httpStatusCode: statusCode,
      );
    }
  }
}
