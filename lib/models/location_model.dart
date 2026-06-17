import 'dart:math' as math;

/// Location model for storing location data
class LocationModel {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'heading': heading,
    'speed': speed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
    longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
    accuracy:
        json['accuracy'] != null
            ? double.tryParse(json['accuracy'].toString())
            : null,
    altitude:
        json['altitude'] != null
            ? double.tryParse(json['altitude'].toString())
            : null,
    heading:
        json['heading'] != null
            ? double.tryParse(json['heading'].toString())
            : null,
    speed:
        json['speed'] != null
            ? double.tryParse(json['speed'].toString())
            : null,
    timestamp:
        DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now(),
  );

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? heading,
    double? speed,
    DateTime? timestamp,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Calculate distance between two locations in meters
  double distanceTo(LocationModel other) {
    const double earthRadius = 6371000; // meters

    final lat1 = latitude * 3.14159265359 / 180;
    final lat2 = other.latitude * 3.14159265359 / 180;
    final dLat = (other.latitude - latitude) * 3.14159265359 / 180;
    final dLng = (other.longitude - longitude) * 3.14159265359 / 180;

    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}

/// Driver location update request
class DriverLocationUpdateRequest {
  final int tripId;
  final double latitude;
  final double longitude;

  DriverLocationUpdateRequest({
    required this.tripId,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Driver availability update request
class DriverAvailabilityRequest {
  final bool isAvailable;

  DriverAvailabilityRequest({required this.isAvailable});

  Map<String, dynamic> toJson() => {'is_available': isAvailable};
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null ? fromJson(json['data']) : null,
      message: json['message'] as String?,
      error: json['error'] as String?,
      statusCode: json['status_code'] as int?,
    );
  }
}

/// Pagination model
class PaginationModel {
  final List<dynamic> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  PaginationModel({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) =>
      PaginationModel(
        data: json['data'] as List? ?? [],
        currentPage: json['current_page'] as int? ?? 1,
        lastPage: json['last_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 20,
        total: json['total'] as int? ?? 0,
      );
}

/// Error response model
class ErrorResponse {
  final String message;
  final int statusCode;
  final Map<String, List<String>>? validationErrors;
  final String? code;

  ErrorResponse({
    required this.message,
    required this.statusCode,
    this.validationErrors,
    this.code,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) => ErrorResponse(
    message: json['message'] as String? ?? 'Unknown error',
    statusCode: json['status_code'] as int? ?? 500,
    validationErrors: (json['errors'] as Map?)?.cast<String, List<String>>(),
    code: json['code'] as String?,
  );
}

/// Rating model
class RatingModel {
  final int tripId;
  final int rating;
  final String? comment;

  RatingModel({required this.tripId, required this.rating, this.comment});

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'rating': rating,
    'comment': comment,
  };
}
