import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/passenger_api.dart';
import '../../features/trips/presentation/pages/location_picker_page.dart';

class MotorcycleRequestScreen extends StatefulWidget {
  const MotorcycleRequestScreen({super.key});

  @override
  State<MotorcycleRequestScreen> createState() => _MotorcycleRequestScreenState();
}

class _MotorcycleRequestScreenState extends State<MotorcycleRequestScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  bool _isRequesting = false;
  String? _error;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(bool isPickup) async {
    final initial = isPickup ? _pickupLatLng : _destinationLatLng;
    final title = isPickup ? 'Select Pickup Location' : 'Select Destination';
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialLocation: initial, title: title),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          _pickupLatLng = result.latlng;
          _pickupController.text = result.address;
        } else {
          _destinationLatLng = result.latlng;
          _destinationController.text = result.address;
        }
      });
    }
  }

  Future<void> _requestRide() async {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      setState(() {
        _error = 'Please select pickup and destination locations.';
      });
      return;
    }

    setState(() {
      _isRequesting = true;
      _error = null;
    });

    try {
      final response = await PassengerApi.instance.createMotorVehicleTrip(
        pickupLocation: _pickupController.text,
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        dropoffLocation: _destinationController.text,
        dropoffLat: _destinationLatLng!.latitude,
        dropoffLng: _destinationLatLng!.longitude,
      );

      if (mounted) {
        final tripData = response['data'] ?? response;
        final tripId = tripData['id'] ?? tripData['trip_id'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Motorcycle request sent!')),
        );

        Navigator.pushReplacementNamed(
          context,
          '/trip/searching/$tripId',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF131729) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Motorcycle',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Ride Quick on a Motorcycle',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Pickup Field
              GestureDetector(
                onTap: () => _pickLocation(true),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _pickupController,
                    decoration: InputDecoration(
                      labelText: 'Pickup Location',
                      prefixIcon: const Icon(Icons.my_location_rounded, color: Color(0xFFEA580C)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Destination Field
              GestureDetector(
                onTap: () => _pickLocation(false),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: 'Destination Location',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton.icon(
                onPressed: _isRequesting ? null : _requestRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.two_wheeler_rounded, color: Colors.white),
                label: Text(
                  _isRequesting ? 'Requesting...' : 'Request Ride Now',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
