import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import 'trip_payment_page.dart';

class TripProgressPage extends ConsumerStatefulWidget {
  const TripProgressPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripProgressPage> createState() => _TripProgressPageState();
}

class _TripProgressPageState extends ConsumerState<TripProgressPage> {
  GoogleMapController? _mapController;
  LatLng? _currentPassengerLocation;
  StreamSubscription<Position>? _positionStream;
  List<LatLng> _routePoints = [];
  bool _isEndingTrip = false;
  double _distanceRemaining = 0.0;
  int _etaMinutes = 0;
  Timer? _routeRefreshTimer;
  Trip? _tripDetails;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartTracking();
    _fetchTripDetails();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _updateRouteAndETA());
  }

  Future<void> _fetchTripDetails() async {
    try {
      final trip = await ref.read(tripRepositoryProvider).passengerTrip(widget.tripId);
      setState(() {
        _tripDetails = trip;
      });
      _updateRouteAndETA();
    } catch (e) {
      debugPrint('[TripProgressPage] Error fetching trip details: $e');
    }
  }

  Future<void> _checkPermissionAndStartTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPassengerLocation = LatLng(position.latitude, position.longitude);
      });
      _updateRouteAndETA();

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position pos) {
        if (mounted) {
          setState(() {
            _currentPassengerLocation = LatLng(pos.latitude, pos.longitude);
          });
          _updateRouteAndETA();
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(_currentPassengerLocation!),
            );
          }
        }
      });
    }
  }

  Future<void> _updateRouteAndETA() async {
    if (_currentPassengerLocation == null || _tripDetails == null) return;
    final dest = _tripDetails!.destination.latLng;
    if (dest == null) return;

    // Calculate distance and approximate ETA
    final distMeters = Geolocator.distanceBetween(
      _currentPassengerLocation!.latitude,
      _currentPassengerLocation!.longitude,
      dest.latitude,
      dest.longitude,
    );

    setState(() {
      _distanceRemaining = distMeters / 1000.0;
      _etaMinutes = ((distMeters / 1000.0) * 3).round(); // Assume 3 min per km average
    });

    // Request computed polyline route
    try {
      final points = await ref.read(tripRepositoryProvider).computeRoute(_currentPassengerLocation!, dest);
      if (mounted && points.isNotEmpty) {
        setState(() {
          _routePoints = points;
        });
      }
    } catch (e) {
      debugPrint('[TripProgressPage] Route fetch error: $e');
    }
  }

  Future<void> _endTrip() async {
    if (_isEndingTrip) return;
    setState(() => _isEndingTrip = true);

    try {
      // Call /api/v3/trips/{tripId}/complete with fallback
      try {
        await ref.read(apiClientProvider).post('/v3/trips/${widget.tripId}/complete');
      } catch (_) {
        await ref.read(apiClientProvider).put('/v3/trips/${widget.tripId}/complete');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip completed! Redirecting to payment...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripPaymentPage(tripId: widget.tripId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending trip: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEndingTrip = false);
      }
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Emergency SOS',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          'This will dial the emergency services at 112. Are you sure you want to call now?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri(scheme: 'tel', path: '112');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Call 112', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _routeRefreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialTarget = _currentPassengerLocation ?? _tripDetails?.pickup.latLng ?? const LatLng(-1.9441, 30.0619);

    final markers = <Marker>{
      if (_currentPassengerLocation != null)
        Marker(
          markerId: const MarkerId('passenger_live'),
          position: _currentPassengerLocation!,
          infoWindow: const InfoWindow(title: 'My Position'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      if (_tripDetails?.destination.latLng != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: _tripDetails!.destination.latLng!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 15,
              ),
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              polylines: {
                if (_routePoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('yellow_route'),
                    points: _routePoints,
                    color: Colors.yellow, // Highlighted clearly in yellow
                    width: 6,
                  ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Custom Header Bar with Emergency Call Button
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Text(
                    'Trip Progress',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.emergency, color: Colors.white),
                    onPressed: _showEmergencyDialog,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'IN PROGRESS',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Updated: Just now',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ETA', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          Text(
                            _etaMinutes > 0 ? '$_etaMinutes mins' : 'Arriving',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Distance Remaining', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${_distanceRemaining.toStringAsFixed(1)} km',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isEndingTrip ? null : _endTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isEndingTrip
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'END TRIP',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
