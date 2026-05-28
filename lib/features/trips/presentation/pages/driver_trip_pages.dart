import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';

class IncomingTripRequestPage extends ConsumerWidget {
  const IncomingTripRequestPage({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingDriverTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Trips')),
      body:
          !isOnline
              ? const Center(child: Text('Go online to receive trip requests.'))
              : requests.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, _) => TripErrorView(
                      message: e.toString(),
                      onRetry:
                          () => ref.invalidate(incomingDriverTripsProvider),
                    ),
                data:
                    (items) => RefreshIndicator(
                      onRefresh:
                          () async =>
                              ref.invalidate(incomingDriverTripsProvider),
                      child:
                          items.isEmpty
                              ? ListView(
                                children: const [
                                  SizedBox(
                                    height: 300,
                                    child: Center(
                                      child: Text('No incoming trips.'),
                                    ),
                                  ),
                                ],
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final trip = items[index];
                                  return ActiveTripCard(
                                    trip: trip,
                                    onCancel: () async {
                                      await ref
                                          .read(tripRepositoryProvider)
                                          .rejectDriverTrip(trip.id);
                                      ref.invalidate(
                                        incomingDriverTripsProvider,
                                      );
                                    },
                                    onPrimaryAction: () async {
                                      final accepted = await ref
                                          .read(tripRepositoryProvider)
                                          .acceptDriverTrip(trip.id);
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => DriverNavigationPage(
                                                trip: accepted,
                                              ),
                                        ),
                                      );
                                    },
                                    primaryLabel: 'Accept',
                                  );
                                },
                              ),
                    ),
              ),
    );
  }
}

class DriverNavigationPage extends ConsumerStatefulWidget {
  const DriverNavigationPage({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<DriverNavigationPage> createState() =>
      _DriverNavigationPageState();
}

class _DriverNavigationPageState extends ConsumerState<DriverNavigationPage> {
  bool _streaming = false;

  Future<void> _uploadLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    await ref
        .read(tripRepositoryProvider)
        .uploadDriverLocation(
          tripId: widget.trip.id,
          position: LatLng(position.latitude, position.longitude),
          heading: position.heading,
          speed: position.speed,
        );
    if (mounted) setState(() => _streaming = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Navigation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ActiveTripCard(trip: widget.trip),
          ElevatedButton.icon(
            onPressed: _uploadLocation,
            icon: const Icon(Icons.near_me_rounded),
            label: Text(_streaming ? 'Location synced' : 'Sync live location'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupConfirmationPage(trip: widget.trip),
                  ),
                ),
            icon: const Icon(Icons.person_pin_circle_rounded),
            label: const Text('Confirm pickup'),
          ),
        ],
      ),
    );
  }
}

class PickupConfirmationPage extends ConsumerWidget {
  const PickupConfirmationPage({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Confirmation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ActiveTripCard(
          trip: trip,
          onPrimaryAction: () async {
            final started = await ref
                .read(tripRepositoryProvider)
                .startDriverTrip(trip.id);
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ActiveTripPage(trip: started)),
            );
          },
          primaryLabel: 'Start Trip',
        ),
      ),
    );
  }
}

class ActiveTripPage extends ConsumerWidget {
  const ActiveTripPage({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ActiveTripCard(
          trip: trip,
          onPrimaryAction: () async {
            await ref.read(tripRepositoryProvider).completeDriverTrip(trip.id);
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          primaryLabel: 'Complete Trip',
        ),
      ),
    );
  }
}

class DriverTripHistoryPage extends ConsumerWidget {
  const DriverTripHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(driverTripHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(driverTripHistoryProvider),
            ),
        data:
            (items) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(driverTripHistoryProvider),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children:
                    items.map((trip) => ActiveTripCard(trip: trip)).toList(),
              ),
            ),
      ),
    );
  }
}

class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(driverEarningsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: earnings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(driverEarningsProvider),
            ),
        data:
            (data) => ListView(
              padding: const EdgeInsets.all(16),
              children:
                  data.entries
                      .map(
                        (entry) => ListTile(
                          title: Text(entry.key),
                          trailing: Text('${entry.value}'),
                        ),
                      )
                      .toList(),
            ),
      ),
    );
  }
}
