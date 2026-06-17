// test/models/trip_model_test.dart
// Unit tests for TripModel parsing and display logic

import 'package:flutter_test/flutter_test.dart';
import 'package:rideconnect_app/models/trip_model.dart';

void main() {
  group('TripModel', () {
    group('Decimal parsing from Laravel', () {
      test('parses string decimals correctly', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.9550',
          'pickup_lng': '30.0596',
          'dropoff_lat': '2.0469',
          'dropoff_lng': '30.2753',
          'fare': '5000.00',
          'status': 'requested',
          'payment_status': 'unpaid',
          'assignment_status': 'unassigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.pickupLat, 1.9550);
        expect(trip.pickupLng, 30.0596);
        expect(trip.fare, 5000.00);
      });

      test('handles null decimal values', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'actual_fare': null,
          'actual_distance': null,
          'status': 'requested',
          'payment_status': 'unpaid',
          'assignment_status': 'unassigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.actualFare, null);
        expect(trip.actualDistance, null);
      });
    });

    group('DateTime parsing', () {
      test('parses ISO 8601 dates correctly', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'completed',
          'payment_status': 'paid',
          'assignment_status': 'assigned',
          'requested_at': '2024-05-29T10:00:00Z',
          'completed_at': '2024-05-29T10:30:00Z',
          'created_at': '2024-05-29T09:59:00Z',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.requestedAt, isNotNull);
        expect(trip.completedAt, isNotNull);
        expect(trip.createdAt, isNotNull);
      });

      test('handles null date values', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'requested',
          'payment_status': 'unpaid',
          'assignment_status': 'unassigned',
          'requested_at': null,
          'accepted_at': null,
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.requestedAt, null);
        expect(trip.acceptedAt, null);
      });
    });

    group('isActive computed property', () {
      test('returns true for active statuses', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'in_progress',
          'payment_status': 'unpaid',
          'assignment_status': 'assigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.isActive, true);
      });

      test('returns false for completed status', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'completed',
          'payment_status': 'paid',
          'assignment_status': 'assigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.isActive, false);
      });
    });

    group('canCancel computed property', () {
      test('returns true for requested status', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'requested',
          'payment_status': 'unpaid',
          'assignment_status': 'unassigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.canCancel, true);
      });

      test('returns false for accepted status', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000',
          'status': 'accepted',
          'payment_status': 'unpaid',
          'assignment_status': 'assigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.canCancel, false);
      });
    });

    group('Fare display formatting', () {
      test('formats fare as RWF with no decimals', () {
        final json = {
          'id': 1,
          'passenger_id': 100,
          'pickup_location': 'Kigali',
          'dropoff_location': 'Muhanga',
          'pickup_lat': '1.95',
          'pickup_lng': '30.06',
          'dropoff_lat': '2.04',
          'dropoff_lng': '30.27',
          'fare': '5000.50',
          'status': 'requested',
          'payment_status': 'unpaid',
          'assignment_status': 'unassigned',
          'rejected_drivers_count': 0,
        };

        final trip = TripModel.fromJson(json);
        expect(trip.fareDisplay, 'RWF 5001');
      });
    });

    group('Transport type icon mapping', () {
      test('returns correct icons for transport types', () {
        final motos = TripModel(
          id: 1,
          passengerId: 100,
          pickupLocation: 'Kigali',
          dropoffLocation: 'Muhanga',
          pickupLat: 1.95,
          pickupLng: 30.06,
          dropoffLat: 2.04,
          dropoffLng: 30.27,
          fare: 1200,
          status: 'requested',
          paymentStatus: 'unpaid',
          assignmentStatus: 'unassigned',
          transportType: 'moto',
          rejectedDriversCount: 0,
        );

        final cars = motos.copyWith(transportType: 'car');
        final buses = motos.copyWith(transportType: 'bus');

        expect(motos.transportIcon, '🏍️');
        expect(cars.transportIcon, '🚗');
        expect(buses.transportIcon, '🚌');
      });
    });

    group('copyWith', () {
      test('creates new instance with updated fields', () {
        final original = TripModel(
          id: 1,
          passengerId: 100,
          pickupLocation: 'Kigali',
          dropoffLocation: 'Muhanga',
          pickupLat: 1.95,
          pickupLng: 30.06,
          dropoffLat: 2.04,
          dropoffLng: 30.27,
          fare: 5000,
          status: 'requested',
          paymentStatus: 'unpaid',
          assignmentStatus: 'unassigned',
          rejectedDriversCount: 0,
        );

        final updated = original.copyWith(status: 'accepted', driverId: 50);

        expect(updated.status, 'accepted');
        expect(updated.driverId, 50);
        expect(updated.fare, original.fare);
        expect(updated.pickupLocation, original.pickupLocation);
      });
    });
  });
}
