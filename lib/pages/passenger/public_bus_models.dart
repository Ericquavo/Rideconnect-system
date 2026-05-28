import 'package:google_maps_flutter/google_maps_flutter.dart';

class PublicBusAssignment {
  PublicBusAssignment({
    required this.assignmentId,
    required this.busId,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    required this.driverAvailabilityStatus,
    required this.busDisplayName,
    required this.busPhotoUrl,
    required this.availableSeats,
    required this.etaMinutes,
    required this.nextStopName,
    required this.routeProgressPercent,
    required this.latestPosition,
    required this.location,
    required this.score,
    required this.demandIndex,
  });

  final int assignmentId;
  final int busId;
  final int? driverId;
  final String driverName;
  final double? driverRating;
  final String? driverAvailabilityStatus;
  final String? busDisplayName;
  final String? busPhotoUrl;
  final int? availableSeats;
  final int? etaMinutes;
  final String? nextStopName;
  final int? routeProgressPercent;
  final LatLng? latestPosition;
  final LatLng? location;
  final double? score;
  final double? demandIndex;

  factory PublicBusAssignment.fromJson(Map<String, dynamic> json) {
    final driver =
        json['driver'] is Map<String, dynamic>
            ? json['driver'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final bus =
        json['bus'] is Map<String, dynamic>
            ? json['bus'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final latestPosition = json['latest_position'];
    final location = json['location'];
    final nextStop =
        json['next_stop'] is Map<String, dynamic>
            ? json['next_stop'] as Map<String, dynamic>
            : const <String, dynamic>{};

    return PublicBusAssignment(
      assignmentId: _readInt(json, <String>['assignment_id']) ?? 0,
      busId: _readInt(json, <String>['bus_id']) ?? 0,
      driverId: _readInt(driver, <String>['id']),
      driverName: _readString(driver, <String>['name']) ?? 'Driver',
      driverRating: _readDouble(driver, <String>['rating']),
      driverAvailabilityStatus: _readString(driver, <String>[
        'availability_status',
      ]),
      busDisplayName: _readString(bus, <String>['display_name']),
      busPhotoUrl: _readString(bus, <String>['photo_url']),
      availableSeats: _readInt(json, <String>['available_seats']),
      etaMinutes:
          _readInt(json, <String>['eta_minutes']) ??
          _readInt(
            latestPosition is Map<String, dynamic>
                ? latestPosition
                : const <String, dynamic>{},
            <String>['eta_minutes'],
          ),
      nextStopName: _readString(nextStop, <String>['stop_name']),
      routeProgressPercent: _readInt(
        latestPosition is Map<String, dynamic>
            ? latestPosition
            : const <String, dynamic>{},
        <String>['route_progress_percent'],
      ),
      latestPosition: _readLatLng(
        latestPosition is Map<String, dynamic> ? latestPosition : null,
      ),
      location: _readLatLng(location is Map<String, dynamic> ? location : null),
      score: _readDouble(json, <String>['score']),
      demandIndex: _readDouble(json, <String>['demand_index']),
    );
  }

  LatLng? get mapPoint => latestPosition ?? location;

  String get title =>
      (busDisplayName != null && busDisplayName!.trim().isNotEmpty)
          ? busDisplayName!.trim()
          : 'Bus #$busId';

  String get driverSummary {
    final rating = driverRating;
    if (rating != null && rating > 0) {
      return '$driverName · ${rating.toStringAsFixed(1)}★';
    }
    return driverName;
  }

  String get footerSummary {
    if (nextStopName != null && nextStopName!.trim().isNotEmpty) {
      return nextStopName!.trim();
    }
    final progress = routeProgressPercent;
    if (progress != null) {
      return '$progress% route progress';
    }
    return 'Route active';
  }

  String get etaLabel => etaMinutes?.toString() ?? '—';
}

class PublicBusBookingRequest {
  PublicBusBookingRequest({
    required this.corridorId,
    required this.boardingStopId,
    required this.destinationStopId,
    required this.seatsReserved,
    this.busRouteAssignmentId,
  });

  final int corridorId;
  final int boardingStopId;
  final int destinationStopId;
  final int seatsReserved;
  final int? busRouteAssignmentId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'corridor_id': corridorId,
    'boarding_stop_id': boardingStopId,
    'destination_stop_id': destinationStopId,
    'seats_reserved': seatsReserved,
    if (busRouteAssignmentId != null)
      'bus_route_assignment_id': busRouteAssignmentId,
  };
}

String publicBusErrorMessage(String? errorCode) {
  switch (errorCode) {
    case 'BUS_SELECTION_INVALID':
      return 'Selected bus is no longer available. Please select another bus.';
    case 'INSUFFICIENT_BUS_CAPACITY':
      return 'Selected bus doesn\'t have enough seats. Select a different bus or reduce seats.';
    case 'NO_BOOKABLE_BUS':
      return 'No available buses currently. Try again later.';
    case 'PASSENGER_NOT_APPROVED':
      return 'Your account must be approved to book a bus seat.';
    case 'PASSENGER_ONLY':
      return 'Only passengers can book bus seats.';
    case 'BUS_BOOKING_FORBIDDEN':
      return 'You are not allowed to book a bus seat.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

String publicBusErrorTitle(String? errorCode) {
  switch (errorCode) {
    case 'PASSENGER_NOT_APPROVED':
      return 'Account approval required';
    case 'PASSENGER_ONLY':
    case 'BUS_BOOKING_FORBIDDEN':
      return 'Bus booking unavailable';
    case 'BUS_SELECTION_INVALID':
    case 'INSUFFICIENT_BUS_CAPACITY':
    case 'NO_BOOKABLE_BUS':
      return 'Choose another bus';
    default:
      return 'Unable to book seat';
  }
}

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _readDouble(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
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

LatLng? _readLatLng(Map<String, dynamic>? source) {
  if (source == null) return null;
  final latitude = _readDouble(source, <String>['latitude', 'lat']);
  final longitude = _readDouble(source, <String>['longitude', 'lng', 'lon']);
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}
