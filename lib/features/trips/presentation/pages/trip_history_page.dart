import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';
import 'live_trip_tracking_page.dart';
import 'trip_details_page.dart';

class TripHistoryPage extends ConsumerWidget {
  const TripHistoryPage({super.key, this.bookingSuccessNonce = 0});

  final int bookingSuccessNonce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(passengerTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(passengerTripsProvider),
            ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(passengerTripsProvider),
              child: ListView(
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: Text('No trips yet.')),
                  ),
                ],
              ),
            );
          }
          final active = items.where((trip) => trip.isActive).toList();
          final history = items.where((trip) => !trip.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(passengerTripsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) const _SectionLabel('Active Trips'),
                ...active.map(
                  (trip) => ActiveTripCard(
                    trip: trip,
                    onTrack:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => LiveTripTrackingPage(tripId: trip.id),
                          ),
                        ),
                    onCancel: () async {
                      await ref
                          .read(tripRepositoryProvider)
                          .cancelPassengerTrip(trip.id);
                      ref.invalidate(passengerTripsProvider);
                    },
                  ),
                ),
                const _SectionLabel('Trip History'),
                ...history.map(
                  (trip) => ActiveTripCard(
                    trip: trip,
                    onTrack:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripDetailsPage(tripId: trip.id),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
