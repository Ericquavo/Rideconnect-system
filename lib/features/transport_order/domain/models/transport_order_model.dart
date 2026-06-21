class Location {
  final double latitude;
  final double longitude;
  final String? address;

  Location({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    };
  }
}

class TransportOrder {
  final String id;
  final String status;
  final String transportType;
  final Location pickup;
  final Location dropoff;
  final double fare;
  final String? assignedDriverId;

  TransportOrder({
    required this.id,
    required this.status,
    required this.transportType,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    this.assignedDriverId,
  });

  factory TransportOrder.fromJson(Map<String, dynamic> json) {
    return TransportOrder(
      id: json['id'] as String,
      status: json['status'] as String,
      transportType: json['transportType'] as String,
      pickup: Location.fromJson(json['pickup'] as Map<String, dynamic>),
      dropoff: Location.fromJson(json['dropoff'] as Map<String, dynamic>),
      fare: (json['fare'] ?? 0.0).toDouble(),
      assignedDriverId: json['assignedDriverId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'transportType': transportType,
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'fare': fare,
      if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
    };
  }

  TransportOrder copyWith({
    String? id,
    String? status,
    String? transportType,
    Location? pickup,
    Location? dropoff,
    double? fare,
    String? assignedDriverId,
  }) {
    return TransportOrder(
      id: id ?? this.id,
      status: status ?? this.status,
      transportType: transportType ?? this.transportType,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      fare: fare ?? this.fare,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
    );
  }
}
