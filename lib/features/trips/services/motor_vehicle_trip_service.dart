import 'dart:async';
import 'package:logger/logger.dart';
import '../../../services/passenger_api.dart';
import '../models/motor_vehicle_trip_status.dart';

/// Service for managing motor-vehicle (motorcycle/car) trip requests
/// Handles creation, polling, cancellation, and lifecycle updates
class MotorVehicleTripService {
  MotorVehicleTripService({PassengerApi? api, Logger? logger})
    : _api = api ?? PassengerApi.instance,
      _logger = logger ?? Logger();

  final PassengerApi _api;
  final Logger _logger;

  final StreamController<MotorVehicleTripStatus> _statusController =
      StreamController<MotorVehicleTripStatus>.broadcast();

  Stream<MotorVehicleTripStatus> get statusStream => _statusController.stream;

  /// Create a new motor-vehicle trip request
  /// Returns the created trip with initial status
  Future<MotorVehicleTripStatus> createTripRequest({
    required String pickupLocation,
    required String dropoffLocation,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String transportType = 'MOTORCYCLE',
  }) async {
    try {
      _logger.i(
        '[MotorVehicleTripService] Creating trip request: '
        '$pickupLocation → $dropoffLocation',
      );

      final response = await _api.post('/motor-vehicle/trip-requests', {
            'transport_type': transportType,
            'pickup_location': pickupLocation,
            'pickup_lat': pickupLat,
            'pickup_lng': pickupLng,
            'dropoff_location': dropoffLocation,
            'dropoff_lat': dropoffLat,
            'dropoff_lng': dropoffLng,
          });

      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;

      final status = MotorVehicleTripStatus.fromJson(data);
      _statusController.add(status);

      return status;
    } catch (e, st) {
      _logger.e(
        '[MotorVehicleTripService] Create request failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Poll the current state of a trip request
  /// Falls back gracefully if endpoint is unavailable
  Future<MotorVehicleTripStatus> getTripRequest(int tripRequestId) async {
    try {
      final response = await _api.get(
        '/motor-vehicle/trip-requests/$tripRequestId',
      );

      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;

      final status = MotorVehicleTripStatus.fromJson(data);
      _statusController.add(status);

      return status;
    } catch (e, st) {
      _logger.e(
        '[MotorVehicleTripService] Get request failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Cancel an active trip request
  /// Returns the cancelled trip status
  Future<MotorVehicleTripStatus> cancelTripRequest(
    int tripRequestId, {
    String? reason,
  }) async {
    try {
      _logger.i('[MotorVehicleTripService] Cancelling trip: $tripRequestId');

      final response = await _api.post(
        '/motor-vehicle/trip-requests/$tripRequestId/cancel',
        {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );

      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;

      final status = MotorVehicleTripStatus.fromJson(data);
      _statusController.add(status);

      return status;
    } catch (e, st) {
      _logger.e(
        '[MotorVehicleTripService] Cancel request failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Watch the lifecycle of a trip request with automatic polling
  /// Emits status updates as they become available
  /// Stops polling when trip reaches terminal state
  Stream<MotorVehicleTripStatus> watchTripLifecycle(
    int tripRequestId, {
    Duration initialDelay = const Duration(seconds: 2),
    Duration maxInterval = const Duration(seconds: 8),
  }) async* {
    int backoffAttempt = 0;
    final backoffIntervals = [
      const Duration(seconds: 2),
      const Duration(seconds: 3),
      const Duration(seconds: 5),
      const Duration(seconds: 8),
      const Duration(seconds: 8),
      const Duration(seconds: 8),
    ];

    while (true) {
      try {
        final interval =
            backoffIntervals[backoffAttempt.clamp(
              0,
              backoffIntervals.length - 1,
            )];
        await Future.delayed(interval);

        final status = await getTripRequest(tripRequestId);
        yield status;

        // Check if we reached a terminal state
        if (_isTerminalState(status)) {
          _logger.i(
            '[MotorVehicleTripService] Trip reached terminal state: '
            '${status.phase}',
          );
          break;
        }

        // Reset backoff on status change (if applicable)
        backoffAttempt = (backoffAttempt + 1) % backoffIntervals.length;
      } catch (e, st) {
        _logger.e(
          '[MotorVehicleTripService] Polling error',
          error: e,
          stackTrace: st,
        );
        backoffAttempt = (backoffAttempt + 1) % backoffIntervals.length;
        continue;
      }
    }
  }

  /// Check if a trip phase is terminal (stop polling)
  bool _isTerminalState(MotorVehicleTripStatus status) {
    return status.phase == TripLifecyclePhase.tripCompleted ||
        status.phase == TripLifecyclePhase.cancelled ||
        status.phase == TripLifecyclePhase.matchTimeout ||
        status.phase == TripLifecyclePhase.noDriversFound;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _statusController.close();
  }
}
