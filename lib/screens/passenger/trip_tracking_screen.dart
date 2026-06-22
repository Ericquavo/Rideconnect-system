import 'package:flutter/material.dart';
import '../../features/trips/presentation/pages/live_trip_tracking_page.dart';

class TripTrackingScreen extends StatelessWidget {
  final int tripId;

  const TripTrackingScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return LiveTripTrackingPage(tripId: tripId);
  }
}
