// ignore_for_file: avoid_dynamic_calls

/// Helpers — all numeric parsers accept both num and String to
/// survive backends that serialize numbers as JSON strings.
String _addr(Map<String, dynamic> nested, dynamic raw) {
  if (nested.isNotEmpty) {
    return (nested['address'] ?? nested['name'] ?? '').toString();
  }
  if (raw is String && raw.isNotEmpty) return raw;
  return '';
}

int _parseInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? _parseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double _parseDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

// Keep _asInt as an alias used by external callers if needed
// ignore: unused_element
int? _asInt(dynamic v) => _parseIntOrNull(v);

DateTime? _tryDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

// ─────────────────────────────────────────────────────────────────────────────

/// A single ride that is available to book.
class RideSummary {
  RideSummary({
    required this.id,
    required this.originAddress,
    required this.destinationAddress,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.status,
    this.rideType = '',
  });

  final int id;
  final String originAddress;
  final String destinationAddress;
  final DateTime? departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final String status;

  /// Extracted from `type` / `ride_type` / `name` on the backend response.
  final String rideType;

  factory RideSummary.fromJson(Map<String, dynamic> json) {
    final origin = (json['origin'] as Map<String, dynamic>?) ?? {};
    final destination = (json['destination'] as Map<String, dynamic>?) ?? {};
    final pickupFallback =
        (json['pickup_address'] ?? json['pickup_location'] ?? '').toString();
    final dropoffFallback =
        (json['dropoff_address'] ?? json['dropoff_location'] ?? '').toString();
    return RideSummary(
      id: _parseInt(json['id'] ?? json['ride_id'] ?? json['trip_id']),
      originAddress:
          _addr(origin, json['origin']).isNotEmpty
              ? _addr(origin, json['origin'])
              : pickupFallback,
      destinationAddress:
          _addr(destination, json['destination']).isNotEmpty
              ? _addr(destination, json['destination'])
              : dropoffFallback,
      departureTime: _tryDate(
        json['departure_time'] ??
            json['scheduled_at'] ??
            json['trip_date'] ??
            json['date'],
      ),
      availableSeats: _parseInt(
        json['available_seats'] ?? json['seats_available'] ?? json['seats'],
      ),
      pricePerSeat: _parseDouble(
        json['price_per_seat'] ?? json['fare'] ?? json['amount'],
      ),
      status: (json['status'] ?? '').toString(),
      rideType:
          (json['type'] ?? json['ride_type'] ?? json['name'] ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A booking item returned from the passenger's history or active rides list.
class RideHistoryItem {
  RideHistoryItem({
    required this.id,
    required this.rideId,
    required this.origin,
    required this.destination,
    required this.seatsBooked,
    required this.totalPrice,
    required this.status,
    required this.bookedAt,
  });

  final int id;
  final int rideId;
  final String origin;
  final String destination;
  final int seatsBooked;
  final double totalPrice;
  final String status;
  final DateTime? bookedAt;

  factory RideHistoryItem.fromJson(Map<String, dynamic> json) {
    final ride = (json['ride'] as Map<String, dynamic>?) ?? {};
    final topOrigin =
        (json['pickup_location'] ?? json['pickup_address'] ?? json['from'])
            ?.toString();
    final topDestination =
        (json['dropoff_location'] ??
                json['dropoff_address'] ??
                json['destination'] ??
                json['to'])
            ?.toString();

    // origin / destination can be a Map<String,dynamic> or a plain String
    final originRaw = ride['origin'];
    final destRaw = ride['destination'];
    final String origin =
        originRaw is Map<String, dynamic>
            ? (originRaw['address'] ?? originRaw['name'] ?? '').toString()
            : (originRaw ??
                    ride['pickup_location'] ??
                    ride['pickup_address'] ??
                    topOrigin ??
                    '')
                .toString();
    final String destination =
        destRaw is Map<String, dynamic>
            ? (destRaw['address'] ?? destRaw['name'] ?? '').toString()
            : (destRaw ??
                    ride['dropoff_location'] ??
                    ride['dropoff_address'] ??
                    ride['to'] ??
                    topDestination ??
                    '')
                .toString();

    return RideHistoryItem(
      id: _parseInt(json['id']),
      rideId: _parseInt(ride['id'] ?? json['ride_id'] ?? json['trip_id']),
      origin: origin,
      destination: destination,
      seatsBooked: _parseInt(json['seats_booked'] ?? json['seats']),
      totalPrice: _parseDouble(json['total_price'] ?? json['fare']),
      status: (json['status'] ?? '').toString(),
      bookedAt: _tryDate(json['booked_at'] ?? json['created_at']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Full details for a single ride, returned by GET /passenger/rides/{id}.
class RideDetails {
  RideDetails({
    required this.id,
    required this.driverName,
    required this.originAddress,
    required this.destinationAddress,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.status,
    this.rideType = '',
    this.seats,
    this.paymentStatus,
    this.notes,
    this.requestedAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final String driverName;
  final String originAddress;
  final String destinationAddress;
  final DateTime? departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final String status;

  // Extended fields not in the minimal spec but present on the backend response
  final String rideType;
  final int? seats;
  final String? paymentStatus;
  final String? notes;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  factory RideDetails.fromJson(Map<String, dynamic> json) {
    final driver = (json['driver'] as Map<String, dynamic>?) ?? {};
    final origin = (json['origin'] as Map<String, dynamic>?) ?? {};
    final destination = (json['destination'] as Map<String, dynamic>?) ?? {};
    return RideDetails(
      id: _parseInt(json['id']),
      driverName: (driver['name'] ?? '').toString(),
      originAddress: _addr(origin, json['origin']),
      destinationAddress: _addr(destination, json['destination']),
      departureTime: _tryDate(json['departure_time']),
      availableSeats: _parseInt(json['available_seats']),
      pricePerSeat: _parseDouble(json['price_per_seat']),
      status: (json['status'] ?? '').toString(),
      rideType: (json['type'] ?? json['ride_type'] ?? '').toString(),
      seats: _parseIntOrNull(
        json['seats'] ?? json['seats_booked'] ?? json['seat_count'],
      ),
      paymentStatus:
          (json['payment_status'] ?? json['paymentStatus'])?.toString(),
      notes: (json['notes'] ?? json['message'])?.toString(),
      requestedAt: _tryDate(json['requested_at'] ?? json['created_at']),
      acceptedAt: _tryDate(json['accepted_at'] ?? json['started_at']),
      completedAt: _tryDate(json['completed_at'] ?? json['finished_at']),
      cancelledAt: _tryDate(json['cancelled_at']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Request body for POST /passenger/rides.
class CreateBookingRequest {
  CreateBookingRequest({
    required this.rideId,
    required this.seats,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.rideType,
    this.scheduledAt,
    this.notes,
  });

  final int rideId;
  final int seats;
  final String pickupAddress;
  final String dropoffAddress;
  final String? rideType;
  final DateTime? scheduledAt;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'ride_id': rideId,
    'seats': seats,
    'pickup_address': pickupAddress,
    'dropoff_address': dropoffAddress,
    if (rideType != null && rideType!.trim().isNotEmpty)
      'ride_type': rideType!.trim(),
    if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

/// Response body from POST /passenger/rides.
class CreateBookingResponse {
  CreateBookingResponse({
    required this.id,
    required this.rideId,
    required this.seats,
    required this.totalPrice,
    required this.status,
  });

  final int id;
  final int rideId;
  final int seats;
  final double totalPrice;
  final String status;

  factory CreateBookingResponse.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'];
    final trip = json['trip'];
    final ride = json['ride'];
    final bookingMap =
        booking is Map<String, dynamic> ? booking : const <String, dynamic>{};
    final tripMap =
        trip is Map<String, dynamic> ? trip : const <String, dynamic>{};
    final rideMap =
        ride is Map<String, dynamic> ? ride : const <String, dynamic>{};

    return CreateBookingResponse(
      id:
          _parseInt(json['id'] ?? json['booking_id'] ?? json['trip_id']) > 0
              ? _parseInt(json['id'] ?? json['booking_id'] ?? json['trip_id'])
              : _parseInt(
                bookingMap['id'] ??
                    bookingMap['booking_id'] ??
                    tripMap['id'] ??
                    rideMap['id'],
              ),
      rideId: _parseInt(
        json['ride_id'] ??
            json['trip_id'] ??
            bookingMap['ride_id'] ??
            bookingMap['trip_id'] ??
            tripMap['ride_id'] ??
            tripMap['id'] ??
            rideMap['id'],
      ),
      seats: _parseInt(
        json['seats'] ??
            json['seat_count'] ??
            bookingMap['seats'] ??
            tripMap['seats'],
      ),
      totalPrice: _parseDouble(
        json['total_price'] ??
            json['amount'] ??
            json['fare'] ??
            bookingMap['total_price'] ??
            bookingMap['amount'] ??
            tripMap['total_price'] ??
            tripMap['fare'],
      ),
      status:
          (json['status'] ??
                  bookingMap['status'] ??
                  tripMap['status'] ??
                  'pending')
              .toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Request body for POST /passenger/payments.
class CreatePaymentRequest {
  CreatePaymentRequest({
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    this.currency = 'RWF',
    this.reference,
    this.notes,
  });

  final int bookingId;
  final double amount;
  final String paymentMethod;
  final String currency;
  final String? reference;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'booking_id': bookingId,
    'amount': amount,
    'payment_method': paymentMethod,
    'currency': currency,
    if (reference != null && reference!.trim().isNotEmpty)
      'reference': reference!.trim(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

/// Response body from POST /passenger/payments.
class CreatePaymentResponse {
  CreatePaymentResponse({
    required this.id,
    required this.status,
    required this.amount,
    required this.reference,
  });

  final int id;
  final String status;
  final double amount;
  final String reference;

  factory CreatePaymentResponse.fromJson(Map<String, dynamic> json) {
    return CreatePaymentResponse(
      id: _parseInt(json['id'] ?? json['payment_id']),
      status: (json['status'] ?? json['payment_status'] ?? '').toString(),
      amount: _parseDouble(json['amount'] ?? json['paid_amount']),
      reference:
          (json['reference'] ??
                  json['transaction_id'] ??
                  json['payment_reference'] ??
                  '')
              .toString(),
    );
  }
}
