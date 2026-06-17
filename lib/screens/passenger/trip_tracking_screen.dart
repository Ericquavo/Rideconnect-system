import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/trip_model.dart';
import '../../providers/trip_provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';

/// Screen for real-time trip tracking
class TripTrackingScreen extends ConsumerStatefulWidget {
  final int tripId;

  const TripTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen> {
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    // Load route on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripState = ref.read(tripStateProvider);
      tripState.whenData((trip) {
        if (trip != null) {
          ref
              .read(mapStateProvider.notifier)
              .loadRoute(
                pickupLat: trip.pickupLat,
                pickupLng: trip.pickupLng,
                dropoffLat: trip.dropoffLat,
                dropoffLng: trip.dropoffLng,
              );
        }
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _cancelTrip() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Trip?'),
            content: const Text('Are you sure you want to cancel this trip?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(apiRepositoryProvider)
                        .cancelMotorcycleTrip(
                          widget.tripId,
                          'Passenger cancelled',
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Trip cancelled')),
                      );
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripStatusStream = ref.watch(
      tripStatusPollingProvider(widget.tripId),
    );
    final mapState = ref.watch(mapStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Tracking'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTripDetails(),
          ),
        ],
      ),
      body: tripStatusStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, st) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
        data: (tripStatus) {
          if (tripStatus.tripDetails == null) {
            return const Center(child: Text('Trip details unavailable'));
          }

          final tripDetails = tripStatus.tripDetails!;
          final driver = tripDetails.driver;

          return Stack(
            children: [
              // Map
              mapState.when(
                loading:
                    () => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                error:
                    (error, st) => Container(
                      color: Colors.red[50],
                      child: Center(child: Text('Map error: $error')),
                    ),
                data: (mapData) {
                  final markers = mapData['markers'] as Set<Marker>? ?? {};
                  final polylines =
                      mapData['polylines'] as Set<Polyline>? ?? {};

                  return GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-1.9536, 29.8739),
                      zoom: 15,
                    ),
                    markers: markers,
                    polylines: polylines,
                  );
                },
              ),
              // Bottom Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildTripPanel(tripDetails, driver),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cancelTrip,
        backgroundColor: Colors.red,
        child: const Icon(Icons.close),
      ),
    );
  }

  Widget _buildTripPanel(TripDetails tripDetails, DriverInfo? driver) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(tripDetails.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tripDetails.status,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Driver Info
            if (driver != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        driver.profilePictureUrl != null
                            ? NetworkImage(driver.profilePictureUrl!)
                            : null,
                    child:
                        driver.profilePictureUrl == null
                            ? const Icon(Icons.person)
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${driver.rating ?? 'N/A'}',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              driver.vehiclePlate ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone),
                    onPressed: () {
                      // Implement call driver
                    },
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Finding driver...'),
              ),
            const SizedBox(height: 16),
            // Trip Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tripDetails.pickupLocation,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dropoff',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tripDetails.dropoffLocation,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fare and Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Fare',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'RWF ${tripDetails.fare?.toStringAsFixed(0) ?? '---'}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Distance',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${tripDetails.distance?.toStringAsFixed(1) ?? '---'} km',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'MATCHING':
        return Colors.orange;
      case 'DRIVER_ASSIGNED':
      case 'PASSENGER_WAITING':
        return Colors.blue;
      case 'DRIVER_ARRIVED':
        return Colors.indigo;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showTripDetails() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Details',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Trip ID: ${widget.tripId}'),
                const SizedBox(height: 8),
                Text('Status: Tracking...'),
              ],
            ),
          ),
    );
  }
}
