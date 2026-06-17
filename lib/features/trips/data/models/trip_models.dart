import 'package:json_annotation/json_annotation.dart';

part 'trip_models.g.dart';

// ==================== REQUEST MODELS ====================

@JsonSerializable()
class CreateTripRequest {
  @JsonKey(name: 'origin_lat')
  final double originLat;

  @JsonKey(name: 'origin_lng')
  final double originLng;

  @JsonKey(name: 'origin_address')
  final String originAddress;

  @JsonKey(name: 'destination_lat')
  final double destinationLat;

  @JsonKey(name: 'destination_lng')
  final double destinationLng;

  @JsonKey(name: 'destination_address')
  final String destinationAddress;

  @JsonKey(name: 'transport_type')
  final String transportType; // PRIVATE_CAR, MOTORCYCLE, PUBLIC_BUS

  @JsonKey(name: 'estimated_fare')
  final int estimatedFare;

  @JsonKey(name: 'passenger_id')
  final int? passengerId;

  CreateTripRequest({
    required this.originLat,
    required this.originLng,
    required this.originAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.transportType,
    required this.estimatedFare,
    this.passengerId,
  });

  factory CreateTripRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateTripRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateTripRequestToJson(this);

  /// Convert to API request format for trip creation
  Map<String, dynamic> toApiRequest(String vehicleType) {
    return {
      'pickup_location': originAddress,
      'pickup_lat': originLat,
      'pickup_lng': originLng,
      'dropoff_location': destinationAddress,
      'dropoff_lat': destinationLat,
      'dropoff_lng': destinationLng,
      'vehicle_type': vehicleType,
    };
  }
}

@JsonSerializable()
class RouteComputeRequest {
  @JsonKey(name: 'origin_lat')
  final double originLat;

  @JsonKey(name: 'origin_lng')
  final double originLng;

  @JsonKey(name: 'destination_lat')
  final double destinationLat;

  @JsonKey(name: 'destination_lng')
  final double destinationLng;

  @JsonKey(name: 'transport_type')
  final String transportType;

  RouteComputeRequest({
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.transportType,
  });

  factory RouteComputeRequest.fromJson(Map<String, dynamic> json) =>
      _$RouteComputeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RouteComputeRequestToJson(this);
}

@JsonSerializable()
class RatingRequest {
  @JsonKey(name: 'rating')
  final int rating; // 1-5

  @JsonKey(name: 'review')
  final String? review;

  @JsonKey(name: 'tip')
  final int? tip;

  RatingRequest({required this.rating, this.review, this.tip});

  factory RatingRequest.fromJson(Map<String, dynamic> json) =>
      _$RatingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RatingRequestToJson(this);
}

// ==================== RESPONSE MODELS ====================

@JsonSerializable()
class RouteComputeResponse {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'data')
  final RouteData? data;

  @JsonKey(name: 'message')
  final String? message;

  RouteComputeResponse({required this.success, this.data, this.message});

  factory RouteComputeResponse.fromJson(Map<String, dynamic> json) =>
      _$RouteComputeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RouteComputeResponseToJson(this);
}

@JsonSerializable()
class RouteData {
  @JsonKey(name: 'distance')
  final double distance; // in km

  @JsonKey(name: 'duration')
  final int duration; // in seconds

  @JsonKey(name: 'estimated_fare')
  final int estimatedFare;

  @JsonKey(name: 'polyline')
  final String? polyline; // Google Maps polyline

  @JsonKey(name: 'waypoints')
  final List<WayPoint>? waypoints;

  RouteData({
    required this.distance,
    required this.duration,
    required this.estimatedFare,
    this.polyline,
    this.waypoints,
  });

  // Convenience getters
  int get durationInMinutes => (duration / 60).ceil();

  factory RouteData.fromJson(Map<String, dynamic> json) =>
      _$RouteDataFromJson(json);

  Map<String, dynamic> toJson() => _$RouteDataToJson(this);
}

@JsonSerializable()
class WayPoint {
  @JsonKey(name: 'lat')
  final double lat;

  @JsonKey(name: 'lng')
  final double lng;

  WayPoint({required this.lat, required this.lng});

  factory WayPoint.fromJson(Map<String, dynamic> json) =>
      _$WayPointFromJson(json);

  Map<String, dynamic> toJson() => _$WayPointToJson(this);
}

@JsonSerializable()
class CreateTripResponse {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'data')
  final TripData? data;

  @JsonKey(name: 'message')
  final String? message;

  @JsonKey(name: 'errors')
  final Map<String, List<String>>? errors;

  CreateTripResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
  });

  factory CreateTripResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateTripResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateTripResponseToJson(this);

  /// Check if this is a current active trip response
  bool get hasActiveTrip => success && data != null && data!.isActive;

  /// Get trip ID if available
  int? get tripId => data?.tripId;
}

/// Extension to check trip status
extension TripDataExtension on TripData {
  bool get isActive {
    return status == 'REQUESTED' ||
           status == 'MATCHING' ||
           status == 'ASSIGNING' ||
           status == 'ASSIGNED' ||
           status == 'ACCEPTED' ||
           status == 'STARTED' ||
           status == 'ARRIVED';
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isFailed => status == 'FAILED';
}

@JsonSerializable()
class TripData {
  @JsonKey(name: 'trip_id')
  final int tripId;

  @JsonKey(name: 'passenger_id')
  final int passengerId;

  @JsonKey(name: 'driver_id')
  final int? driverId;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'origin_lat')
  final double originLat;

  @JsonKey(name: 'origin_lng')
  final double originLng;

  @JsonKey(name: 'origin_address')
  final String originAddress;

  @JsonKey(name: 'destination_lat')
  final double destinationLat;

  @JsonKey(name: 'destination_lng')
  final double destinationLng;

  @JsonKey(name: 'destination_address')
  final String destinationAddress;

  @JsonKey(name: 'transport_type')
  final String transportType;

  @JsonKey(name: 'estimated_fare')
  final int estimatedFare;

  @JsonKey(name: 'actual_fare')
  final int? actualFare;

  @JsonKey(name: 'distance')
  final double? distance;

  @JsonKey(name: 'duration')
  final int? duration;

  @JsonKey(name: 'created_at')
  final String createdAt;

  @JsonKey(name: 'updated_at')
  final String updatedAt;

  @JsonKey(name: 'completed_at')
  final String? completedAt;

  @JsonKey(name: 'driver')
  final DriverData? driver;

  TripData({
    required this.tripId,
    required this.passengerId,
    this.driverId,
    required this.status,
    required this.originLat,
    required this.originLng,
    required this.originAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.transportType,
    required this.estimatedFare,
    this.actualFare,
    this.distance,
    this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.driver,
  });

  factory TripData.fromJson(Map<String, dynamic> json) =>
      _$TripDataFromJson(json);

  Map<String, dynamic> toJson() => _$TripDataToJson(this);
}

@JsonSerializable()
class DriverData {
  @JsonKey(name: 'driver_id')
  final int driverId;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'phone')
  final String phone;

  @JsonKey(name: 'rating')
  final double rating;

  @JsonKey(name: 'avatar')
  final String? avatar;

  @JsonKey(name: 'vehicle_model')
  final String? vehicleModel;

  @JsonKey(name: 'vehicle_plate')
  final String? vehiclePlate;

  DriverData({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.rating,
    this.avatar,
    this.vehicleModel,
    this.vehiclePlate,
  });

  factory DriverData.fromJson(Map<String, dynamic> json) =>
      _$DriverDataFromJson(json);

  Map<String, dynamic> toJson() => _$DriverDataToJson(this);
}

// ==================== LIST RESPONSE ====================

@JsonSerializable()
class TripsListResponse {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'data')
  final List<TripData>? data;

  @JsonKey(name: 'message')
  final String? message;

  TripsListResponse({required this.success, this.data, this.message});

  factory TripsListResponse.fromJson(Map<String, dynamic> json) =>
      _$TripsListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TripsListResponseToJson(this);
}
