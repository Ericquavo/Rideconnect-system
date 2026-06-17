import 'package:flutter_test/flutter_test.dart';
import 'package:rideconnect_app/features/trips/domain/matching_lifecycle_models.dart';
import 'package:rideconnect_app/features/trips/domain/trip_models.dart';

void main() {
  test('parses motor vehicle trip request SEARCHING response', () {
    final snapshot = MatchingLifecycleSnapshot.fromJson({
      'success': true,
      'trip_id': 5,
      'status': 'MATCHING',
      'matching_status': 'SEARCHING',
      'message': 'Finding a driver... We will keep searching.',
      'estimated_fare': 3610,
      'fare_breakdown': {
        'base_fare': 500,
        'distance_cost': 2670,
        'time_cost': 440,
        'total': 3610,
      },
      'fare_details': {
        'distance_km': 8.9,
        'duration_minutes': 22,
        'currency': 'RWF',
        'cached': false,
        'fallback': true,
      },
    });

    expect(snapshot.status, MatchingLifecycleStatus.searchingCandidates);
    expect(snapshot.message, 'Finding a driver... We will keep searching.');
    expect(snapshot.trip?.id, 5);
    expect(snapshot.trip?.status, TripStatus.matched);
    expect(snapshot.trip?.fare, 3610);
  });

  test('maps motorcycle lifecycle statuses to progress steps', () {
    expect(
      MatchingLifecycleStatusX.parse('DRIVER_ASSIGNED'),
      MatchingLifecycleStatus.driverSelected,
    );
    expect(
      MatchingLifecycleStatusX.parse('PASSENGER_WAITING'),
      MatchingLifecycleStatus.driverAcknowledged,
    );
    expect(
      MatchingLifecycleStatusX.parse('DRIVER_ARRIVED'),
      MatchingLifecycleStatus.pickedUp,
    );
    expect(
      MatchingLifecycleStatusX.parse('IN_PROGRESS'),
      MatchingLifecycleStatus.inProgress,
    );
  });

  test('parses tracking response as assigned lifecycle snapshot', () {
    final snapshot = MatchingLifecycleSnapshot.fromTrackingEnvelope({
      'success': true,
      'data': {
        'trip': {
          'id': 15,
          'status': 'DRIVER_ASSIGNED',
          'pickup_location': 'Kimironko Market',
          'dropoff_location': 'Nyabugogo',
          'fare': 3610,
          'driver': {'id': 7, 'name': 'John Doe', 'rating': 4.8},
          'vehicle': {'plate_number': 'RAB123A', 'type': 'MOTORCYCLE'},
        },
        'eta_minutes': 5,
        'message': 'Driver assigned',
      },
    });

    expect(snapshot.status, MatchingLifecycleStatus.driverSelected);
    expect(snapshot.trip?.id, 15);
    expect(snapshot.trip?.driver?.name, 'John Doe');
    expect(snapshot.selectedDriver?.driverName, 'John Doe');
    expect(snapshot.trip?.vehicle?.plateNumber, 'RAB123A');
  });
}
