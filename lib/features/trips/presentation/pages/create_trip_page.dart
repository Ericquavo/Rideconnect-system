import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import 'matching_lifecycle_pages.dart';
import 'trip_searching_page.dart';
import 'location_picker_page.dart';
import '../../../../pages/passenger/public_bus_booking_page.dart';

class CreateTripPage extends ConsumerStatefulWidget {
  const CreateTripPage({super.key, this.onTripCreated});

  final VoidCallback? onTripCreated;

  @override
  ConsumerState<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends ConsumerState<CreateTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  String _vehicleType = 'CAR';
  String _tripType = 'private';
  String _scheduleMode = 'immediate';
  String _paymentMethod = 'cash';
  int _seatCount = 1;
  DateTime? _departureTime;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () => _error = 'Location permission is required for pickup detection.',
      );
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _pickupLatLng = LatLng(position.latitude, position.longitude);
      _pickupController.text = 'Current location';
    });
  }

  Future<void> _openPickupLocationPicker() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder:
            (_) => LocationPickerPage(
              initialLocation: _pickupLatLng,
              title: 'Select Pickup Location',
            ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickupLatLng = result.latlng;
        _pickupController.text = result.address;
      });
    }
  }

  Future<void> _openDestinationLocationPicker() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder:
            (_) => LocationPickerPage(
              initialLocation: _destinationLatLng,
              title: 'Select Destination',
            ),
      ),
    );
    if (result != null) {
      setState(() {
        _destinationLatLng = result.latlng;
        _destinationController.text = result.address;
      });
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _departureTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _scheduleMode = 'scheduled';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that coordinates are actually set
    if (_pickupLatLng == null) {
      setState(
        () => _error = 'Please select a valid pickup location from the map.',
      );
      return;
    }
    if (_destinationLatLng == null) {
      setState(
        () =>
            _error = 'Please select a valid destination location from the map.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Step 1: Find available drivers first
      print('[CreateTripPage] Step 1: Matching drivers...');
      final matchingSession = await ref
          .read(tripRepositoryProvider)
          .matchPassengerDrivers(
            transportType: _vehicleType,
            pickupLat: _pickupLatLng!.latitude,
            pickupLng: _pickupLatLng!.longitude,
            dropoffLat: _destinationLatLng!.latitude,
            dropoffLng: _destinationLatLng!.longitude,
          );

      if (matchingSession.drivers.isEmpty) {
        setState(
          () =>
              _error =
                  'No available drivers found for this route. Please try again.',
        );
        return;
      }

      print('[CreateTripPage] Found ${matchingSession.drivers.length} drivers');

      // Step 2: Create trip request with first available driver
      final firstDriver = matchingSession.drivers.first;
      final request = TripRequest(
        pickup: TripLocation(
          label: _pickupController.text.trim(),
          lat: _pickupLatLng?.latitude,
          lng: _pickupLatLng?.longitude,
        ),
        destination: TripLocation(
          label: _destinationController.text.trim(),
          lat: _destinationLatLng?.latitude,
          lng: _destinationLatLng?.longitude,
        ),
        vehicleType: _vehicleType,
        seatCount: _seatCount,
        tripType: _tripType,
        scheduleMode: _scheduleMode,
        paymentMethod: _paymentMethod,
        departureTime: _scheduleMode == 'scheduled' ? _departureTime : null,
        notes: _notesController.text,
        estimatedFare: _estimateFare(),
        driverId: firstDriver.driverId,
        matchingSessionId: matchingSession.matchingSessionId,
      );

      print(
        '[CreateTripPage] Step 2: Requesting trip with driver ${firstDriver.driverId}',
      );
      final snapshot = await ref
          .read(tripRepositoryProvider)
          .requestMatchedTrip(request);
      final trip = snapshot.trip;
      widget.onTripCreated?.call();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) =>
                  trip == null
                      ? const TripSearchingPage(tripId: 0)
                      : MatchingInProgressPage(tripId: trip.id),
        ),
      );
    } catch (e) {
      print('[CreateTripPage] Error: $e');
      print('[CreateTripPage] Error type: ${e.runtimeType}');

      // Provide more specific error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('No available drivers')) {
        errorMessage = 'No available drivers found. Please try again later.';
      } else if (errorMessage.contains('Pickup and dropoff')) {
        errorMessage = 'Pickup and dropoff locations are required.';
      } else if (errorMessage.contains('timeout') ||
          errorMessage.contains('Time')) {
        errorMessage = 'Request timed out. Please check your connection.';
      } else if (errorMessage.contains('422') ||
          errorMessage.contains('validation')) {
        errorMessage = 'Invalid trip details. Please check all fields.';
      }

      setState(() => _error = errorMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double _estimateFare() {
    final base = switch (_vehicleType) {
      'MOTORCYCLE' => 1200.0,
      'BUS' => 600.0,
      _ => 2500.0,
    };
    return base * _seatCount;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Trip')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'private',
                    label: Text('Private'),
                    icon: Icon(Icons.directions_car),
                  ),
                  ButtonSegment(
                    value: 'public',
                    label: Text('Public'),
                    icon: Icon(Icons.directions_bus),
                  ),
                  ButtonSegment(
                    value: 'moto',
                    label: Text('Moto'),
                    icon: Icon(Icons.two_wheeler),
                  ),
                ],
                selected: {_tripType},
                onSelectionChanged: (value) {
                  final type = value.first;
                  if (type == 'public') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PublicBusBookingPage(),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _tripType = type;
                    _vehicleType = type == 'moto' ? 'MOTORCYCLE' : 'CAR';
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildLocationField(
                _pickupController,
                'Pickup location',
                Icons.my_location_rounded,
                onMapTap: _openPickupLocationPicker,
              ),
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('Use current location'),
              ),
              _buildLocationField(
                _destinationController,
                'Destination',
                Icons.location_on_rounded,
                onMapTap: _openDestinationLocationPicker,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _seatCount,
                      decoration: const InputDecoration(labelText: 'Seats'),
                      items:
                          List.generate(6, (i) => i + 1)
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _seatCount = v ?? 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'mobile_money',
                          child: Text('Mobile Money'),
                        ),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                      ],
                      onChanged:
                          (v) => setState(() => _paymentMethod = v ?? 'cash'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _scheduleMode == 'scheduled',
                onChanged: (value) {
                  if (value) {
                    _pickSchedule();
                  } else {
                    setState(() => _scheduleMode = 'immediate');
                  }
                },
                title: const Text('Schedule trip'),
                subtitle: Text(
                  _departureTime?.toLocal().toString() ?? 'Immediate booking',
                ),
              ),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Estimated fare: ${_estimateFare().toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF5E5B))),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon:
                    _submitting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded),
                label: const Text('Request Trip'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField(
    TextEditingController controller,
    String label,
    IconData icon, {
    required VoidCallback onMapTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.map_rounded),
          onPressed: onMapTap,
          tooltip: 'Select on map',
        ),
      ),
      validator:
          (value) =>
              value == null || value.trim().isEmpty
                  ? '$label is required.'
                  : null,
      onTap: onMapTap,
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          (value) =>
              value == null || value.trim().isEmpty
                  ? '$label is required.'
                  : null,
    );
  }
}
