import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'matching_lifecycle_pages.dart';
import 'trip_matching_page.dart';
import 'location_picker_page.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import '../../../../pages/passenger/public_bus_booking_page.dart';
import '../../../../services/passenger_api.dart';

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

    // If the user has entered/selected an address but coordinates are missing,
    // attempt to geocode the provided address as a fallback before rejecting.
    if (_pickupLatLng == null && _pickupController.text.trim().isNotEmpty) {
      try {
        final locs = await geocoding.locationFromAddress(
          _pickupController.text.trim(),
        );
        if (locs.isNotEmpty) {
          final p = locs.first;
          setState(() => _pickupLatLng = LatLng(p.latitude, p.longitude));
        }
      } catch (_) {
        // ignore and fall through to error handling below
      }
    }

    if (_destinationLatLng == null &&
        _destinationController.text.trim().isNotEmpty) {
      try {
        final locs = await geocoding.locationFromAddress(
          _destinationController.text.trim(),
        );
        if (locs.isNotEmpty) {
          final p = locs.first;
          setState(() => _destinationLatLng = LatLng(p.latitude, p.longitude));
        }
      } catch (_) {
        // ignore and fall through to error handling below
      }
    }

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
      final tripRepo = ref.read(tripRepositoryProvider);
      final activeTrip = await _activeTrip();
      if (activeTrip != null) {
        bool? shouldCreateNew = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Active Trip Found'),
            content: const Text(
                'You already have an active trip in progress. Would you like to view your current trip or create a new one?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('View Active Trip'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Create New Trip'),
              ),
            ],
          ),
        );

        if (shouldCreateNew != true) {
          debugPrint(
            '[CreateTripPage] Active trip found; resuming tripId=${activeTrip.tripId}',
          );
          widget.onTripCreated?.call();
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => TripMatchingPage(
                    tripId: activeTrip.tripId,
                    initialStatus: activeTrip.status,
                    initialMatchingStatus: activeTrip.matchingStatus,
                    initialData: activeTrip.raw,
                  ),
            ),
          );
          setState(() => _submitting = false);
          return;
        }
      }

      final pickupAddress = _pickupController.text.trim();
      final dropoffAddress = _destinationController.text.trim();
      final request = TripRequest(
        pickup: TripLocation(
          label: pickupAddress,
          lat: _pickupLatLng!.latitude,
          lng: _pickupLatLng!.longitude,
        ),
        destination: TripLocation(
          label: dropoffAddress,
          lat: _destinationLatLng!.latitude,
          lng: _destinationLatLng!.longitude,
        ),
        vehicleType: _vehicleType,
        seatCount: _vehicleType == 'MOTORCYCLE' ? 1 : _seatCount,
        tripType: _tripType,
        scheduleMode: _scheduleMode,
        paymentMethod: _paymentMethod,
        departureTime: _scheduleMode == 'scheduled' ? _departureTime : null,
        notes: _notesController.text,
        estimatedFare: _estimateFare(),
      );

      if (_vehicleType == 'MOTORCYCLE') {
        debugPrint('[CreateTripPage] Requesting MOTORCYCLE trip directly...');
        final snapshot = await tripRepo.requestMotorVehicleTrip(request);
        final tripId = snapshot.trip?.id ?? 0;
        if (tripId <= 0) {
          throw Exception(
            'Trip request was accepted but the server did not return a valid trip ID.',
          );
        }

        debugPrint(
          '[CreateTripPage] Moto trip request succeeded: tripId=$tripId status=${snapshot.status}',
        );
        widget.onTripCreated?.call();
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => TripMatchingPage(
                  tripId: tripId,
                  initialStatus:
                      snapshot.trip?.status.apiValue ??
                      snapshot.status.apiValue,
                  initialData: {
                    if (snapshot.trip?.fare != null)
                      'estimated_fare': snapshot.trip!.fare,
                  },
                ),
          ),
        );
        return;
      }

      // Step 1: Find available drivers first
      debugPrint('[CreateTripPage] Step 1: Matching drivers...');
      final matchingSession = await tripRepo.matchPassengerDrivers(
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
                  _vehicleType == 'MOTORCYCLE'
                      ? 'No motorcycle drivers are currently available nearby. Please try again later or choose a car ride.'
                      : 'No available drivers found for this route. Please try again.',
        );
        return;
      }

      debugPrint(
        '[CreateTripPage] Found ${matchingSession.drivers.length} drivers',
      );

      // Step 2: Request the trip through the mobile trips API so it is
      // persisted as a real trip that matching and driver screens can load.
      final firstDriver = matchingSession.drivers.first;

      debugPrint(
        '[CreateTripPage] Step 2: Requesting $_vehicleType trip with driver ${firstDriver.driverId}',
      );

      final snapshot = await tripRepo.requestMatchedTrip(
        request.copyWith(
          driverId: firstDriver.driverId,
          matchingSessionId: matchingSession.matchingSessionId,
        ),
      );

      final tripId = snapshot.trip?.id ?? 0;
      if (tripId <= 0) {
        throw Exception(
          'Trip request was accepted but the server did not return a valid trip ID.',
        );
      }

      debugPrint('[CreateTripPage] Trip request succeeded: tripId=$tripId');
      widget.onTripCreated?.call();
      if (!mounted) return;

      // Navigate to trip status page
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchingInProgressPage(tripId: tripId),
        ),
      );
    } catch (e) {
      debugPrint('[CreateTripPage] Error: $e');
      debugPrint('[CreateTripPage] Error type: ${e.runtimeType}');

      // Provide more specific error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('No available drivers')) {
        errorMessage =
            _vehicleType == 'MOTORCYCLE'
                ? 'No motorcycle drivers are currently available nearby. Please try again later or choose a car ride.'
                : 'No available drivers found. Please try again later.';
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

  Future<_ActiveTripSeed?> _activeTrip() async {
    try {
      final data = await PassengerApi.instance.getActiveTrip();
      final source =
          data['trip'] is Map<String, dynamic>
              ? data['trip'] as Map<String, dynamic>
              : data;
      final tripId = _readInt(source, const ['trip_id', 'id']);
      if (tripId == null || tripId <= 0) return null;
      final status = _readString(source, const ['status', 'trip_status']);
      if (_isTerminalStatus(status)) return null;
      return _ActiveTripSeed(
        tripId: tripId,
        status: status ?? 'REQUESTED',
        matchingStatus: _readString(source, const ['matching_status']),
        raw: source,
      );
    } on PassengerApiException catch (e) {
      if (e.statusCode == 404) return null;
      debugPrint('[CreateTripPage] Active trip check skipped: $e');
      return null;
    } catch (e) {
      debugPrint('[CreateTripPage] Active trip check skipped: $e');
      return null;
    }
  }

  bool _isTerminalStatus(String? status) {
    final raw = (status ?? '').toUpperCase();
    return raw.contains('COMPLETE') ||
        raw.contains('CANCEL') ||
        raw == 'EXPIRED' ||
        raw.contains('FAILED_MAX_RETRIES');
  }

  int? _readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
    }
    return null;
  }

  String? _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
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
}

class _ActiveTripSeed {
  const _ActiveTripSeed({
    required this.tripId,
    required this.status,
    required this.raw,
    this.matchingStatus,
  });

  final int tripId;
  final String status;
  final String? matchingStatus;
  final Map<String, dynamic> raw;
}
