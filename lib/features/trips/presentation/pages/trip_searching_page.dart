import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';
import 'driver_arriving_page.dart';
import 'driver_matched_page.dart';
import 'live_trip_tracking_page.dart';
import 'trip_completion_page.dart';

class TripSearchingPage extends ConsumerWidget {
  const TripSearchingPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(tripTrackingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Search')),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => TripErrorView(
              message: error.toString(),
              onRetry:
                  () =>
                      ref.read(tripTrackingProvider(tripId).notifier).refresh(),
            ),
        data: (data) {
          final trip = data.trip;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (trip.status == TripStatus.matched ||
                trip.status == TripStatus.driverConfirmed) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DriverMatchedPage(tripId: trip.id),
                ),
              );
            } else if (trip.status == TripStatus.driverArriving) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DriverArrivingPage(tripId: trip.id),
                ),
              );
            } else if (trip.status == TripStatus.pickedUp ||
                trip.status == TripStatus.inProgress) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LiveTripTrackingPage(tripId: trip.id),
                ),
              );
            } else if (trip.status == TripStatus.completed) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripCompletionPage(tripId: trip.id),
                ),
              );
            }
          });
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ActiveTripCard(
              trip: trip,
              onCancel: () async {
                await ref
                    .read(tripRepositoryProvider)
                    .cancelPassengerTrip(trip.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
    );
  }
}
