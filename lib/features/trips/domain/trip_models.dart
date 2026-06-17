import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TripStatus {
  requested,
  matched,
  driverConfirmed,
  driverArriving,
  pickedUp,
  inProgress,
  completed,
  cancelled,
  disputed,
}

extension TripStatusX on TripStatus {
  String get apiValue {
    switch (this) {
      case TripStatus.requested:
        return 'REQUESTED';
      case TripStatus.matched:
        return 'MATCHED';
      case TripStatus.driverConfirmed:
        return 'DRIVER_CONFIRMED';
      case TripStatus.driverArriving:
        return 'DRIVER_ARRIVING';
      case TripStatus.pickedUp:
        return 'PICKED_UP';
      case TripStatus.inProgress:
        return 'IN_PROGRESS';
      case TripStatus.completed:
        return 'COMPLETED';
      case TripStatus.cancelled:
        return 'CANCELLED';
      case TripStatus.disputed:
        return 'DISPUTED';
    }
  }

  String get label => apiValue
      .toLowerCase()
      .split('_')
      .map(
        (part) =>
            part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  bool get isTerminal =>
      this == TripStatus.completed ||
      this == TripStatus.cancelled ||
      this == TripStatus.disputed;

  static TripStatus parse(dynamic value) {
    final raw = (value ?? '').toString().trim().toUpperCase();
    if (raw == 'PASSENGER_WAITING' ||
        raw.contains('ACCEPT') ||
        raw.contains('CONFIRM')) {
      return TripStatus.driverConfirmed;
    }
    if (raw == 'DRIVER_ASSIGNED' || raw == 'ASSIGNED') {
      return TripStatus.matched;
    }
    if (raw == 'DRIVER_ARRIVED' || raw == 'ARRIVED') {
      return TripStatus.pickedUp;
    }
    if (raw.contains('MATCH')) {
      return TripStatus.matched;
    }
    if (raw.contains('ARRIV')) {
      return TripStatus.driverArriving;
    }
    if (raw.contains('PICK')) {
      return TripStatus.pickedUp;
    }
    if (raw.contains('PROGRESS') || raw == 'STARTED') {
      return TripStatus.inProgress;
    }
    if (raw.contains('COMPLETE') || raw == 'FINISHED') {
      return TripStatus.completed;
    }
    if (raw.contains('CANCEL') || raw.contains('REJECT')) {
      return TripStatus.cancelled;
    }
    if (raw.contains('DISPUT')) {
      return TripStatus.disputed;
    }
    return TripStatus.requested;
  }
}

class TripLocation {
  const TripLocation({required this.label, this.lat, this.lng});

  final String label;
  final double? lat;
  final double? lng;

  LatLng? get latLng => lat == null || lng == null ? null : LatLng(lat!, lng!);

  /// Convert to JSON with field name mapping for API compatibility.
  /// Includes both legacy and current payload keys for backend compatibility.
  Map<String, dynamic> toJson(String prefix) => {
    '${prefix}_name': label,
    '${prefix}_location': label,
    if (lat != null) '${prefix}_lat': lat,
    if (lng != null) '${prefix}_lng': lng,
    if (lat != null && lng != null) prefix: {'lat': lat, 'lng': lng},
  };

  factory TripLocation.fromJson(Map<String, dynamic> json, String prefix) {
    final nested = json[prefix];
    final map =
        nested is Map<String, dynamic> ? nested : const <String, dynamic>{};
    return TripLocation(
      label:
          _readString(json, [
            '${prefix}_name', // Check 'pickup_name' / 'dropoff_name' first
            '${prefix}_location',
            '${prefix}_address',
            prefix,
            prefix == 'dropoff' ? 'destination' : 'from',
          ]) ??
          _readString(map, ['address', 'name']) ??
          '--',
      lat:
          _readDouble(json, ['${prefix}_lat', 'lat']) ??
          _readDouble(map, ['lat', 'latitude']),
      lng:
          _readDouble(json, ['${prefix}_lng', 'lng']) ??
          _readDouble(map, ['lng', 'longitude']),
    );
  }
}

class TripRequest {
  TripRequest({
    required this.pickup,
    required this.destination,
    required this.vehicleType,
    required this.seatCount,
    required this.tripType,
    required this.scheduleMode,
    required this.paymentMethod,
    this.departureTime,
    this.notes,
    this.driverId,
    this.matchingSessionId,
    this.estimatedFare,
  });

  final TripLocation pickup;
  final TripLocation destination;
  final String vehicleType;
  final int seatCount;
  final String tripType;
  final String scheduleMode;
  final String paymentMethod;
  final DateTime? departureTime;
  final String? notes;
  final int? driverId;
  final String? matchingSessionId;
  final double? estimatedFare;

  TripRequest copyWith({
    TripLocation? pickup,
    TripLocation? destination,
    String? vehicleType,
    int? seatCount,
    String? tripType,
    String? scheduleMode,
    String? paymentMethod,
    DateTime? departureTime,
    String? notes,
    int? driverId,
    String? matchingSessionId,
    double? estimatedFare,
  }) {
    return TripRequest(
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      vehicleType: vehicleType ?? this.vehicleType,
      seatCount: seatCount ?? this.seatCount,
      tripType: tripType ?? this.tripType,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      departureTime: departureTime ?? this.departureTime,
      notes: notes ?? this.notes,
      driverId: driverId ?? this.driverId,
      matchingSessionId: matchingSessionId ?? this.matchingSessionId,
      estimatedFare: estimatedFare ?? this.estimatedFare,
    );
  }

  Map<String, dynamic> toJson() => {
    ...pickup.toJson('pickup'),
    ...destination.toJson('dropoff'),
    'vehicle_type': vehicleType,
    'transport_type': vehicleType,
    'seats': seatCount,
    'seat_count': seatCount,
    'trip_type': tripType,
    'schedule_mode': scheduleMode,
    'payment_method': paymentMethod,
    if (departureTime != null)
      'departure_time': departureTime!.toIso8601String(),
    if (departureTime != null) 'scheduled_at': departureTime!.toIso8601String(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    if (driverId != null) 'driver_id': driverId,
    if (matchingSessionId != null) 'matching_session_id': matchingSessionId,
    if (estimatedFare != null) 'fare': estimatedFare,
  };
}

class Trip {
  Trip({
    required this.id,
    required this.status,
    required this.pickup,
    required this.destination,
    this.driver,
    this.vehicle,
    this.fare = 0,
    this.etaText = '',
    this.paymentStatus = '',
    this.createdAt,
  });

  final int id;
  final TripStatus status;
  final TripLocation pickup;
  final TripLocation destination;
  final TripDriver? driver;
  final TripVehicle? vehicle;
  final double fare;
  final String etaText;
  final String paymentStatus;
  final DateTime? createdAt;

  bool get isActive => !status.isTerminal;

  Map<String, dynamic> toJson() => {
    'trip_id': id,
    'status': status.apiValue,
    'pickup_location': pickup.label,
    'dropoff_location': destination.label,
    'fare': fare,
    // Add more fields as needed for UI
  };
  factory Trip.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'];
    final vehicle = json['vehicle'];
    return Trip(
      id: _readInt(json, ['id', 'trip_id']) ?? 0,
      status: TripStatusX.parse(json['status'] ?? json['trip_status']),
      pickup: TripLocation.fromJson(json, 'pickup'),
      destination: TripLocation.fromJson(json, 'dropoff'),
      driver: driver is Map<String, dynamic> ? TripDriver.fromJson(driver) : null,
      vehicle: vehicle is Map<String, dynamic> ? TripVehicle.fromJson(vehicle) : null,
      fare: _readDouble(json, ['fare', 'actual_fare', 'price', 'amount']) ?? 0,
      etaText: _readString(json, ['eta', 'eta_text', 'duration']) ?? '',
      paymentStatus: _readString(json, ['payment_status']) ?? '',
      createdAt: DateTime.tryParse(_readString(json, ['created_at', 'requested_at']) ?? ''),
    );
  }
}

class TripDriver {
  TripDriver({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.phone = '',
    this.rating = 0,
  });

  final int id;
  final String name;
  final String photoUrl;
  final String phone;
  final double rating;

  factory TripDriver.fromJson(Map<String, dynamic> json) => TripDriver(
    id: _readInt(json, ['id', 'driver_id', 'user_id']) ?? 0,
    name: _readString(json, ['name', 'driver_name', 'full_name']) ?? 'Driver',
    photoUrl:
        _readString(json, ['photo_url', 'avatar', 'profile_photo_url']) ?? '',
    phone: _readString(json, ['phone', 'phone_number']) ?? '',
    rating: _readDouble(json, ['rating', 'avg_rating']) ?? 0,
  );
}

class TripVehicle {
  TripVehicle({
    this.model = '',
    this.plateNumber = '',
    this.color = '',
    this.type = '',
  });

  final String model;
  final String plateNumber;
  final String color;
  final String type;

  factory TripVehicle.fromJson(Map<String, dynamic> json) => TripVehicle(
    model: _readString(json, ['model', 'vehicle_model', 'name']) ?? '',
    plateNumber:
        _readString(json, ['plate_number', 'registration_number', 'plate']) ??
        '',
    color: _readString(json, ['color']) ?? '',
    type: _readString(json, ['type', 'vehicle_type']) ?? '',
  );
}

class TripTracking {
  TripTracking({
    required this.trip,
    this.driverLocation,
    this.route = const <LatLng>[],
    this.etaText = '',
  });

  final Trip trip;
  final LatLng? driverLocation;
  final List<LatLng> route;
  final String etaText;

  factory TripTracking.fromJson(Map<String, dynamic> json) {
    final tripMap =
        json['trip'] is Map<String, dynamic>
            ? json['trip'] as Map<String, dynamic>
            : json;
    final driverLocation = json['driver_location'];
    final driverMap =
        driverLocation is Map<String, dynamic>
            ? driverLocation
            : const <String, dynamic>{};
    final routeRaw = json['route'] ?? json['route_path'] ?? json['polyline'];
    final route = <LatLng>[];
    if (routeRaw is List) {
      for (final item in routeRaw.whereType<Map<String, dynamic>>()) {
        final lat = _readDouble(item, ['lat', 'latitude']);
        final lng = _readDouble(item, ['lng', 'longitude']);
        if (lat != null && lng != null) route.add(LatLng(lat, lng));
      }
    }
    final lat = _readDouble(driverMap, ['lat', 'latitude']);
    final lng = _readDouble(driverMap, ['lng', 'longitude']);
    return TripTracking(
      trip: Trip.fromJson(tripMap),
      driverLocation: lat == null || lng == null ? null : LatLng(lat, lng),
      route: route,
      etaText: _readString(json, ['eta', 'eta_text', 'duration']) ?? '',
    );
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
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
  }
  return null;
}

String? _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
