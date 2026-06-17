import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/trip_provider.dart';
import '../../providers/location_provider.dart';
import '../../core/constants/app_constants.dart';

/// Screen for creating and managing book trips
class BookingScreen extends ConsumerStatefulWidget {
  final String transportType; // 'PUBLIC_BUS' or 'MOTORCYCLE'

  const BookingScreen({super.key, required this.transportType});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late TextEditingController _pickupController;
  late TextEditingController _dropoffController;
  late GoogleMapController _mapController;

  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController();
    _dropoffController = TextEditingController();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleCreateTrip() async {
    if (_pickupLocation == null || _dropoffLocation == null) {
      _showError('Please select both pickup and dropoff locations');
      return;
    }

    try {
      final tripState = ref.read(tripStateProvider.notifier);

      final tripId =
          widget.transportType == AppConstants.transportTypePublicBus
              ? await tripState.createPublicBusTrip(
                pickupLocation: _pickupController.text,
                dropoffLocation: _dropoffController.text,
                pickupLat: _pickupLocation!.latitude,
                pickupLng: _pickupLocation!.longitude,
                dropoffLat: _dropoffLocation!.latitude,
                dropoffLng: _dropoffLocation!.longitude,
              )
              : await tripState.createMotorcycleTrip(
                pickupLocation: _pickupController.text,
                dropoffLocation: _dropoffController.text,
                pickupLat: _pickupLocation!.latitude,
                pickupLng: _pickupLocation!.longitude,
                dropoffLat: _dropoffLocation!.latitude,
                dropoffLng: _dropoffLocation!.longitude,
              );

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/tracking', arguments: tripId);
      }
    } catch (e) {
      _showError('Failed to create trip: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLocationPicker(String locationType) {
    // This is a placeholder - in production, use a proper place picker
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select $locationType Location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter address or tap on map',
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Select'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transportType == AppConstants.transportTypePublicBus
              ? 'Book Public Bus'
              : 'Book Motorcycle',
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map Preview
            SizedBox(
              height: 300,
              child: currentLocation.when(
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
                data:
                    (location) => GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target:
                            location != null
                                ? LatLng(location.latitude, location.longitude)
                                : const LatLng(-1.9536, 29.8739),
                        zoom: 15,
                      ),
                      markers: {
                        if (_pickupLocation != null)
                          Marker(
                            markerId: const MarkerId('pickup'),
                            position: _pickupLocation!,
                            infoWindow: const InfoWindow(title: 'Pickup'),
                          ),
                        if (_dropoffLocation != null)
                          Marker(
                            markerId: const MarkerId('dropoff'),
                            position: _dropoffLocation!,
                            infoWindow: const InfoWindow(title: 'Dropoff'),
                          ),
                      },
                      onTap: (latLng) {
                        setState(() {
                          if (_pickupLocation == null) {
                            _pickupLocation = latLng;
                            _pickupController.text =
                                '${latLng.latitude}, ${latLng.longitude}';
                          } else if (_dropoffLocation == null) {
                            _dropoffLocation = latLng;
                            _dropoffController.text =
                                '${latLng.latitude}, ${latLng.longitude}';
                          }
                        });
                      },
                    ),
              ),
            ),
            // Location Selection
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup Location
                  Text(
                    'Pickup Location',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pickupController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Tap on map to select',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onTap: () => _showLocationPicker('Pickup'),
                  ),
                  const SizedBox(height: 16),
                  // Dropoff Location
                  Text(
                    'Dropoff Location',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dropoffController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Tap on map to select',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onTap: () => _showLocationPicker('Dropoff'),
                  ),
                  const SizedBox(height: 24),
                  // Request Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _handleCreateTrip,
                      icon: const Icon(Icons.directions_car),
                      label: Text(
                        'Request ${widget.transportType == AppConstants.transportTypePublicBus ? 'Bus' : 'Motorcycle'}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
