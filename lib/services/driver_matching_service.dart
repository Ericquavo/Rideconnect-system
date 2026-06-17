// File: lib/services/driver_matching_service.dart
// Production Driver Matching Service with empty response handling
// Last Updated: May 29, 2026

import 'package:dio/dio.dart';
import '../config/api_config.dart';

class AvailableDriver {
  final int id;
  final String name;
  final double rating;
  final String vehicleType;
  final double distance;
  final int eta; // minutes
  final String vehicleNumber;
  final String? vehicleColor;
  final String? licensePlate;

  AvailableDriver({
    required this.id,
    required this.name,
    required this.rating,
    required this.vehicleType,
    required this.distance,
    required this.eta,
    required this.vehicleNumber,
    this.vehicleColor,
    this.licensePlate,
  });

  factory AvailableDriver.fromJson(Map<String, dynamic> json) {
    return AvailableDriver(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Driver',
      rating: (json['rating'] ?? 0.0).toDouble(),
      vehicleType: json['vehicle_type'] ?? 'Unknown',
      distance: (json['distance'] ?? 0.0).toDouble(),
      eta: json['eta'] ?? 0,
      vehicleNumber: json['vehicle_number'] ?? '',
      vehicleColor: json['vehicle_color'],
      licensePlate: json['license_plate'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rating': rating,
    'vehicle_type': vehicleType,
    'distance': distance,
    'eta': eta,
    'vehicle_number': vehicleNumber,
    'vehicle_color': vehicleColor,
    'license_plate': licensePlate,
  };
}

class DriverMatchingResponse {
  final List<AvailableDriver> drivers;
  final String? matchingSessionId;
  final bool hasAvailableDrivers;
  final String? noDriversReason;
  final DateTime? expiresAt;

  DriverMatchingResponse({
    required this.drivers,
    this.matchingSessionId,
    required this.hasAvailableDrivers,
    this.noDriversReason,
    this.expiresAt,
  });

  factory DriverMatchingResponse.fromJson(Map<String, dynamic> json) {
    final drivers =
        (json['data'] as List?)
            ?.map((d) => AvailableDriver.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];

    return DriverMatchingResponse(
      drivers: drivers,
      matchingSessionId: json['matching_session_id'] as String?,
      hasAvailableDrivers: drivers.isNotEmpty,
      noDriversReason:
          drivers.isEmpty
              ? json['message'] ?? 'No drivers currently available in your area'
              : null,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'])
              : null,
    );
  }

  /// Check if response is effectively empty
  bool get isEmpty => drivers.isEmpty;

  /// Get appropriate message for empty response
  String getEmptyStateMessage() {
    if (isEmpty) {
      return noDriversReason ??
          'No drivers available at the moment. Please try again later.';
    }
    return '';
  }

  /// Check if session has expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class MatchingSessionResponse {
  final List<AvailableDriver> drivers;
  final bool isActive;
  final DateTime? expiresAt;

  MatchingSessionResponse({
    required this.drivers,
    required this.isActive,
    this.expiresAt,
  });

  factory MatchingSessionResponse.fromJson(Map<String, dynamic> json) {
    final drivers =
        (json['drivers'] as List?)
            ?.map((d) => AvailableDriver.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];

    return MatchingSessionResponse(
      drivers: drivers,
      isActive: json['is_active'] ?? false,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'])
              : null,
    );
  }

  bool get isEmpty => drivers.isEmpty;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class DriverMatchingService {
  final Dio dio;

  DriverMatchingService({required this.dio});

  /// Fetch available drivers for matching
  /// Gracefully handles empty driver list
  Future<DriverMatchingResponse> getAvailableDrivers({
    required double latitude,
    required double longitude,
    String? transportType,
    int maxResults = 10,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.availableDrivers,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          if (transportType != null) 'transport_type': transportType,
          'max_results': maxResults,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final matchingResponse = DriverMatchingResponse.fromJson(response.data);

        // Handle empty driver list gracefully
        if (matchingResponse.isEmpty) {
          return matchingResponse;
        }

        return matchingResponse;
      }

      if (response.statusCode == 404 || response.statusCode == 422) {
        // Return empty response instead of throwing error
        return DriverMatchingResponse(
          drivers: [],
          matchingSessionId: null,
          hasAvailableDrivers: false,
          noDriversReason: 'No drivers found in your area. Please try again.',
        );
      }

      // Handle server errors gracefully
      return DriverMatchingResponse(
        drivers: [],
        matchingSessionId: null,
        hasAvailableDrivers: false,
        noDriversReason:
            'Unable to load drivers. Status: ${response.statusCode}',
      );
    } catch (e) {
      // Return empty response on error instead of crashing
      return DriverMatchingResponse(
        drivers: [],
        matchingSessionId: null,
        hasAvailableDrivers: false,
        noDriversReason:
            'Unable to connect. Please check your internet and try again.',
      );
    }
  }

  /// Get matching session details
  /// Handles empty/null session gracefully
  Future<MatchingSessionResponse?> getMatchingSession(String sessionId) async {
    if (sessionId.isEmpty) {
      return null;
    }

    try {
      final tripId = int.tryParse(sessionId) ?? 0;
      final response = await dio.get(
        ApiEndpoints.matchingSession(tripId),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return MatchingSessionResponse.fromJson(
          response.data['data'] ?? response.data,
        );
      }

      if (response.statusCode == 404) {
        return null; // Session expired or not found
      }

      return null; // Return null on any error
    } catch (e) {
      return null; // Gracefully return null on exception
    }
  }

  /// Fetch drivers with retry logic for better reliability
  Future<DriverMatchingResponse> getAvailableDriversWithRetry({
    required double latitude,
    required double longitude,
    String? transportType,
    int maxResults = 10,
    int maxAttempts = 3,
  }) async {
    DriverMatchingResponse? lastResponse;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        lastResponse = await getAvailableDrivers(
          latitude: latitude,
          longitude: longitude,
          transportType: transportType,
          maxResults: maxResults,
        );

        // If we got drivers or a valid empty response, return it
        if (lastResponse.drivers.isNotEmpty || attempt == maxAttempts) {
          return lastResponse;
        }

        // Wait before retrying (exponential backoff)
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      } catch (e) {
        if (attempt == maxAttempts) {
          rethrow;
        }
        // Continue to next attempt
      }
    }

    return lastResponse ??
        DriverMatchingResponse(
          drivers: [],
          matchingSessionId: null,
          hasAvailableDrivers: false,
          noDriversReason: 'Unable to fetch drivers after multiple attempts',
        );
  }

  /// Filter drivers by rating
  List<AvailableDriver> filterByRating(
    List<AvailableDriver> drivers, {
    double minRating = 3.0,
  }) {
    return drivers.where((d) => d.rating >= minRating).toList();
  }

  /// Sort drivers by distance
  List<AvailableDriver> sortByDistance(List<AvailableDriver> drivers) {
    final sorted = [...drivers];
    sorted.sort((a, b) => a.distance.compareTo(b.distance));
    return sorted;
  }

  /// Sort drivers by ETA
  List<AvailableDriver> sortByEta(List<AvailableDriver> drivers) {
    final sorted = [...drivers];
    sorted.sort((a, b) => a.eta.compareTo(b.eta));
    return sorted;
  }

  /// Get best driver (closest with highest rating)
  AvailableDriver? getBestDriver(List<AvailableDriver> drivers) {
    if (drivers.isEmpty) return null;

    final sorted = [...drivers];
    sorted.sort((a, b) {
      // Primary: distance (closer is better)
      // Secondary: rating (higher is better)
      final distanceDiff = a.distance.compareTo(b.distance);
      if (distanceDiff != 0) return distanceDiff;
      return b.rating.compareTo(a.rating);
    });

    return sorted.first;
  }
}
