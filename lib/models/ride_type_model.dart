/// Models for Private Transport (CAR & MOTORCYCLE)
library;

// ─────────────────────────────────────────────────────────────────────────────
//  Ride Type & Rules Models
// ─────────────────────────────────────────────────────────────────────────────

/// Ride rules determine what flow is allowed for this ride
class RideRules {
  final bool canBook; // Can create booking (SCHEDULED rides)
  final bool canRequestTrip; // Can request direct trip (ON_DEMAND rides)
  final String allowedFlow; // BOOKING_ONLY | TRIP_ONLY | BOTH | NONE

  RideRules({
    required this.canBook,
    required this.canRequestTrip,
    required this.allowedFlow,
  });

  factory RideRules.fromJson(Map<String, dynamic> json) {
    return RideRules(
      canBook: json['can_book'] ?? false,
      canRequestTrip: json['can_request_trip'] ?? false,
      allowedFlow: json['allowed_flow'] ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() => {
    'can_book': canBook,
    'can_request_trip': canRequestTrip,
    'allowed_flow': allowedFlow,
  };
}

/// Driver information
class DriverInfo {
  final int? id;
  final String name;
  final double rating;
  final String? phone;
  final int trips;

  DriverInfo({
    this.id,
    required this.name,
    required this.rating,
    this.phone,
    required this.trips,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      rating: _toDouble(json['rating']) ?? 4.5,
      phone: json['phone'],
      trips: json['trips'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'rating': rating,
    if (phone != null) 'phone': phone,
    'trips': trips,
  };
}

/// Vehicle information
class VehicleInfo {
  final String make;
  final String model;
  final String color;
  final String? licensePlate;
  final int? year;

  VehicleInfo({
    required this.make,
    required this.model,
    required this.color,
    this.licensePlate,
    this.year,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      make: json['make'] ?? 'Unknown',
      model: json['model'] ?? 'Model',
      color: json['color'] ?? 'White',
      licensePlate: json['license_plate'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() => {
    'make': make,
    'model': model,
    'color': color,
    if (licensePlate != null) 'license_plate': licensePlate,
    if (year != null) 'year': year,
  };
}

/// Location information
class LocationInfo {
  final String address;
  final double lat;
  final double lng;

  LocationInfo({required this.address, required this.lat, required this.lng});

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      address: json['address'] ?? 'Unknown Location',
      lat: _toDouble(json['lat']) ?? 0.0,
      lng: _toDouble(json['lng']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'address': address, 'lat': lat, 'lng': lng};
}

/// Main Ride model - represents available ride from API
class Ride {
  final int id;
  final String transportType; // CAR, MOTORCYCLE, BUS
  final String travelMode; // SCHEDULED, ON_DEMAND
  final LocationInfo origin;
  final LocationInfo destination;
  final DriverInfo? driver;
  final VehicleInfo? vehicle;
  final double? pricePerSeat;
  final String currency;
  final RideRules rideRules;
  final int? availableSeats;
  final String? estimatedTime;

  Ride({
    required this.id,
    required this.transportType,
    required this.travelMode,
    required this.origin,
    required this.destination,
    this.driver,
    this.vehicle,
    this.pricePerSeat,
    required this.currency,
    required this.rideRules,
    this.availableSeats,
    this.estimatedTime,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] ?? 0,
      transportType: json['transport_type'] ?? 'CAR',
      travelMode: json['travel_mode'] ?? 'ON_DEMAND',
      origin: LocationInfo.fromJson(json['origin'] ?? {}),
      destination: LocationInfo.fromJson(json['destination'] ?? {}),
      driver:
          json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null,
      vehicle:
          json['vehicle'] != null
              ? VehicleInfo.fromJson(json['vehicle'])
              : null,
      pricePerSeat: _toDouble(json['price_per_seat']),
      currency: json['currency'] ?? 'RWF',
      rideRules: RideRules.fromJson(json['ride_rules'] ?? {}),
      availableSeats: json['available_seats'],
      estimatedTime: json['estimated_time'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transport_type': transportType,
    'travel_mode': travelMode,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    if (driver != null) 'driver': driver!.toJson(),
    if (vehicle != null) 'vehicle': vehicle!.toJson(),
    if (pricePerSeat != null) 'price_per_seat': pricePerSeat,
    'currency': currency,
    'ride_rules': rideRules.toJson(),
    if (availableSeats != null) 'available_seats': availableSeats,
    if (estimatedTime != null) 'estimated_time': estimatedTime,
  };

  /// Convenience getter - is this a motorcycle ride?
  bool get isMotorcycle => transportType == 'MOTORCYCLE';

  /// Convenience getter - is this a car?
  bool get isCar => transportType == 'CAR';

  /// Convenience getter - is on-demand?
  bool get isOnDemand => travelMode == 'ON_DEMAND';

  /// Convenience getter - is scheduled?
  bool get isScheduled => travelMode == 'SCHEDULED';
}

/// Helper function to safely convert to double
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
