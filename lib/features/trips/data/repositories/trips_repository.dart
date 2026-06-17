import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_models.dart';
import '../datasources/trips_datasource.dart';
import '../../domain/trip_realtime_event.dart';

/// High-level business logic for trip operations
abstract class ITripsRepository {
  /// Get list of active or recent trips
  Future<List<TripData>> getTrips({int? limit, int? offset, String? status});

  /// Get specific trip details
  Future<TripData> getTrip(int tripId);

  /// Create a new trip request
  Future<TripData> createTrip(CreateTripRequest request, String vehicleType);

  /// Compute route and get fare estimate
  Future<RouteData> computeRoute(RouteComputeRequest request);

  /// Cancel a trip
  Future<void> cancelTrip(int tripId, {String? reason});

  /// Rate/review a completed trip
  Future<void> rateTrip(int tripId, RatingRequest request, String vehicleType);

  /// Acknowledge a trip status transition
  Future<void> acknowledgeTripStatus(int tripId, String ackType);

  /// Get trip history
  Future<List<TripData>> getTripHistory(String vehicleType, {int? page, int? perPage});
}

/// Implementation of trips repository
class TripsRepository implements ITripsRepository {
  final ITripsDataSource _dataSource;

  TripsRepository({required ITripsDataSource dataSource})
    : _dataSource = dataSource;

  @override
  Future<List<TripData>> getTrips({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      final response = await _dataSource.getTrips(
        limit: limit ?? 10,
        offset: offset ?? 0,
        status: status,
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch trips');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TripData> getTrip(int tripId) async {
    try {
      final response = await _dataSource.getTrip(tripId);

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch trip');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TripData> createTrip(CreateTripRequest request, String vehicleType) async {
    try {
      final response = await _dataSource.createTrip(request, vehicleType);

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to create trip');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<RouteData> computeRoute(RouteComputeRequest request) async {
    try {
      final response = await _dataSource.computeRoute(request);

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to compute route');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> cancelTrip(int tripId, {String? reason}) async {
    try {
      final response = await _dataSource.cancelTrip(tripId, reason: reason);

      if (!response.success) {
        throw Exception(response.message ?? 'Failed to cancel trip');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> rateTrip(int tripId, RatingRequest request, String vehicleType) async {
    try {
      final response = await _dataSource.rateTrip(tripId, request, vehicleType);

      if (!response.success) {
        throw Exception(response.message ?? 'Failed to rate trip');
      }
    } catch (e) {
      throw Exception('Failed to rate trip: $e');
    }
  }

  @override
  Future<void> acknowledgeTripStatus(int tripId, String ackType) async {
    await _dataSource.acknowledgeTripStatus(tripId, ackType);
  }

  @override
  Future<List<TripData>> getTripHistory(String vehicleType, {int? page, int? perPage}) async {
    try {
      final response = await _dataSource.getTripHistory(
        vehicleType,
        page: page ?? 1,
        perPage: perPage ?? 20,
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch trip history');
      }
    } catch (e) {
      rethrow;
    }
  }
}
