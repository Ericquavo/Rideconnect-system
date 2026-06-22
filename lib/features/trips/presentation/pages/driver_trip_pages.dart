import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';
import '../../../../ui/driver/driver_match_modal.dart';
import '../../../../repositories/auth_repository.dart';
import 'trip_progress_page.dart';



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
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Trip #${trip.id}',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Chip(
                                                label: Text(trip.status.label.toUpperCase()),
                                                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                                                labelStyle: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              const Icon(Icons.circle, color: Colors.green, size: 14),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  trip.pickup.label,
                                                  style: GoogleFonts.poppins(fontSize: 13),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, color: Colors.red, size: 14),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  trip.destination.label,
                                                  style: GoogleFonts.poppins(fontSize: 13),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => TripProgressPage(tripId: trip.id),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.map, size: 18),
                                                  label: const Text('TRACK TRIP'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    try {
                                                      await ref.read(tripRepositoryProvider).markDriverArrivedV3(trip.id);
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Arrived at pickup location.'),
                                                            backgroundColor: Colors.green,
                                                          ),
                                                        );
                                                        ref.invalidate(incomingDriverTripsProvider);
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Error updating status: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(Icons.check_circle, size: 18),
                                                  label: const Text('MARK AS ARRIVED'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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

  Map<String, dynamic> _extractEarningsMap(Map<String, dynamic> raw) {
    final data = raw['data'] ?? raw['earnings'] ?? raw;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(driverEarningsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Earnings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: earnings.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(driverEarningsProvider),
            ),
        data: (data) {
          final earningsMap = _extractEarningsMap(data);
          
          // Filter out technical fields like success/message/etc if any got through
          final filtered = Map<String, dynamic>.from(earningsMap)
            ..removeWhere((k, v) => k == 'success' || k == 'message' || k == 'status' || v is Map || v is List);

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No earnings statistics available.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: filtered.entries.map((entry) {
              final title = entry.key
                  .split('_')
                  .map((word) => word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1)}'
                      : '')
                  .join(' ');

              // Format value: if numeric, format nicely, else keep as string
              var valStr = entry.value.toString();
              if (entry.value is num) {
                final doubleVal = (entry.value as num).toDouble();
                valStr = '\$${doubleVal.toStringAsFixed(2)}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        valStr,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
