import 'package:flutter/material.dart';

import 'live_trip_tracking_page.dart';
import '../widgets/active_trip_card.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_error_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriverMatchedPage extends ConsumerWidget {
  const DriverMatchedPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(tripTrackingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Matched')),
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
