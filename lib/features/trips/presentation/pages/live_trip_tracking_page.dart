import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/trip_error_view.dart';
import 'emergency_support_page.dart';
import 'trip_completion_page.dart';

class LiveTripTrackingPage extends ConsumerWidget {
  const LiveTripTrackingPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(tripTrackingProvider(tripId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Tracking'),
        actions: [
          IconButton(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmergencySupportPage(tripId: tripId),
                  ),
                ),
            icon: const Icon(Icons.emergency_rounded),
          ),
        ],
      ),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry:
                  () =>
                      ref.read(tripTrackingProvider(tripId).notifier).refresh(),
            ),
        data: (data) {
          if (data.trip.status == TripStatus.completed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => TripCompletionPage(tripId: tripId),
                  ),
                );
              }
            });
          }
          final markers = <Marker>{};
          final pickup = data.trip.pickup.latLng;
          final destination = data.trip.destination.latLng;
          if (pickup != null) {
            markers.add(
              Marker(markerId: const MarkerId('pickup'), position: pickup),
            );
          }
          if (destination != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destination,
              ),
            );
          }
          if (data.driverLocation != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: data.driverLocation!,
              ),
            );
          }
          final initial =
              data.driverLocation ??
              pickup ??
              destination ??
              const LatLng(-1.9441, 30.0619);
          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: {
                    if (data.route.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: data.route,
                        color: const Color(0xFF4C57D6),
                        width: 5,
                      ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ActiveTripCard(trip: data.trip),
              ),
            ],
          );
        },
      ),
    );
  }
}
