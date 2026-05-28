import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';
import 'live_trip_tracking_page.dart';

class DriverArrivingPage extends ConsumerWidget {
  const DriverArrivingPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(tripTrackingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Arriving')),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry:
                  () =>
                      ref.read(tripTrackingProvider(tripId).notifier).refresh(),
            ),
        data:
            (data) => Padding(
              padding: const EdgeInsets.all(16),
              child: ActiveTripCard(
                trip: data.trip,
                onTrack:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveTripTrackingPage(tripId: tripId),
                      ),
                    ),
              ),
            ),
      ),
    );
  }
}
