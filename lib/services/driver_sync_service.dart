import 'package:flutter/foundation.dart';

enum DriverTripStage { accepted, onRoute, inProgress }

extension DriverTripStageX on DriverTripStage {
  String get label {
    switch (this) {
      case DriverTripStage.accepted:
        return 'Accepted';
      case DriverTripStage.onRoute:
        return 'On Route';
      case DriverTripStage.inProgress:
        return 'In Progress';
    }
  }

  String get backendStatus {
    switch (this) {
      case DriverTripStage.accepted:
        return 'accepted';
      case DriverTripStage.onRoute:
        return 'on_route';
      case DriverTripStage.inProgress:
        return 'in_progress';
    }
  }

  static DriverTripStage fromBackendStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'on_route' || normalized == 'onroute') {
      return DriverTripStage.onRoute;
    }
    if (normalized == 'in_progress' || normalized == 'ongoing') {
      return DriverTripStage.inProgress;
    }
    return DriverTripStage.accepted;
  }
}

class DriverActiveTrip {
  final String requestId;
  final String passengerName;
  final String pickup;
  final String destination;
  final double fare;
  final DriverTripStage stage;

  const DriverActiveTrip({
    required this.requestId,
    required this.passengerName,
    required this.pickup,
    required this.destination,
    required this.fare,
    this.stage = DriverTripStage.accepted,
  });

  DriverActiveTrip copyWith({DriverTripStage? stage}) {
    return DriverActiveTrip(
      requestId: requestId,
      passengerName: passengerName,
      pickup: pickup,
      destination: destination,
      fare: fare,
      stage: stage ?? this.stage,
    );
  }
}

class DriverSyncService {
  DriverSyncService._();

  static final DriverSyncService instance = DriverSyncService._();

  final ValueNotifier<int> dataVersionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<DriverActiveTrip?> activeTripNotifier =
      ValueNotifier<DriverActiveTrip?>(null);

  void bumpDataVersion() {
    dataVersionNotifier.value = dataVersionNotifier.value + 1;
  }

  void setActiveTrip(DriverActiveTrip trip) {
    activeTripNotifier.value = trip;
    bumpDataVersion();
  }

  void updateActiveTripStage(DriverTripStage stage) {
    final activeTrip = activeTripNotifier.value;
    if (activeTrip == null) return;
    activeTripNotifier.value = activeTrip.copyWith(stage: stage);
    bumpDataVersion();
  }

  void advanceActiveTripStage() {
    final activeTrip = activeTripNotifier.value;
    if (activeTrip == null) return;

    final next = switch (activeTrip.stage) {
      DriverTripStage.accepted => DriverTripStage.onRoute,
      DriverTripStage.onRoute => DriverTripStage.inProgress,
      DriverTripStage.inProgress => DriverTripStage.inProgress,
    };

    activeTripNotifier.value = activeTrip.copyWith(stage: next);
    bumpDataVersion();
  }

  void clearActiveTrip() {
    activeTripNotifier.value = null;
    bumpDataVersion();
  }
}
