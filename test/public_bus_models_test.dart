import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rideconnect_app/pages/passenger/public_bus_models.dart';

void main() {
  test('PublicBusAssignment parses nested bus assignment fields', () {
    final assignment = PublicBusAssignment.fromJson({
      'assignment_id': 101,
      'bus_id': 88,
      'available_seats': 12,
      'eta_minutes': 7,
      'driver': {
        'id': 9,
        'name': 'John Doe',
        'rating': 4.7,
        'availability_status': 'online',
      },
      'bus': {
        'display_name': 'City Shuttle 12',
        'photo_url': 'https://example.com/bus.png',
      },
      'latest_position': {
        'latitude': -1.95,
        'longitude': 30.06,
        'route_progress_percent': 66,
      },
      'next_stop': {'stop_name': 'Downtown'},
      'score': 0.88,
      'demand_index': 0.32,
    });

    expect(assignment.assignmentId, 101);
    expect(assignment.busId, 88);
    expect(assignment.driverSummary, 'John Doe · 4.7★');
    expect(assignment.title, 'City Shuttle 12');
    expect(assignment.availableSeats, 12);
    expect(assignment.etaLabel, '7');
    expect(assignment.footerSummary, 'Downtown');
    expect(assignment.mapPoint, const LatLng(-1.95, 30.06));
  });

  test('PublicBusBookingRequest omits bus assignment when absent', () {
    final payload =
        PublicBusBookingRequest(
          corridorId: 3,
          boardingStopId: 11,
          destinationStopId: 12,
          seatsReserved: 2,
        ).toJson();

    expect(payload, {
      'corridor_id': 3,
      'boarding_stop_id': 11,
      'destination_stop_id': 12,
      'seats_reserved': 2,
    });
  });

  test('PublicBusBookingRequest includes selected bus assignment', () {
    final payload =
        PublicBusBookingRequest(
          corridorId: 3,
          boardingStopId: 11,
          destinationStopId: 12,
          seatsReserved: 2,
          busRouteAssignmentId: 101,
        ).toJson();

    expect(payload['bus_route_assignment_id'], 101);
  });

  test('Public bus error codes map to friendly text', () {
    expect(
      publicBusErrorMessage('BUS_SELECTION_INVALID'),
      'Selected bus is no longer available. Please select another bus.',
    );
    expect(
      publicBusErrorMessage('INSUFFICIENT_BUS_CAPACITY'),
      'Selected bus doesn\'t have enough seats. Select a different bus or reduce seats.',
    );
    expect(
      publicBusErrorMessage('NO_BOOKABLE_BUS'),
      'No available buses currently. Try again later.',
    );
  });
}
