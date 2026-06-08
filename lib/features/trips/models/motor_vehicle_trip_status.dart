/// UI-facing lifecycle phases for motor vehicle matching.
enum TripLifecyclePhase {
  requestReceived,
  fareCalculated,
  searchingCandidates,
  driversFound,
  contactingDrivers,
  driverAccepted,
  driverArriving,
  driverArrived,
  tripStarted,
  tripCompleted,
  noDriversFound,
  cancelled,
  matchTimeout,
  unknown,
}

extension TripLifecyclePhaseX on TripLifecyclePhase {
  bool get isTerminal =>
      this == TripLifecyclePhase.tripCompleted ||
      this == TripLifecyclePhase.noDriversFound ||
      this == TripLifecyclePhase.cancelled ||
      this == TripLifecyclePhase.matchTimeout;
}

class TripDriver {
  const TripDriver({
    this.id,
    this.name,
    this.phone,
    this.rating,
    this.vehiclePlate,
    this.photoUrl,
    this.lat,
    this.lng,
  });

  final int? id;
  final String? name;
  final String? phone;
  final double? rating;
  final String? vehiclePlate;
  final String? photoUrl;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  factory TripDriver.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    return TripDriver(
      id: json['id'] as int?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      rating: _toDouble(json['rating']),
      vehiclePlate: json['vehicle_plate'] as String?,
      photoUrl: json['photo_url'] as String?,
      lat: loc is Map ? _toDouble(loc['lat']) : null,
      lng: loc is Map ? _toDouble(loc['lng']) : null,
    );
  }
}

/// Parsed `data` object from GET /passenger/motor-vehicle/trip-requests/{id}.
class MotorVehicleTripStatus {
  const MotorVehicleTripStatus({
    required this.tripId,
    required this.status,
    required this.matchingStatus,
    required this.phase,
    this.driver,
    this.estimatedFare,
    this.actualFare,
    this.currency,
    this.retryCount,
    this.maxRetries,
    this.driversFound = 0,
    this.searchRadiusKm,
    this.etaMinutes,
    this.vehicleDescription,
    this.driverPhotoUrl,
    this.raw = const {},
  });

  final int tripId;
  final String status;
  final String? matchingStatus;
  final TripLifecyclePhase phase;
  final TripDriver? driver;
  final num? estimatedFare;
  final num? actualFare;
  final String? currency;
  final int? retryCount;
  final int? maxRetries;
  final int driversFound;
  final double? searchRadiusKm;
  final int? etaMinutes;
  final String? vehicleDescription;
  final String? driverPhotoUrl;
  final Map<String, dynamic> raw;

  factory MotorVehicleTripStatus.fromJson(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    final matching = data['matching_status']?.toString();
    final driverJson = data['driver'] ?? data['assigned_driver'] ?? data['driver_info'];
    return MotorVehicleTripStatus(
      tripId: (data['trip_id'] as num?)?.toInt() ??
          (data['id'] as num?)?.toInt() ??
          0,
      status: status,
      matchingStatus: matching,
      phase: mapPhase(status, matching),
      driver: driverJson is Map<String, dynamic>
          ? TripDriver.fromJson(driverJson)
          : null,
      estimatedFare: data['estimated_fare'] as num?,
      actualFare: data['actual_fare'] as num?,
      currency: data['currency'] as String?,
      retryCount: (data['retry_count'] as num?)?.toInt(),
      maxRetries: (data['max_retries'] as num?)?.toInt(),
      driversFound: _readInt(data, const [
        'drivers_found',
        'candidates',
        'driver_count',
        'matched_drivers',
      ]) ?? 0,
      searchRadiusKm: _readDouble(data, const [
        'search_radius',
        'radius',
        'matching_radius',
      ]),
      etaMinutes: _readInt(data, const [
        'eta_minutes',
        'eta',
        'estimated_arrival',
      ]),
      vehicleDescription: _readString(data, const [
        'vehicle_description',
        'vehicle',
        'bike',
      ]),
      driverPhotoUrl: _readString(data, const ['driver_photo_url', 'photo_url']),
      raw: data,
    );
  }

  static TripLifecyclePhase mapPhase(String status, String? matchingStatus) {
    switch (status) {
      case 'REQUESTED':
      case 'MATCHING':
      case 'MATCHING_PENDING':
        switch (matchingStatus) {
          case 'DRIVER_FOUND':
            return TripLifecyclePhase.driversFound;
          case 'FAILED_MAX_RETRIES':
            return TripLifecyclePhase.noDriversFound;
          case 'SEARCHING':
          case 'RETRY_SCHEDULED':
          case 'RETRYING':
          default:
            return TripLifecyclePhase.searchingCandidates;
        }
      case 'ASSIGNED':
      case 'DRIVER_ASSIGNED':
        return TripLifecyclePhase.driverAccepted;
      case 'PASSENGER_WAITING':
      case 'DRIVER_ARRIVED':
        return TripLifecyclePhase.driverArrived;
      case 'IN_PROGRESS':
        return TripLifecyclePhase.tripStarted;
      case 'COMPLETED':
        return TripLifecyclePhase.tripCompleted;
      case 'REJECTED_BY_DRIVER':
        return matchingStatus == 'FAILED_MAX_RETRIES'
            ? TripLifecyclePhase.noDriversFound
            : TripLifecyclePhase.searchingCandidates;
      case 'CANCELLED_BY_PASSENGER':
      case 'CANCELLED_BY_DRIVER':
        return TripLifecyclePhase.cancelled;
      case 'EXPIRED':
        return TripLifecyclePhase.matchTimeout;
      default:
        return TripLifecyclePhase.unknown;
    }
  }
}

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
  }
  return null;
}

double? _readDouble(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
  }
  return null;
}

String? _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
