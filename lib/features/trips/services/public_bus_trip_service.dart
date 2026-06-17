import 'dart:async';
import 'package:logger/logger.dart';
import '../../../services/passenger_api.dart';

/// Status model for public bus trip requests
class PublicBusTripStatus {
  const PublicBusTripStatus({
    required this.requestId,
    required this.status,
    required this.corridorId,
    required this.boardingStopId,
    required this.destinationStopId,
    this.busId,
    this.busName,
    this.busMake,
    this.busModel,
    this.busPlate,
    this.driverName,
    this.driverPhone,
    this.estimatedFare,
    this.actualFare,
    this.seatsReserved = 1,
    this.ticketCode,
    this.createdAt,
    this.raw = const {},
  });

  final int requestId;
  final String status;
  final int corridorId;
  final int boardingStopId;
  final int destinationStopId;
  final int? busId;
  final String? busName;
  final String? busMake;
  final String? busModel;
  final String? busPlate;
  final String? driverName;
  final String? driverPhone;
  final num? estimatedFare;
  final num? actualFare;
  final int seatsReserved;
  final String? ticketCode;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  bool get isPending =>
      status == 'PENDING' ||
      status == 'SEARCHING' ||
      status == 'AWAITING_ASSIGNMENT';
  bool get isAssigned => status == 'ASSIGNED' || status == 'CONFIRMED';
  bool get isBoarding => status == 'BOARDING' || status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED' || status == 'ARRIVED';
  bool get isCancelled => status == 'CANCELLED';

  factory PublicBusTripStatus.fromJson(Map<String, dynamic> json) {
    return PublicBusTripStatus(
      requestId:
          (json['request_id'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      status: (json['status'] as String?)?.toUpperCase() ?? 'UNKNOWN',
      corridorId: (json['corridor_id'] as num?)?.toInt() ?? 0,
      boardingStopId: (json['boarding_stop_id'] as num?)?.toInt() ?? 0,
      destinationStopId: (json['destination_stop_id'] as num?)?.toInt() ?? 0,
      busId: (json['bus_id'] as num?)?.toInt(),
      busName: json['bus_name'] as String?,
      busMake: json['bus_make'] as String?,
      busModel: json['bus_model'] as String?,
      busPlate: json['bus_plate'] as String?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      estimatedFare: json['estimated_fare'] as num?,
      actualFare: json['actual_fare'] as num?,
      seatsReserved: (json['seats_reserved'] as num?)?.toInt() ?? 1,
      ticketCode: json['ticket_code'] as String?,
      createdAt:
          json['created_at'] is String
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      raw: json,
    );
  }
}

/// Service for managing public bus trip requests
/// Handles creation, polling, and lifecycle updates
class PublicBusTripService {
  PublicBusTripService({PassengerApi? api, Logger? logger})
    : _api = api ?? PassengerApi.instance,
      _logger = logger ?? Logger();

  final PassengerApi _api;
  final Logger _logger;

  final StreamController<PublicBusTripStatus> _statusController =
      StreamController<PublicBusTripStatus>.broadcast();

  Stream<PublicBusTripStatus> get statusStream => _statusController.stream;

  /// Create a new public bus trip request
  /// Returns the created request with initial status
  Future<PublicBusTripStatus> createBusRequest({
    required int corridorId,
    required int boardingStopId,
    required int destinationStopId,
    int seatsReserved = 1,
    int? busRouteAssignmentId,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLocation,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    try {
      _logger.i(
        '[PublicBusTripService] Creating bus request: '
        'corridor=$corridorId, stops=$boardingStopId→$destinationStopId',
      );

      final payload = <String, dynamic>{
        'transport_type': 'PUBLIC_BUS',
        'seats_reserved': seatsReserved,
        'corridor_id': corridorId,
        'boarding_stop_id': boardingStopId,
        'destination_stop_id': destinationStopId,
        if (busRouteAssignmentId != null)
          'bus_route_assignment_id': busRouteAssignmentId,
        if (pickupLocation != null) 'pickup_location': pickupLocation,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (dropoffLocation != null) 'dropoff_location': dropoffLocation,
        if (dropoffLat != null) 'dropoff_lat': dropoffLat,
        if (dropoffLng != null) 'dropoff_lng': dropoffLng,
      };

      final response = await _api.post(
        '/passenger/public-bus/request',
        payload,
      );

      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;

      final status = PublicBusTripStatus.fromJson(data);
      _statusController.add(status);

      return status;
    } catch (e, st) {
      _logger.e(
        '[PublicBusTripService] Create request failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Get the current state of a bus request
  Future<PublicBusTripStatus> getBusRequest(int requestId) async {
    try {
      final response = await _api.get(
        '/passenger/public-bus/requests/$requestId',
      );

      final data =
          response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;

      final status = PublicBusTripStatus.fromJson(data);
      _statusController.add(status);

      return status;
    } catch (e, st) {
      _logger.e(
        '[PublicBusTripService] Get request failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Watch the lifecycle of a bus request with automatic polling
  /// Emits status updates as they become available
  Stream<PublicBusTripStatus> watchBusLifecycle(
    int requestId, {
    Duration initialDelay = const Duration(seconds: 2),
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

        final status = await getBusRequest(requestId);
        yield status;

        // Check if we reached a terminal state
        if (status.isCompleted || status.isCancelled) {
          _logger.i(
            '[PublicBusTripService] Bus request reached terminal state: '
            '${status.status}',
          );
          break;
        }

        backoffAttempt = (backoffAttempt + 1) % backoffIntervals.length;
      } catch (e, st) {
        _logger.e(
          '[PublicBusTripService] Polling error',
          error: e,
          stackTrace: st,
        );
        backoffAttempt = (backoffAttempt + 1) % backoffIntervals.length;
        continue;
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _statusController.close();
  }
}
