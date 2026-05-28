import 'package:flutter/foundation.dart';

import '../../../models/matching/matching_session.dart';
import 'trip_models.dart';

enum MatchingLifecycleStatus {
  tripRequested,
  searchingCandidates,
  mlMatching,
  driverSelected,
  driverNotified,
  driverAcknowledged,
  driverRejected,
  reassigningDriver,
  noDriversAvailable,
  driverArriving,
  pickedUp,
  inProgress,
  completed,
  cancelled,
}

extension MatchingLifecycleStatusX on MatchingLifecycleStatus {
  String get apiValue {
    switch (this) {
      case MatchingLifecycleStatus.tripRequested:
        return 'TRIP_REQUESTED';
      case MatchingLifecycleStatus.searchingCandidates:
        return 'SEARCHING_CANDIDATES';
      case MatchingLifecycleStatus.mlMatching:
        return 'ML_MATCHING';
      case MatchingLifecycleStatus.driverSelected:
        return 'DRIVER_SELECTED';
      case MatchingLifecycleStatus.driverNotified:
        return 'DRIVER_NOTIFIED';
      case MatchingLifecycleStatus.driverAcknowledged:
        return 'DRIVER_ACKNOWLEDGED';
      case MatchingLifecycleStatus.driverRejected:
        return 'DRIVER_REJECTED';
      case MatchingLifecycleStatus.reassigningDriver:
        return 'REASSIGNING_DRIVER';
      case MatchingLifecycleStatus.noDriversAvailable:
        return 'NO_DRIVERS_AVAILABLE';
      case MatchingLifecycleStatus.driverArriving:
        return 'DRIVER_ARRIVING';
      case MatchingLifecycleStatus.pickedUp:
        return 'PICKED_UP';
      case MatchingLifecycleStatus.inProgress:
        return 'IN_PROGRESS';
      case MatchingLifecycleStatus.completed:
        return 'COMPLETED';
      case MatchingLifecycleStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get label => apiValue
      .toLowerCase()
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  bool get isTerminal =>
      this == MatchingLifecycleStatus.completed ||
      this == MatchingLifecycleStatus.cancelled ||
      this == MatchingLifecycleStatus.noDriversAvailable;

  static MatchingLifecycleStatus parse(dynamic value) {
    final raw = (value ?? '').toString().trim().toUpperCase();
    if (raw.contains('SEARCH')) return MatchingLifecycleStatus.searchingCandidates;
    if (raw.contains('ML') || raw.contains('MATCHING')) {
      return MatchingLifecycleStatus.mlMatching;
    }
    if (raw.contains('SELECTED') || raw == 'MATCHED') {
      return MatchingLifecycleStatus.driverSelected;
    }
    if (raw.contains('NOTIFIED')) return MatchingLifecycleStatus.driverNotified;
    if (raw.contains('ACK') || raw.contains('CONFIRM')) {
      return MatchingLifecycleStatus.driverAcknowledged;
    }
    if (raw.contains('REJECT')) return MatchingLifecycleStatus.driverRejected;
    if (raw.contains('REASSIGN')) return MatchingLifecycleStatus.reassigningDriver;
    if (raw.contains('NO_DRIVER') || raw.contains('NO DRIVERS')) {
      return MatchingLifecycleStatus.noDriversAvailable;
    }
    if (raw.contains('ARRIV')) return MatchingLifecycleStatus.driverArriving;
    if (raw.contains('PICK')) return MatchingLifecycleStatus.pickedUp;
    if (raw.contains('PROGRESS') || raw == 'STARTED') {
      return MatchingLifecycleStatus.inProgress;
    }
    if (raw.contains('COMPLETE')) return MatchingLifecycleStatus.completed;
    if (raw.contains('CANCEL')) return MatchingLifecycleStatus.cancelled;
    return MatchingLifecycleStatus.tripRequested;
  }

  static MatchingLifecycleStatus fromTripStatus(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return MatchingLifecycleStatus.tripRequested;
      case TripStatus.matched:
        return MatchingLifecycleStatus.driverSelected;
      case TripStatus.driverConfirmed:
        return MatchingLifecycleStatus.driverAcknowledged;
      case TripStatus.driverArriving:
        return MatchingLifecycleStatus.driverArriving;
      case TripStatus.pickedUp:
        return MatchingLifecycleStatus.pickedUp;
      case TripStatus.inProgress:
        return MatchingLifecycleStatus.inProgress;
      case TripStatus.completed:
        return MatchingLifecycleStatus.completed;
      case TripStatus.cancelled:
      case TripStatus.disputed:
        return MatchingLifecycleStatus.cancelled;
    }
  }
}

@immutable
class AssignmentAttempt {
  const AssignmentAttempt({
    required this.index,
    required this.status,
    this.driverId,
    this.driverName = '',
    this.createdAt,
  });

  final int index;
  final MatchingLifecycleStatus status;
  final int? driverId;
  final String driverName;
  final DateTime? createdAt;

  factory AssignmentAttempt.fromJson(Map<String, dynamic> json, int index) {
    final driver = json['driver'];
    final driverMap =
        driver is Map<String, dynamic> ? driver : const <String, dynamic>{};
    return AssignmentAttempt(
      index: _readInt(json, const ['attempt', 'index']) ?? index,
      status: MatchingLifecycleStatusX.parse(json['status']),
      driverId:
          _readInt(json, const ['driver_id', 'driverId']) ??
          _readInt(driverMap, const ['id', 'driver_id']),
      driverName:
          _readString(json, const ['driver_name', 'name']) ??
          _readString(driverMap, const ['name', 'driver_name']) ??
          '',
      createdAt: DateTime.tryParse(
        _readString(json, const ['created_at', 'timestamp']) ?? '',
      ),
    );
  }
}

@immutable
class MatchingLifecycleSnapshot {
  const MatchingLifecycleSnapshot({
    required this.status,
    this.trip,
    this.session,
    this.selectedDriver,
    this.candidates = const [],
    this.attempts = const [],
    this.message = '',
    this.lastUpdated,
  });

  final MatchingLifecycleStatus status;
  final Trip? trip;
  final MatchingSession? session;
  final DriverMatch? selectedDriver;
  final List<DriverMatch> candidates;
  final List<AssignmentAttempt> attempts;
  final String message;
  final DateTime? lastUpdated;

  bool get hasCandidates => candidates.isNotEmpty;

  MatchingLifecycleSnapshot copyWith({
    MatchingLifecycleStatus? status,
    Trip? trip,
    MatchingSession? session,
    DriverMatch? selectedDriver,
    List<DriverMatch>? candidates,
    List<AssignmentAttempt>? attempts,
    String? message,
    DateTime? lastUpdated,
  }) {
    return MatchingLifecycleSnapshot(
      status: status ?? this.status,
      trip: trip ?? this.trip,
      session: session ?? this.session,
      selectedDriver: selectedDriver ?? this.selectedDriver,
      candidates: candidates ?? this.candidates,
      attempts: attempts ?? this.attempts,
      message: message ?? this.message,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory MatchingLifecycleSnapshot.fromTrip(Trip trip) {
    return MatchingLifecycleSnapshot(
      status: MatchingLifecycleStatusX.fromTripStatus(trip.status),
      trip: trip,
      selectedDriver:
          trip.driver == null
              ? null
              : DriverMatch(
                driverId: trip.driver!.id,
                driverName: trip.driver!.name,
                profilePhotoUrl: trip.driver!.photoUrl,
                rating: trip.driver!.rating,
                estimatedArrivalMinutes: 0,
                estimatedFare: trip.fare,
                distanceKm: 0,
                onlineStatus: 'online',
                assignmentState: 'assigned',
                acceptingRequests: true,
                availabilityLocked: true,
              ),
      lastUpdated: DateTime.now(),
    );
  }

  factory MatchingLifecycleSnapshot.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final tripRaw = data['trip'];
    final sessionRaw = data['matching_session'] ?? data['session'];
    final selectedRaw = data['selected_driver'] ?? data['driver'];
    final candidatesRaw =
        data['candidates'] ??
        data['ranked_candidates'] ??
        data['drivers'] ??
        data['matched_drivers'];
    final attemptsRaw = data['assignment_attempts'] ?? data['attempts'];
    return MatchingLifecycleSnapshot(
      status: MatchingLifecycleStatusX.parse(
        data['matching_status'] ?? data['status'] ?? data['trip_status'],
      ),
      trip: tripRaw is Map<String, dynamic> ? Trip.fromJson(tripRaw) : null,
      session:
          sessionRaw is Map<String, dynamic>
              ? MatchingSession.fromJson(sessionRaw)
              : null,
      selectedDriver:
          selectedRaw is Map<String, dynamic>
              ? DriverMatch.fromJson(selectedRaw)
              : null,
      candidates:
          candidatesRaw is List
              ? candidatesRaw
                  .whereType<Map<String, dynamic>>()
                  .map(DriverMatch.fromJson)
                  .toList()
              : const [],
      attempts:
          attemptsRaw is List
              ? attemptsRaw
                  .whereType<Map<String, dynamic>>()
                  .indexed
                  .map((entry) => AssignmentAttempt.fromJson(entry.$2, entry.$1 + 1))
                  .toList()
              : const [],
      message: _readString(data, const ['message', 'status_message']) ?? '',
      lastUpdated: DateTime.now(),
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

String? _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
