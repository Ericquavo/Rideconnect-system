import 'package:flutter/foundation.dart';

/// Represents a matching session from the backend
/// Persists during driver selection and request confirmation
@immutable
class MatchingSession {
  final String matchingSessionId;
  final String transportType; // 'motor_vehicle' or 'private_car'
  final int responseVersion;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final List<DriverMatch> drivers;

  const MatchingSession({
    required this.matchingSessionId,
    required this.transportType,
    required this.responseVersion,
    required this.generatedAt,
    required this.expiresAt,
    required this.drivers,
  });

  /// Check if session is still valid
  bool get isValid {
    return DateTime.now().isBefore(expiresAt);
  }

  /// Check if session is expired
  bool get isExpired {
    return !isValid;
  }

  /// Time remaining in seconds
  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inSeconds > 0 ? diff.inSeconds : 0;
  }

  factory MatchingSession.fromJson(Map<String, dynamic> json) {
    try {
      final source = _dataMap(json);
      final drivers =
          (_readList(source, const [
                'drivers',
                'matched_drivers',
                'online_drivers',
                'items',
                'results',
              ]))
              ?.map((d) => DriverMatch.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [];
      final now = DateTime.now();
      final generatedAt =
          _readDateTime(source, const ['generated_at', 'created_at']) ?? now;
      final expiresAt =
          _readDateTime(source, const ['expires_at', 'expiresAt']) ??
          now.add(const Duration(minutes: 5));

      return MatchingSession(
        matchingSessionId:
            _readString(source, const [
              'matching_session_id',
              'matchingSessionId',
              'session_id',
              'id',
            ]) ??
            '',
        transportType:
            _readString(source, const ['transport_type', 'transportType']) ??
            '',
        responseVersion:
            _readInt(source, const ['response_version', 'version']) ?? 0,
        generatedAt: generatedAt,
        expiresAt: expiresAt,
        drivers: drivers,
      );
    } catch (e) {
      throw FormatException('Failed to parse MatchingSession: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'matching_session_id': matchingSessionId,
      'transport_type': transportType,
      'response_version': responseVersion,
      'generated_at': generatedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'drivers': drivers.map((d) => d.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MatchingSession(id: $matchingSessionId, type: $transportType, drivers: ${drivers.length}, expires: $secondsRemaining)';
  }
}

/// Individual driver in a matching response
@immutable
class DriverMatch {
  final int driverId;
  final String driverName;
  final String? profilePhotoUrl;
  final double? rating;
  final double? behaviorScore;
  final int estimatedArrivalMinutes;
  final double estimatedFare;
  final double distanceKm;
  final String onlineStatus; // 'online', 'offline', 'busy'
  final String assignmentState; // 'available', 'locked', 'assigned'
  final bool acceptingRequests;
  final bool availabilityLocked;
  final DriverLocation? currentLocation;
  final DriverVehicle? vehicle;

  // Private car specific
  final int? availableSeats;
  final List<String>? comfortTags;

  const DriverMatch({
    required this.driverId,
    required this.driverName,
    this.profilePhotoUrl,
    this.rating,
    this.behaviorScore,
    required this.estimatedArrivalMinutes,
    required this.estimatedFare,
    required this.distanceKm,
    required this.onlineStatus,
    required this.assignmentState,
    required this.acceptingRequests,
    required this.availabilityLocked,
    this.currentLocation,
    this.vehicle,
    this.availableSeats,
    this.comfortTags,
  });

  /// Check if driver can be selected
  bool get canSelect {
    return acceptingRequests &&
        !availabilityLocked &&
        assignmentState == 'available' &&
        onlineStatus == 'online';
  }

  /// Get display rating or N/A
  String get displayRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }

  /// Get behavior score badge color
  String get behaviorScoreBadge {
    if (behaviorScore == null) return 'Unknown';
    if (behaviorScore! >= 4.5) return 'Excellent';
    if (behaviorScore! >= 4.0) return 'Good';
    if (behaviorScore! >= 3.5) return 'Fair';
    return 'Low';
  }

  factory DriverMatch.fromJson(Map<String, dynamic> json) {
    try {
      final driver = json['driver'];
      final driverMap =
          driver is Map<String, dynamic> ? driver : const <String, dynamic>{};
      final location = json['current_location'];
      final vehicle = json['vehicle'] ?? driverMap['vehicle'];
      final onlineStatus =
          _readString(json, const [
            'online_status',
            'availability_status',
            'status',
          ]) ??
          'online';
      final assignmentState =
          _readString(json, const ['assignment_state', 'assignment_status']) ??
          'available';

      return DriverMatch(
        driverId:
            _readInt(json, const ['driver_id', 'id', 'user_id']) ??
            _readInt(driverMap, const ['id', 'driver_id', 'user_id']) ??
            0,
        driverName:
            _readString(json, const ['driver_name', 'name', 'full_name']) ??
            _readString(driverMap, const [
              'name',
              'driver_name',
              'full_name',
            ]) ??
            'Unknown Driver',
        profilePhotoUrl:
            _readString(json, const ['profile_photo_url', 'avatar', 'photo']) ??
            _readString(driverMap, const [
              'profile_photo_url',
              'avatar',
              'photo',
            ]),
        rating:
            _readDouble(json, const [
              'rating',
              'avg_rating',
              'driver_rating',
            ]) ??
            _readDouble(driverMap, const ['rating', 'avg_rating']),
        behaviorScore: _readDouble(json, const ['behavior_score']),
        estimatedArrivalMinutes:
            _readInt(json, const [
              'estimated_arrival_minutes',
              'eta_minutes',
              'eta',
            ]) ??
            0,
        estimatedFare:
            _readDouble(json, const ['estimated_fare', 'fare', 'price']) ?? 0.0,
        distanceKm: _readDouble(json, const ['distance_km', 'distance']) ?? 0.0,
        onlineStatus: onlineStatus,
        assignmentState: assignmentState,
        acceptingRequests:
            _readBool(json, const ['accepting_requests', 'can_accept']) ??
            onlineStatus == 'online',
        availabilityLocked:
            _readBool(json, const ['availability_locked', 'locked']) ??
            assignmentState == 'locked',
        currentLocation:
            location is Map<String, dynamic>
                ? DriverLocation.fromJson(location)
                : null,
        vehicle:
            vehicle is Map<String, dynamic>
                ? DriverVehicle.fromJson(vehicle)
                : null,
        availableSeats: _readInt(json, const ['available_seats', 'seats']),
        comfortTags:
            (json['comfort_tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList(),
      );
    } catch (e) {
      throw FormatException('Failed to parse DriverMatch: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'driver_name': driverName,
      'profile_photo_url': profilePhotoUrl,
      'rating': rating,
      'behavior_score': behaviorScore,
      'estimated_arrival_minutes': estimatedArrivalMinutes,
      'estimated_fare': estimatedFare,
      'distance_km': distanceKm,
      'online_status': onlineStatus,
      'assignment_state': assignmentState,
      'accepting_requests': acceptingRequests,
      'availability_locked': availabilityLocked,
      'current_location': currentLocation?.toJson(),
      'vehicle': vehicle?.toJson(),
      'available_seats': availableSeats,
      'comfort_tags': comfortTags,
    };
  }

  @override
  String toString() {
    return 'DriverMatch(id: $driverId, name: $driverName, canSelect: $canSelect)';
  }
}

@immutable
class DriverLocation {
  final double latitude;
  final double longitude;

  const DriverLocation({required this.latitude, required this.longitude});

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      latitude: _readDouble(json, const ['latitude', 'lat']) ?? 0.0,
      longitude: _readDouble(json, const ['longitude', 'lng']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

@immutable
class DriverVehicle {
  final String vehicleType;
  final String plateNumber;
  final String color;

  const DriverVehicle({
    required this.vehicleType,
    required this.plateNumber,
    required this.color,
  });

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    return DriverVehicle(
      vehicleType:
          _readString(json, const ['vehicle_type', 'type', 'model']) ??
          'Unknown',
      plateNumber:
          _readString(json, const ['plate_number', 'plate', 'registration']) ??
          'N/A',
      color: _readString(json, const ['color']) ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'color': color,
    };
  }
}

Map<String, dynamic> _dataMap(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    final session = data['matching_session'];
    if (session is Map<String, dynamic>) {
      return <String, dynamic>{...data, ...session};
    }
    return data;
  }
  return json;
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

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _readDouble(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool? _readBool(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
  }
  return null;
}

DateTime? _readDateTime(Map<String, dynamic> source, List<String> keys) {
  final text = _readString(source, keys);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

List<dynamic>? _readList(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is List) return value;
  }
  return null;
}
