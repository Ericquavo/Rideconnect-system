// lib/screens/driver/driver_active_trip_screen.dart
// Active trip management with status transitions and GPS tracking

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service_v2.dart';
import '../../core/services/rtdb_service.dart';

class DriverActiveTripScreen extends StatefulWidget {
  final TripModel trip;
  final String authToken;

  const DriverActiveTripScreen({
    super.key,
    required this.trip,
    required this.authToken,
  });

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen> {
  late TripModel _trip;
  GoogleMapController? _mapController;
  Timer? _locationTimer;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // 1. Update backend via API
        final service = TripServiceV2(authToken: widget.authToken);
        service.updateDriverLocation(
          tripId: _trip.id,
          latitude: pos.latitude,
          longitude: pos.longitude,
          speedKmh: pos.speed * 3.6,
          heading: pos.heading,
          accuracy: pos.accuracy,
        ).catchError((_) {});

        // 2. Direct fast-path updates to RTDB
        final rtdb = RTDBService();
        final driverIdStr = _trip.driverId?.toString() ?? 'unknown';

        if (_trip.driverId != null) {
          rtdb.updateDriverLocation(
            driverIdStr,
            lat: pos.latitude,
            lng: pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
          ).catchError((_) {});
        }

        rtdb.ref('trip_tracking/${_trip.id}').set({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'updated_at': ServerValue.timestamp,
        }).catchError((_) {});

      } catch (_) {
        // Non-fatal error in location tracking
      }
    });
  }

  Map<String, Map<String, String>> get _statusAction {
    return {
      'ACCEPTED': {'label': "I've Arrived", 'action': 'arrived', 'next': 'PASSENGER_WAITING'},
      'PASSENGER_WAITING': {'label': 'Start Trip', 'action': 'start', 'next': 'IN_PROGRESS'},
      'IN_PROGRESS': {'label': 'Complete Trip ✓', 'action': 'complete', 'next': 'COMPLETED'},
      // Fallback for lowercase
      'accepted': {'label': "I've Arrived", 'action': 'arrived', 'next': 'PASSENGER_WAITING'},
      'passenger_waiting': {'label': 'Start Trip', 'action': 'start', 'next': 'IN_PROGRESS'},
      'in_progress': {'label': 'Complete Trip ✓', 'action': 'complete', 'next': 'COMPLETED'},
    };
  }

  Future<void> _advanceStatus() async {
    final action = _statusAction[_trip.status];
    if (action == null) return;

    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final service = TripServiceV2(authToken: widget.authToken);
      final act = action['action'];

      if (act == 'arrived') {
        await service.arriveTrip(_trip.id);
      } else if (act == 'start') {
        await service.startTrip(_trip.id);
      } else if (act == 'complete') {
        await service.completeTrip(_trip.id);
      } else {
        await service.updateTripStatus(tripId: _trip.id, status: action['next']!);
      }

      setState(() {
        _trip = _trip.copyWith(status: action['next']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status updated'),
          backgroundColor: Colors.green,
        ),
      );

      if (action['next'] == 'COMPLETED' || action['next'] == 'completed') {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _statusAction[_trip.status];

    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back navigation
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Trip #${_trip.id}'),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_trip.pickupLat, _trip.pickupLng),
                  zoom: 15,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: {
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trip.statusLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.blue[900]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Fare:'),
                              Text(_trip.fareDisplay),
                            ],
                          ),
                          const Divider(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📍 Pickup:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(_trip.pickupLocation),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🏁 Dropoff:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(_trip.dropoffLocation),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (action != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isUpdatingStatus ? null : _advanceStatus,
                          child:
                              _isUpdatingStatus
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    action['label']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
