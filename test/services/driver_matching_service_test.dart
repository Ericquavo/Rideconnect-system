// test/services/driver_matching_service_test.dart
// Unit tests for DriverMatchingService retry and empty response handling

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:rideconnect_app/services/driver_matching_service.dart';

void main() {
  group('DriverMatchingService Response Models', () {
    group('AvailableDriver', () {
      test('parses from JSON correctly', () {
        final json = {
          'id': 1,
          'name': 'John Driver',
          'rating': 4.5,
          'vehicle_type': 'moto',
          'distance': 2.5,
          'eta': 10,
          'vehicle_number': 'KGL001',
          'vehicle_color': 'Blue',
          'license_plate': 'RWA-001',
        };

        final driver = AvailableDriver.fromJson(json);
        expect(driver.id, 1);
        expect(driver.name, 'John Driver');
        expect(driver.rating, 4.5);
        expect(driver.vehicleType, 'moto');
        expect(driver.distance, 2.5);
        expect(driver.eta, 10);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 2,
          'name': 'Jane Driver',
          'rating': 0.0,
          'vehicle_type': 'car',
          'distance': 0.0,
          'eta': 0,
          'vehicle_number': '',
        };

        final driver = AvailableDriver.fromJson(json);
        expect(driver.vehicleColor, null);
        expect(driver.licensePlate, null);
      });
    });

    group('DriverMatchingResponse', () {
      test('returns hasAvailableDrivers true when drivers list not empty', () {
        final response = DriverMatchingResponse(
          drivers: [
            AvailableDriver(
              id: 1,
              name: 'Driver 1',
              rating: 4.0,
              vehicleType: 'car',
              distance: 1.0,
              eta: 5,
              vehicleNumber: 'ABC123',
            ),
          ],
          hasAvailableDrivers: true,
        );

        expect(response.hasAvailableDrivers, true);
        expect(response.isEmpty, false);
      });

      test('returns hasAvailableDrivers false when drivers list is empty', () {
        final response = DriverMatchingResponse(
          drivers: [],
          hasAvailableDrivers: false,
          noDriversReason: 'No drivers in your area',
        );

        expect(response.hasAvailableDrivers, false);
        expect(response.isEmpty, true);
        expect(response.getEmptyStateMessage(), 'No drivers in your area');
      });

      test(
        'returns default empty message when no drivers and no reason provided',
        () {
          final response = DriverMatchingResponse(
            drivers: [],
            hasAvailableDrivers: false,
          );

          expect(response.isEmpty, true);
          expect(
            response.getEmptyStateMessage(),
            'No drivers available at the moment. Please try again later.',
          );
        },
      );

      test('parses from JSON with drivers', () {
        final json = {
          'data': [
            {
              'id': 1,
              'name': 'Driver 1',
              'rating': 4.5,
              'vehicle_type': 'moto',
              'distance': 2.0,
              'eta': 8,
              'vehicle_number': 'ABC123',
            },
          ],
          'matching_session_id': 'session-123',
          'message': null,
        };

        final response = DriverMatchingResponse.fromJson(json);
        expect(response.drivers.length, 1);
        expect(response.drivers[0].name, 'Driver 1');
        expect(response.hasAvailableDrivers, true);
        expect(response.matchingSessionId, 'session-123');
      });

      test('parses from JSON with no drivers', () {
        final json = {
          'data': [],
          'message': 'No drivers available in this area',
        };

        final response = DriverMatchingResponse.fromJson(json);
        expect(response.drivers.length, 0);
        expect(response.hasAvailableDrivers, false);
        expect(response.noDriversReason, 'No drivers available in this area');
      });
    });

    group('MatchingSessionResponse', () {
      test('checks session expiration correctly', () {
        final futureTime = DateTime.now().add(const Duration(hours: 1));
        final response = MatchingSessionResponse(
          drivers: [],
          isActive: true,
          expiresAt: futureTime,
        );

        expect(response.isExpired, false);
      });

      test('detects expired sessions', () {
        final pastTime = DateTime.now().subtract(const Duration(hours: 1));
        final response = MatchingSessionResponse(
          drivers: [],
          isActive: true,
          expiresAt: pastTime,
        );

        expect(response.isExpired, true);
      });
    });

    group('Driver filtering and sorting', () {
      final drivers = [
        AvailableDriver(
          id: 1,
          name: 'Driver A',
          rating: 4.5,
          vehicleType: 'car',
          distance: 5.0,
          eta: 10,
          vehicleNumber: 'A123',
        ),
        AvailableDriver(
          id: 2,
          name: 'Driver B',
          rating: 3.0,
          vehicleType: 'car',
          distance: 2.0,
          eta: 5,
          vehicleNumber: 'B456',
        ),
        AvailableDriver(
          id: 3,
          name: 'Driver C',
          rating: 2.5,
          vehicleType: 'car',
          distance: 1.0,
          eta: 3,
          vehicleNumber: 'C789',
        ),
      ];

      test('filters drivers by rating', () {
        final service = DriverMatchingService(dio: MockDio() as dynamic);
        final filtered = service.filterByRating(drivers, minRating: 3.5);

        expect(filtered.length, 1);
        expect(filtered[0].name, 'Driver A');
      });

      test('sorts drivers by distance', () {
        final service = DriverMatchingService(dio: MockDio() as dynamic);
        final sorted = service.sortByDistance(drivers);

        expect(sorted[0].name, 'Driver C');
        expect(sorted[1].name, 'Driver B');
        expect(sorted[2].name, 'Driver A');
      });

      test('sorts drivers by ETA', () {
        final service = DriverMatchingService(dio: MockDio() as dynamic);
        final sorted = service.sortByEta(drivers);

        expect(sorted[0].name, 'Driver C');
        expect(sorted[1].name, 'Driver B');
        expect(sorted[2].name, 'Driver A');
      });

      test('returns best driver by distance and rating', () {
        final service = DriverMatchingService(dio: MockDio() as dynamic);
        final best = service.getBestDriver(drivers);

        // Should prefer closest driver (Driver C at 1.0 km)
        expect(best?.name, 'Driver C');
      });

      test('returns null for empty driver list', () {
        final service = DriverMatchingService(dio: MockDio() as dynamic);
        final best = service.getBestDriver([]);

        expect(best, null);
      });
    });
  });
}

class MockDio implements Dio {
  MockDio();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
