// lib/models/trip_model.dart
// Trip model matching trips DB table exactly

class TripModel {
  final int id;
  final int passengerId;
  final int? driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String? pickupZone;
  final String? dropoffZone;
  final String? pickupPlaceName;
  final String? dropoffPlaceName;
  final double fare;
  final double? actualFare;
  final double? actualDistance;
  final String status;
  final String paymentStatus;
  final String assignmentStatus;
  final String? transportType;
  final String? matchingSessionId;
  final String? idempotencyKey;
  final int rejectedDriversCount;
  final double? rankerScore;
  final String? rankerVersion;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TripModel({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.pickupZone,
    this.dropoffZone,
    this.pickupPlaceName,
    this.dropoffPlaceName,
    required this.fare,
    this.actualFare,
    this.actualDistance,
    required this.status,
    required this.paymentStatus,
    required this.assignmentStatus,
    this.transportType,
    this.matchingSessionId,
    this.idempotencyKey,
    required this.rejectedDriversCount,
    this.rankerScore,
    this.rankerVersion,
    this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  static double _parseDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory TripModel.fromJson(Map<String, dynamic> j) => TripModel(
    id: j['id'] as int,
    passengerId: j['passenger_id'] as int,
    driverId: j['driver_id'] as int?,
    pickupLocation: j['pickup_location'] as String,
    dropoffLocation: j['dropoff_location'] as String,
    pickupLat: _parseDouble(j['pickup_lat']),
    pickupLng: _parseDouble(j['pickup_lng']),
    dropoffLat: _parseDouble(j['dropoff_lat']),
    dropoffLng: _parseDouble(j['dropoff_lng']),
    pickupZone: j['pickup_zone'] as String?,
    dropoffZone: j['dropoff_zone'] as String?,
    pickupPlaceName: j['pickup_place_name'] as String?,
    dropoffPlaceName: j['dropoff_place_name'] as String?,
    fare: _parseDouble(j['fare']),
    actualFare:
        j['actual_fare'] != null ? _parseDouble(j['actual_fare']) : null,
    actualDistance:
        j['actual_distance'] != null
            ? _parseDouble(j['actual_distance'])
            : null,
    status: j['status'] as String,
    paymentStatus: j['payment_status'] as String? ?? 'unpaid',
    assignmentStatus: j['assignment_status'] as String? ?? 'unassigned',
    transportType: j['transport_type'] as String?,
    matchingSessionId: j['matching_session_id'] as String?,
    idempotencyKey: j['idempotency_key'] as String?,
    rejectedDriversCount: j['rejected_drivers_count'] as int? ?? 0,
    rankerScore:
        j['ranker_score'] != null ? _parseDouble(j['ranker_score']) : null,
    rankerVersion: j['ranker_version'] as String?,
    requestedAt: _parseDate(j['requested_at']),
    acceptedAt: _parseDate(j['accepted_at']),
    startedAt: _parseDate(j['started_at']),
    completedAt: _parseDate(j['completed_at']),
    rejectedAt: _parseDate(j['rejected_at']),
    rejectionReason: j['rejection_reason'] as String?,
    createdAt: _parseDate(j['created_at']),
    updatedAt: _parseDate(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'passenger_id': passengerId,
    'driver_id': driverId,
    'pickup_location': pickupLocation,
    'dropoff_location': dropoffLocation,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'fare': fare,
    'status': status,
    'payment_status': paymentStatus,
    'assignment_status': assignmentStatus,
    'transport_type': transportType,
    'rejected_drivers_count': rejectedDriversCount,
  };

  TripModel copyWith({
    String? status,
    String? paymentStatus,
    String? assignmentStatus,
    int? driverId,
    String? transportType,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? actualFare,
    double? actualDistance,
  }) => TripModel(
    id: id,
    passengerId: passengerId,
    driverId: driverId ?? this.driverId,
    pickupLocation: pickupLocation,
    dropoffLocation: dropoffLocation,
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    dropoffLat: dropoffLat,
    dropoffLng: dropoffLng,
    pickupZone: pickupZone,
    dropoffZone: dropoffZone,
    pickupPlaceName: pickupPlaceName,
    dropoffPlaceName: dropoffPlaceName,
    fare: fare,
    actualFare: actualFare ?? this.actualFare,
    actualDistance: actualDistance ?? this.actualDistance,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    assignmentStatus: assignmentStatus ?? this.assignmentStatus,
    transportType: transportType ?? this.transportType,
    matchingSessionId: matchingSessionId,
    idempotencyKey: idempotencyKey,
    rejectedDriversCount: rejectedDriversCount,
    rankerScore: rankerScore,
    rankerVersion: rankerVersion,
    requestedAt: requestedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    rejectedAt: rejectedAt,
    rejectionReason: rejectionReason,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  // ── Computed helpers ────────────────────────────────────────────────

  bool get isActive => [
    'requested',
    'assigning',
    'accepted',
    'enroute_to_pickup',
    'arrived_at_pickup',
    'in_progress',
  ].contains(status);

  bool get canCancel => ['requested', 'assigning'].contains(status);

  bool get isCompleted => status == 'completed';
}

// ──────────────────────────────────────────────────────────────────────
// DTO MODELS FOR API COMMUNICATION
// ──────────────────────────────────────────────────────────────────────

/// Trip request DTO for creating a new trip
class TripRequestDto {
  final String pickupLocation;
  final String dropoffLocation;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String transportType;
  final String? pickupName;
  final String? dropoffName;
  final String? pickupAddress;
  final String? dropoffAddress;

  TripRequestDto({
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.transportType,
    this.pickupName,
    this.dropoffName,
    this.pickupAddress,
    this.dropoffAddress,
  });

  Map<String, dynamic> toJson() => {
    'pickup_location': pickupLocation,
    'dropoff_location': dropoffLocation,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'pickup_name': pickupName ?? pickupLocation,
    'pickup_address': pickupAddress ?? pickupLocation,
    'dropoff_name': dropoffName ?? dropoffLocation,
    'dropoff_address': dropoffAddress ?? dropoffLocation,
    'transport_type': transportType,
  };
}

/// Trip response from server
class TripResponseDto {
  final bool success;
  final int tripId;
  final String status;
  final String message;
  final TripDetails? tripDetails;

  TripResponseDto({
    required this.success,
    required this.tripId,
    required this.status,
    required this.message,
    this.tripDetails,
  });

  factory TripResponseDto.fromJson(Map<String, dynamic> json) =>
      TripResponseDto(
        success: json['success'] as bool,
        tripId: json['trip_id'] as int,
        status: json['status'] as String,
        message: json['message'] as String? ?? '',
        tripDetails:
            json['trip'] != null ? TripDetails.fromJson(json['trip']) : null,
      );
}

/// Trip details model
class TripDetails {
  final int id;
  final int passengerId;
  final int? driverId;
  final String status;
  final String transportType;
  final String pickupLocation;
  final String dropoffLocation;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double? fare;
  final double? estimatedDuration;
  final double? distance;
  final String? polyline;
  final int? availableSeats;
  final DriverInfo? driver;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  TripDetails({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.status,
    required this.transportType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.fare,
    this.estimatedDuration,
    this.distance,
    this.polyline,
    this.availableSeats,
    this.driver,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory TripDetails.fromJson(Map<String, dynamic> json) => TripDetails(
    id: json['id'] as int,
    passengerId: json['passenger_id'] as int,
    driverId: json['driver_id'] as int?,
    status: json['status'] as String,
    transportType: json['transport_type'] as String? ?? '',
    pickupLocation: json['pickup_location'] as String,
    dropoffLocation: json['dropoff_location'] as String,
    pickupLat: double.tryParse(json['pickup_lat'].toString()) ?? 0.0,
    pickupLng: double.tryParse(json['pickup_lng'].toString()) ?? 0.0,
    dropoffLat: double.tryParse(json['dropoff_lat'].toString()) ?? 0.0,
    dropoffLng: double.tryParse(json['dropoff_lng'].toString()) ?? 0.0,
    fare:
        json['fare'] != null ? double.tryParse(json['fare'].toString()) : null,
    estimatedDuration:
        json['estimated_duration'] != null
            ? double.tryParse(json['estimated_duration'].toString())
            : null,
    distance:
        json['distance'] != null
            ? double.tryParse(json['distance'].toString())
            : null,
    polyline: json['polyline'] as String?,
    availableSeats: json['available_seats'] as int?,
    driver: json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null,
    createdAt:
        json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
    startedAt:
        json['started_at'] != null
            ? DateTime.tryParse(json['started_at'].toString())
            : null,
    completedAt:
        json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())
            : null,
    cancelledAt:
        json['cancelled_at'] != null
            ? DateTime.tryParse(json['cancelled_at'].toString())
            : null,
  );

  TripDetails copyWith({
    int? id,
    int? passengerId,
    int? driverId,
    String? status,
    String? transportType,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    double? fare,
    double? estimatedDuration,
    double? distance,
    String? polyline,
    int? availableSeats,
    DriverInfo? driver,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return TripDetails(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      transportType: transportType ?? this.transportType,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      fare: fare ?? this.fare,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      distance: distance ?? this.distance,
      polyline: polyline ?? this.polyline,
      availableSeats: availableSeats ?? this.availableSeats,
      driver: driver ?? this.driver,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}

/// Driver information model
class DriverInfo {
  final int id;
  final String name;
  final String? profilePictureUrl;
  final double? rating;
  final String? vehicleType;
  final String? vehiclePlate;
  final String? vehicleColor;
  final double? currentLat;
  final double? currentLng;
  final int? minutesAway;

  DriverInfo({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.rating,
    this.vehicleType,
    this.vehiclePlate,
    this.vehicleColor,
    this.currentLat,
    this.currentLng,
    this.minutesAway,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) => DriverInfo(
    id: json['id'] as int,
    name: json['name'] as String,
    profilePictureUrl: json['profile_picture_url'] as String?,
    rating:
        json['rating'] != null
            ? double.tryParse(json['rating'].toString())
            : null,
    vehicleType: json['vehicle_type'] as String?,
    vehiclePlate: json['vehicle_plate'] as String?,
    vehicleColor: json['vehicle_color'] as String?,
    currentLat:
        json['current_lat'] != null
            ? double.tryParse(json['current_lat'].toString())
            : null,
    currentLng:
        json['current_lng'] != null
            ? double.tryParse(json['current_lng'].toString())
            : null,
    minutesAway: json['minutes_away'] as int?,
  );
}

/// Trip action request model
class TripActionRequest {
  final String? reason;

  TripActionRequest({this.reason});

  Map<String, dynamic> toJson() => {if (reason != null) 'reason': reason};
}

/// Trip status response model
class TripStatusResponse {
  final bool success;
  final String status;
  final String? matchingStatus;
  final TripDetails? tripDetails;
  final String? message;

  TripStatusResponse({
    required this.success,
    required this.status,
    this.matchingStatus,
    this.tripDetails,
    this.message,
  });

  factory TripStatusResponse.fromJson(Map<String, dynamic> json) =>
      TripStatusResponse(
        success: json['success'] as bool,
        status: json['status'] as String,
        matchingStatus: json['matching_status'] as String?,
        tripDetails:
            json['trip'] != null ? TripDetails.fromJson(json['trip']) : null,
        message: json['message'] as String?,
      );
}

/// Route model for navigation
class RouteModel {
  final String polyline;
  final int distanceMeters;
  final String duration;
  final List<TripLatLng>? points;

  RouteModel({
    required this.polyline,
    required this.distanceMeters,
    required this.duration,
    this.points,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
    polyline: json['polyline'] as String,
    distanceMeters: json['distance_meters'] as int,
    duration: json['duration'] as String,
    points:
        (json['points'] as List?)?.map((p) => TripLatLng.fromJson(p)).toList(),
  );
}

/// Latitude/Longitude model defined for route data
class TripLatLng {
  final double latitude;
  final double longitude;

  TripLatLng({required this.latitude, required this.longitude});

  factory TripLatLng.fromJson(Map<String, dynamic> json) => TripLatLng(
    latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
    longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

extension TripModelDisplay on TripModel {
  String get fareDisplay => 'RWF ${fare.toStringAsFixed(0)}';

  String get actualFareDisplay =>
      actualFare != null
          ? 'RWF ${actualFare!.toStringAsFixed(0)}'
          : fareDisplay;

  String get statusLabel {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'requested':
        return 'Searching for driver...';
      case 'assigning':
        return 'Matching you with a driver...';
      case 'accepted':
        return 'Driver accepted! On the way';
      case 'enroute_to_pickup':
      case 'enroute':
      case 'on_the_way':
        return 'Driver is coming to you';
      case 'arrived_at_pickup':
      case 'arrived':
        return 'Driver has arrived — please come out';
      case 'in_progress':
      case 'started':
        return 'Trip in progress';
      case 'completed':
        return 'Trip completed ✓';
      case 'cancelled':
        return 'Trip cancelled';
      default:
        return status;
    }
  }

  String get transportIcon {
    switch (transportType?.toLowerCase()) {
      case 'moto':
      case 'motorcycle':
        return '🏍️';
      case 'car':
      case 'private':
        return '🚗';
      case 'bus':
      case 'public_bus':
        return '🚌';
      default:
        return '🚗';
    }
  }
}
