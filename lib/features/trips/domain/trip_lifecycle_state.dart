import 'package:flutter/foundation.dart';

import '../models/motor_vehicle_trip_status.dart' as model;

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
  cancelled,
  noDriversFound,
  matchTimeout,
  unknown,
}

extension TripLifecyclePhaseX on TripLifecyclePhase {
  String get label {
    switch (this) {
      case TripLifecyclePhase.requestReceived:
        return 'Request received';
      case TripLifecyclePhase.fareCalculated:
        return 'Fare calculated';
      case TripLifecyclePhase.searchingCandidates:
        return 'Searching nearby drivers';
      case TripLifecyclePhase.driversFound:
        return 'Drivers found';
      case TripLifecyclePhase.contactingDrivers:
        return 'Contacting drivers';
      case TripLifecyclePhase.driverAccepted:
        return 'Driver accepted';
      case TripLifecyclePhase.driverArriving:
        return 'Driver arriving';
      case TripLifecyclePhase.driverArrived:
        return 'Driver arrived';
      case TripLifecyclePhase.tripStarted:
        return 'Trip started';
      case TripLifecyclePhase.tripCompleted:
        return 'Trip completed';
      case TripLifecyclePhase.cancelled:
        return 'Cancelled';
      case TripLifecyclePhase.noDriversFound:
        return 'No drivers found';
      case TripLifecyclePhase.matchTimeout:
        return 'Match timeout';
      case TripLifecyclePhase.unknown:
        return 'Matching';
    }
  }

  bool get isTerminal =>
      this == TripLifecyclePhase.tripCompleted ||
      this == TripLifecyclePhase.cancelled ||
      this == TripLifecyclePhase.noDriversFound ||
      this == TripLifecyclePhase.matchTimeout;

  int get timelineIndex {
    switch (this) {
      case TripLifecyclePhase.requestReceived:
        return 0;
      case TripLifecyclePhase.fareCalculated:
        return 1;
      case TripLifecyclePhase.searchingCandidates:
        return 2;
      case TripLifecyclePhase.driversFound:
        return 3;
      case TripLifecyclePhase.contactingDrivers:
        return 4;
      case TripLifecyclePhase.driverAccepted:
        return 5;
      case TripLifecyclePhase.driverArriving:
        return 6;
      case TripLifecyclePhase.driverArrived:
        return 7;
      case TripLifecyclePhase.tripStarted:
        return 8;
      case TripLifecyclePhase.tripCompleted:
        return 9;
      case TripLifecyclePhase.cancelled:
      case TripLifecyclePhase.noDriversFound:
      case TripLifecyclePhase.matchTimeout:
      case TripLifecyclePhase.unknown:
        return 9;
    }
  }

  String get subtitle {
    switch (this) {
      case TripLifecyclePhase.requestReceived:
        return 'Your trip request has been received.';
      case TripLifecyclePhase.fareCalculated:
        return 'Fare details are ready.';
      case TripLifecyclePhase.searchingCandidates:
        return 'Finding drivers near you.';
      case TripLifecyclePhase.driversFound:
        return 'Drivers have been located.';
      case TripLifecyclePhase.contactingDrivers:
        return 'Notifying driver candidates.';
      case TripLifecyclePhase.driverAccepted:
        return 'A driver has accepted your request.';
      case TripLifecyclePhase.driverArriving:
        return 'Your driver is on the way.';
      case TripLifecyclePhase.driverArrived:
        return 'Driver has arrived at pickup.';
      case TripLifecyclePhase.tripStarted:
        return 'Your trip has started.';
      case TripLifecyclePhase.tripCompleted:
        return 'Your trip is complete.';
      case TripLifecyclePhase.cancelled:
        return 'This trip was cancelled.';
      case TripLifecyclePhase.noDriversFound:
        return 'No drivers were available nearby.';
      case TripLifecyclePhase.matchTimeout:
        return 'Matching timed out. Please retry.';
      case TripLifecyclePhase.unknown:
        return 'Matching in progress.';
    }
  }
}

@immutable
class TripLifecycleState {
  const TripLifecycleState({
    required this.tripId,
    required this.phase,
    required this.status,
    this.matchingStatus,
    this.statusMessage = '',
    this.searchRadiusKm,
    this.driversFound = 0,
    this.retryCount = 0,
    this.maxRetries = 0,
    this.estimatedFare,
    this.etaMinutes,
    this.driver,
    this.vehicleDescription,
    this.driverPhone,
    this.driverPhotoUrl,
    this.vehiclePlate,
    this.realtimeConnected = false,
    this.polling = false,
    this.raw = const {},
  });

  final int tripId;
  final TripLifecyclePhase phase;
  final String status;
  final String? matchingStatus;
  final String statusMessage;
  final double? searchRadiusKm;
  final int driversFound;
  final int retryCount;
  final int maxRetries;
  final double? estimatedFare;
  final int? etaMinutes;
  final model.TripDriver? driver;
  final String? vehicleDescription;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final String? vehiclePlate;
  final bool realtimeConnected;
  final bool polling;
  final Map<String, dynamic> raw;

  bool get isTerminal => phase.isTerminal;

  bool get canCancel {
    return phase == TripLifecyclePhase.searchingCandidates ||
        phase == TripLifecyclePhase.driversFound ||
        phase == TripLifecyclePhase.contactingDrivers ||
        phase == TripLifecyclePhase.driverAccepted;
  }

  String get subtitle => phase.subtitle;

  String get statusLabel {
    if (statusMessage.isNotEmpty) return statusMessage;
    return phase.subtitle;
  }

  static TripLifecycleState initial({
    required int tripId,
    double? estimatedFare,
  }) {
    return TripLifecycleState(
      tripId: tripId,
      phase: TripLifecyclePhase.requestReceived,
      status: 'REQUESTED',
      statusMessage: 'Request received. Preparing your trip.',
      estimatedFare: estimatedFare,
      polling: true,
    );
  }

  factory TripLifecycleState.fromStatus(
    model.MotorVehicleTripStatus status, {
    bool realtimeConnected = false,
    bool polling = false,
  }) {
    final mappedPhase = _mapPhase(status.phase, status);
    return TripLifecycleState(
      tripId: status.tripId,
      phase: mappedPhase,
      status: status.status,
      matchingStatus: status.matchingStatus,
      statusMessage: _friendlyMessage(mappedPhase, status),
      searchRadiusKm: status.searchRadiusKm,
      driversFound: status.driversFound,
      retryCount: status.retryCount ?? 0,
      maxRetries: status.maxRetries ?? 0,
      estimatedFare: status.estimatedFare?.toDouble(),
      etaMinutes: status.etaMinutes,
      driver: status.driver,
      vehicleDescription: status.vehicleDescription,
      driverPhone: status.driver?.phone,
      driverPhotoUrl: status.driver?.photoUrl,
      vehiclePlate: status.driver?.vehiclePlate,
      realtimeConnected: realtimeConnected,
      polling: polling,
      raw: status.raw,
    );
  }

  TripLifecycleState copyWith({
    TripLifecyclePhase? phase,
    String? status,
    String? matchingStatus,
    String? statusMessage,
    double? searchRadiusKm,
    int? driversFound,
    int? retryCount,
    int? maxRetries,
    double? estimatedFare,
    int? etaMinutes,
    model.TripDriver? driver,
    String? vehicleDescription,
    String? driverPhone,
    String? driverPhotoUrl,
    String? vehiclePlate,
    bool? realtimeConnected,
    bool? polling,
    Map<String, dynamic>? raw,
  }) {
    return TripLifecycleState(
      tripId: tripId,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      matchingStatus: matchingStatus ?? this.matchingStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      driversFound: driversFound ?? this.driversFound,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      driver: driver ?? this.driver,
      vehicleDescription: vehicleDescription ?? this.vehicleDescription,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      polling: polling ?? this.polling,
      raw: raw ?? this.raw,
    );
  }
}

TripLifecyclePhase _mapPhase(
  model.TripLifecyclePhase phase,
  model.MotorVehicleTripStatus status,
) {
  if (phase == model.TripLifecyclePhase.searchingCandidates &&
      status.matchingStatus == 'DRIVER_FOUND') {
    return TripLifecyclePhase.driversFound;
  }
  if (phase == model.TripLifecyclePhase.searchingCandidates &&
      status.matchingStatus == 'FAILED_MAX_RETRIES') {
    return TripLifecyclePhase.noDriversFound;
  }

  switch (phase) {
    case model.TripLifecyclePhase.requestReceived:
      return TripLifecyclePhase.requestReceived;
    case model.TripLifecyclePhase.fareCalculated:
      return TripLifecyclePhase.fareCalculated;
    case model.TripLifecyclePhase.searchingCandidates:
      return TripLifecyclePhase.searchingCandidates;
    case model.TripLifecyclePhase.driversFound:
      return TripLifecyclePhase.driversFound;
    case model.TripLifecyclePhase.contactingDrivers:
      return TripLifecyclePhase.contactingDrivers;
    case model.TripLifecyclePhase.driverAccepted:
      return TripLifecyclePhase.driverAccepted;
    case model.TripLifecyclePhase.driverArriving:
      return TripLifecyclePhase.driverArriving;
    case model.TripLifecyclePhase.driverArrived:
      return TripLifecyclePhase.driverArrived;
    case model.TripLifecyclePhase.tripStarted:
      return TripLifecyclePhase.tripStarted;
    case model.TripLifecyclePhase.tripCompleted:
      return TripLifecyclePhase.tripCompleted;
    case model.TripLifecyclePhase.cancelled:
      return TripLifecyclePhase.cancelled;
    case model.TripLifecyclePhase.noDriversFound:
      return TripLifecyclePhase.noDriversFound;
    case model.TripLifecyclePhase.matchTimeout:
      return TripLifecyclePhase.matchTimeout;
    case model.TripLifecyclePhase.unknown:
      return TripLifecyclePhase.unknown;
  }
}

String _friendlyMessage(
  TripLifecyclePhase phase,
  model.MotorVehicleTripStatus status,
) {
  if (phase == TripLifecyclePhase.driversFound) {
    return 'Drivers found. Contacting nearby candidates.';
  }
  if (phase == TripLifecyclePhase.driverAccepted) {
    return 'Driver accepted your request.';
  }
  if (phase == TripLifecyclePhase.driverArriving) {
    return 'Your driver is on the way.';
  }
  if (phase == TripLifecyclePhase.driverArrived) {
    return 'Driver has arrived for pickup.';
  }
  if (phase == TripLifecyclePhase.tripStarted) {
    return 'Trip started. Enjoy your ride.';
  }
  if (phase == TripLifecyclePhase.tripCompleted) {
    return 'Trip completed. Please pay and rate your driver.';
  }
  if (phase == TripLifecyclePhase.noDriversFound) {
    return 'No drivers found nearby. You can retry or try again later.';
  }
  if (phase == TripLifecyclePhase.matchTimeout) {
    return 'Matching timed out. Please retry or adjust your pickup.';
  }
  if (phase == TripLifecyclePhase.cancelled) {
    return 'This trip was cancelled.';
  }
  return phase.subtitle;
}
