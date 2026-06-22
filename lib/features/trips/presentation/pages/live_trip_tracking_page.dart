import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_error_view.dart';
import 'trip_completion_page.dart';
import 'trip_progress_page.dart';

class LiveTripTrackingPage extends ConsumerStatefulWidget {
  const LiveTripTrackingPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<LiveTripTrackingPage> createState() => _LiveTripTrackingPageState();
}

class _LiveTripTrackingPageState extends ConsumerState<LiveTripTrackingPage> {
  GoogleMapController? _mapController;
  bool _isStartingTrip = false;
  bool _autoPan = true;
  bool _showTimeoutWarning = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _showTimeoutWarning = false;
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showTimeoutWarning = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Emergency Assistance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to call emergency services (212)? This will initiate a call immediately.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri(scheme: 'tel', path: '212');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not place emergency call.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Call 212',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _updateViewport(LatLng driverPos, LatLng pickupPos) {
    if (_mapController == null || !_autoPan) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        driverPos.latitude < pickupPos.latitude ? driverPos.latitude : pickupPos.latitude,
        driverPos.longitude < pickupPos.longitude ? driverPos.longitude : pickupPos.longitude,
      ),
      northeast: LatLng(
        driverPos.latitude > pickupPos.latitude ? driverPos.latitude : pickupPos.latitude,
        driverPos.longitude > pickupPos.longitude ? driverPos.longitude : pickupPos.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80.0),
    );
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    await launchUrl(uri);
  }

  Future<void> _messageDriver(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'sms', path: phone.trim());
    await launchUrl(uri);
  }

  Future<void> _startTrip() async {
    if (_isStartingTrip) return;
    setState(() => _isStartingTrip = true);

    try {
      await ref.read(tripRepositoryProvider).startTripV3(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripProgressPage(tripId: widget.tripId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting trip: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingTrip = false);
      }
    }
  }

  String _getStatusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return 'Matching Driver';
      case TripStatus.matched:
        return 'Driver Assigned';
      case TripStatus.driverConfirmed:
        return 'Driver En Route';
      case TripStatus.driverArriving:
        return 'Driver Arrived';
      case TripStatus.pickedUp:
        return 'Waiting Passenger';
      case TripStatus.inProgress:
        return 'Trip In Progress';
      case TripStatus.completed:
        return 'Trip Completed';
      default:
        return status.name;
    }
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return Colors.orange;
      case TripStatus.matched:
        return Colors.blue;
      case TripStatus.driverConfirmed:
        return Colors.indigo;
      case TripStatus.driverArriving:
        return Colors.purple;
      case TripStatus.pickedUp:
        return Colors.amber;
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.completed:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(tripTrackingProvider(widget.tripId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return tracking.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Trip Tracking',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                const SizedBox(height: 24),
                if (_showTimeoutWarning) ...[
                  Text(
                    'Connecting to live tracking server...',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The server may be starting up (Render free tier spin-up can take up to a minute). Please wait or try again.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _startTimeoutTimer();
                      });
                      ref.invalidate(tripTrackingProvider(widget.tripId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Retry Connection', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ] else ...[
                  Text(
                    'Loading tracking details...',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: Text('Trip Tracking', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ),
        body: TripErrorView(
          message: e.toString(),
          onRetry: () {
            _startTimeoutTimer();
            ref.read(tripTrackingProvider(widget.tripId).notifier).refresh();
          },
        ),
      ),
      data: (data) {
        if (data.trip.status == TripStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripCompletionPage(tripId: widget.tripId),
                ),
              );
            }
          });
        }

        if (data.trip.status == TripStatus.inProgress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripProgressPage(tripId: widget.tripId),
                ),
              );
            }
          });
        }

        final markers = <Marker>{};
        final pickup = data.trip.pickup.latLng;
        final destination = data.trip.destination.latLng;
        final bool isTripStarted = data.trip.status == TripStatus.inProgress;

        if (isTripStarted) {
          // Trip started: show Driver and Destination markers (two separate markers)
          if (destination != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destination,
                infoWindow: const InfoWindow(title: 'Destination'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            );
          }
          if (data.driverLocation != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: data.driverLocation!,
                infoWindow: const InfoWindow(title: 'Driver Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                rotation: data.heading,
              ),
            );
          }
        } else {
          // Before Pickup: show Pickup and Driver markers (two separate markers)
          if (pickup != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('pickup'),
                position: pickup,
                infoWindow: const InfoWindow(title: 'Pickup Point'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Distinct Green Marker as per Reference Image
              ),
            );
          }
          if (data.driverLocation != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: data.driverLocation!,
                infoWindow: const InfoWindow(title: 'Driver Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                rotation: data.heading,
              ),
            );
          }
        }

        final initial = data.driverLocation ?? pickup ?? destination ?? const LatLng(-1.9441, 30.0619);

        // Update Map viewport automatically to keep driver and target (pickup or destination) visible
        final targetPos = isTripStarted ? destination : pickup;
        if (data.driverLocation != null && targetPos != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateViewport(data.driverLocation!, targetPos);
          });
        }

        final distanceVal = (data.driverLocation != null && targetPos != null)
            ? Geolocator.distanceBetween(
                data.driverLocation!.latitude,
                data.driverLocation!.longitude,
                targetPos.latitude,
                targetPos.longitude,
              )
            : null;

        // Arrival detection: check if within 50 meters
        final bool isArrived = !isTripStarted && distanceVal != null && distanceVal <= 50.0;
        final activeTripStatus = isArrived ? TripStatus.driverArriving : data.trip.status;

        final distanceKm = distanceVal != null ? (distanceVal / 1000).toStringAsFixed(1) : null;
        final etaMinutes = distanceVal != null ? ( (distanceVal / 1000) * 3 ).toStringAsFixed(0) : null;

        final displayDistance = data.distanceText.isNotEmpty 
            ? data.distanceText 
            : (distanceKm != null ? '$distanceKm km away' : null);
        final displayEta = data.etaText.isNotEmpty 
            ? data.etaText 
            : (etaMinutes != null ? 'ETA $etaMinutes mins' : null);

        // Progress percentage helper
        double progressPercentage = 0.0;
        if (activeTripStatus == TripStatus.inProgress) {
          progressPercentage = 100.0;
        } else if (activeTripStatus == TripStatus.driverArriving || activeTripStatus == TripStatus.pickedUp) {
          progressPercentage = 50.0;
        } else if (activeTripStatus == TripStatus.matched || activeTripStatus == TripStatus.driverConfirmed) {
          progressPercentage = 25.0;
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              // Google Map with traffic layer enabled
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: 15,
                  ),
                  markers: markers,
                  trafficEnabled: true,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polylines: {
                    if (isTripStarted) ...{
                      if (data.route.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: data.route,
                          color: Colors.green, // Active journey after pickup is Green
                          width: 6,
                        ),
                    } else ...{
                      if (data.driverToPickupRoute.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('driver_to_pickup'),
                          points: data.driverToPickupRoute,
                          color: Colors.blue, // Driver traveling to pickup is Blue
                          width: 6,
                        ),
                    }
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (data.driverLocation != null && pickup != null) {
                      _updateViewport(data.driverLocation!, pickup);
                    }
                  },
                ),
              ),

              // Custom Header Bar with Back Button
              Positioned(
                top: 48,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: IconButton(
                        icon: Icon(Icons.emergency_rounded, color: Colors.red),
                        onPressed: _showEmergencyDialog,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrival banner notification overlay
              if (isArrived)
                Positioned(
                  top: 110,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your driver has arrived.',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Modern Draggable Bottom Sheet
              Positioned.fill(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.32,
                  minChildSize: 0.20,
                  maxChildSize: 0.65,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4)),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Handlebar
                          Center(
                            child: Container(
                              width: 48,
                              height: 6,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black12,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                          // Driver / Vehicle Header Row
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFF6C63FF),
                                child: Icon(Icons.person, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.trip.driver?.name ?? 'Assigned Driver',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.orange, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          data.trip.driver?.rating != null ? data.trip.driver!.rating.toStringAsFixed(1) : '4.8',
                                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(activeTripStatus).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusLabel(activeTripStatus).toUpperCase(),
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(activeTripStatus)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Vertical Address Timeline Section
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.circle, color: Colors.blue, size: 12),
                                    Container(
                                      width: 2,
                                      height: 38,
                                      color: isDark ? Colors.white24 : Colors.black12,
                                    ),
                                    const Icon(Icons.circle, color: Colors.green, size: 12),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your pickup location',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      Text(
                                        data.trip.pickup.label,
                                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        activeTripStatus == TripStatus.inProgress
                                            ? 'Trip started'
                                            : (activeTripStatus == TripStatus.driverArriving || activeTripStatus == TripStatus.pickedUp
                                                ? 'Driver has arrived'
                                                : 'Driver is on the way'),
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      Text(
                                        activeTripStatus == TripStatus.inProgress
                                            ? 'Traveling to destination'
                                            : (activeTripStatus == TripStatus.driverArriving || activeTripStatus == TripStatus.pickedUp
                                                ? 'Waiting for passenger'
                                                : 'Heading to pickup · ${displayDistance ?? "--"}'),
                                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 20),

                          // Metrics Grid
                          GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildMetricTile('Distance', displayDistance ?? '--', Icons.directions, isDark),
                              _buildMetricTile('ETA', displayEta ?? '--', Icons.access_time_filled, isDark),
                              _buildMetricTile('Speed', '${data.speed.toStringAsFixed(0)} km/h', Icons.speed, isDark),
                              _buildMetricTile('Updated', _formatTime(data.updatedAt), Icons.cloud_done, isDark),
                            ],
                          ),
                          const Divider(height: 20),

                          // Trip Status Label Block
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trip Status',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStatusLabel(activeTripStatus),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _getStatusColor(activeTripStatus),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Progress Bar
                          Text(
                            'Route Progress: ${progressPercentage.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progressPercentage / 100.0,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            color: activeTripStatus == TripStatus.inProgress ? Colors.green : Colors.blue,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 24),

                          // Action Panel: Message / Call
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _messageDriver(data.trip.driver?.phone),
                                  icon: const Icon(Icons.message),
                                  label: const Text('Message'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _callDriver(data.trip.driver?.phone),
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Start Trip button (Visible/active ONLY when status is ACCEPTED)
                          if (activeTripStatus == TripStatus.driverConfirmed)
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: !_isStartingTrip ? _startTrip : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isStartingTrip
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        'START TRIP',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 28, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            Text(
              value,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      return '$hour:$min:$sec $period';
    } catch (_) {
      return 'Just now';
    }
  }
}
