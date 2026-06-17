// lib/screens/passenger/passenger_tracking_screen.dart
// Live tracking of trip with Firestore realtime updates (Riverpod-based)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service_v2.dart';
import '../../features/trips/presentation/providers/trip_realtime_notifier.dart';

class PassengerTrackingScreen extends ConsumerStatefulWidget {
  final TripModel trip;
  final String authToken;

  const PassengerTrackingScreen({
    super.key,
    required this.trip,
    required this.authToken,
  });

  @override
  ConsumerState<PassengerTrackingScreen> createState() =>
      _PassengerTrackingScreenState();
}

class _PassengerTrackingScreenState
    extends ConsumerState<PassengerTrackingScreen> {
  late TripModel _trip;
  LatLng? _driverLatLng;
  Map<String, dynamic>? _driverInfo;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  double get _progressValue {
    const steps = {
      'requested': 0.1,
      'assigning': 0.2,
      'accepted': 0.4,
      'enroute_to_pickup': 0.55,
      'arrived_at_pickup': 0.7,
      'in_progress': 0.85,
      'completed': 1.0,
    };
    return steps[_trip.status] ?? 0.0;
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Cancel Trip?'),
            content: const Text('Are you sure you want to cancel this trip?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Yes, Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await TripServiceV2(
          authToken: widget.authToken,
        ).cancelTrip(_trip.id, reason: 'passenger_cancelled');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Rate Your Trip'),
            content: const Text('How was your experience?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showCancelledDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Trip Cancelled'),
            content: const Text('Your trip has been cancelled.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the realtime provider for this trip
    final realtimeState = ref.watch(
      tripRealtimeNotifierProvider(widget.trip.id),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trip in Progress'), elevation: 0),
      body: realtimeState.when(
        data: (state) {
          // Update local state based on realtime events
          if (state.currentEvent != null) {
            switch (state.currentEvent!.event) {
              case 'DriverAssigned':
                final driverId =
                    state.currentEvent!.payload['driver_id'] as int?;
                if (driverId != null && _trip.driverId != driverId) {
                  _trip = _trip.copyWith(
                    status: 'assigned',
                    driverId: driverId,
                  );
                  _driverInfo = {
                    'driver_id': driverId,
                    'driver_name': state.currentEvent!.payload['driver_name'],
                  };
                }
                break;
              case 'DriverAccepted':
                _trip = _trip.copyWith(status: 'accepted');
                break;
              case 'DriverArrived':
                _trip = _trip.copyWith(status: 'driver_arrived');
                break;
              case 'TripStarted':
                _trip = _trip.copyWith(status: 'in_progress');
                break;
              case 'TripCompleted':
                _trip = _trip.copyWith(status: 'completed');
                Future.delayed(
                  const Duration(milliseconds: 500),
                  _showRatingDialog,
                );
                break;
              case 'TripCancelled':
                Future.delayed(
                  const Duration(milliseconds: 500),
                  _showCancelledDialog,
                );
                break;
            }
          }

          return Column(
            children: [
              Expanded(
                flex: 2,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target:
                        _driverLatLng ??
                        LatLng(_trip.pickupLat, _trip.pickupLng),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: {
                    if (_driverLatLng != null)
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: _driverLatLng!,
                        infoWindow: const InfoWindow(title: 'Driver'),
                      ),
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: LatLng(_trip.pickupLat, _trip.pickupLng),
                      infoWindow: const InfoWindow(title: 'Pickup'),
                    ),
                    Marker(
                      markerId: const MarkerId('dropoff'),
                      position: LatLng(_trip.dropoffLat, _trip.dropoffLng),
                      infoWindow: const InfoWindow(title: 'Dropoff'),
                    ),
                  },
                ),
              ),
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: _progressValue),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _trip.statusLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (!state.isConnected)
                            Chip(
                              label: const Text('⚠ Offline'),
                              backgroundColor: Colors.orange[100],
                              labelStyle: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_trip.transportIcon} Transport'),
                                Text(
                                  _trip.transportType?.toUpperCase() ?? 'CAR',
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fare'),
                                Text(_trip.fareDisplay),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Driver'),
                                Text(_driverInfo?['driver_name'] ?? '—'),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('License Plate'),
                                Text(_driverInfo?['license_plate'] ?? '—'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_trip.canCancel)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: _cancelTrip,
                            child: const Text(
                              'Cancel Trip',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading realtime data'),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
