import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';

class TripDetailsPage extends ConsumerWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(tripTrackingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: Text('Trip #$tripId')),
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
            (data) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ActiveTripCard(trip: data.trip),
                ListTile(
                  leading: const Icon(Icons.payment_rounded),
                  title: const Text('Payment'),
                  subtitle: Text(
                    data.trip.paymentStatus.isEmpty
                        ? 'Pending'
                        : data.trip.paymentStatus,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.route_rounded),
                  title: const Text('Route checkpoints'),
                  subtitle: Text(
                    '${data.route.length} backend route points synced',
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
