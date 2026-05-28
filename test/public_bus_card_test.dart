import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideconnect_app/pages/passenger/public_bus_models.dart';
import 'package:rideconnect_app/pages/passenger/widgets/public_bus_card.dart';

void main() {
  testWidgets('PublicBusCard shows display name, driver, and select action', (
    WidgetTester tester,
  ) async {
    final assignment = PublicBusAssignment.fromJson({
      'assignment_id': 101,
      'bus_id': 88,
      'available_seats': 12,
      'eta_minutes': 7,
      'driver': {'name': 'John Doe', 'rating': 4.7},
      'bus': {'display_name': 'City Shuttle 12'},
      'next_stop': {'stop_name': 'Downtown'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicBusCard(
            assignment: assignment,
            selected: true,
            selectLabel: 'Select',
            selectedLabel: 'Selected',
            onSelect: () {},
            onDetails: () {},
          ),
        ),
      ),
    );

    expect(find.text('City Shuttle 12'), findsOneWidget);
    expect(find.text('John Doe · 4.7★'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('ETA 7'), findsOneWidget);
  });
}
