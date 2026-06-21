import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'matching_lifecycle_pages.dart';
import 'trip_matching_page.dart';
import 'location_picker_page.dart';
import 'best_matches_driver_page.dart';
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
  String _vehicleType = 'MOTORCYCLE';
  String _tripType = 'moto';
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
        tripType: _tripType == 'moto' ? 'private' : _tripType,
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

        // Navigate to manual driver candidate selection screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BestMatchesDriverPage(
              tripId: tripId,
              candidates: snapshot.candidates,
              initialFare: snapshot.trip?.fare ?? snapshot.candidates.firstOrNull?.estimatedFare,
            ),
          ),
        );
        return;
      }

      if (_vehicleType == 'CAR') {
        debugPrint('[CreateTripPage] Requesting Private Car trip directly...');
        final snapshot = await tripRepo.requestPrivateCarTrip(request);
        final tripId = snapshot.trip?.id ?? 0;
        if (tripId <= 0) {
          throw Exception(
            'Trip request was accepted but the server did not return a valid trip ID.',
          );
        }

        debugPrint(
          '[CreateTripPage] Private Car trip request succeeded: tripId=$tripId status=${snapshot.status}',
        );
        widget.onTripCreated?.call();
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchingInProgressPage(tripId: tripId),
          ),
        );
        return;
      }
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
      'MOTORCYCLE' => 720.0,
      'BUS' => 300.0,
      _ => 1500.0,
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
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              Text(
                'Request V3 Ride',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),
              _buildTabSelector(isDark),
              const SizedBox(height: 24),
              _buildCustomLocationField(
                controller: _pickupController,
                label: 'Pickup location',
                prefixIcon: Icons.gps_fixed_rounded,
                onMapTap: _openPickupLocationPicker,
                context: context,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _useCurrentLocation,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: const Color(0xFF4C57D6),
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: Text(
                    'Use current location',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomLocationField(
                controller: _destinationController,
                label: 'Destination',
                prefixIcon: Icons.location_on_rounded,
                onMapTap: _openDestinationLocationPicker,
                context: context,
              ),
              const SizedBox(height: 24),
              _buildPaymentDropdown(isDark),
              if (_vehicleType == 'CAR') ...[
                const SizedBox(height: 16),
                _buildSeatSelector(isDark),
              ],
              const SizedBox(height: 16),
              _buildNotesField(isDark),
              const SizedBox(height: 16),
              _buildScheduleTile(isDark),
              const SizedBox(height: 24),
              _buildFareEstimate(isDark),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF5E5B).withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF5E5B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildRequestButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    final borderColor = isDark ? Colors.white24 : Colors.black;

    Widget buildTab(String value, String label, IconData icon, {bool showCheck = false}) {
      final isSelected = _tripType == value;
      final selectedColor = const Color(0xFF3B82F6); // Blue color as in the reference image

      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (value == 'public') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PublicBusBookingPage(),
                ),
              );
              return;
            }
            setState(() {
              _tripType = value;
              _vehicleType = value == 'moto' ? 'MOTORCYCLE' : 'CAR';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent,
              borderRadius: value == 'moto'
                  ? const BorderRadius.horizontal(left: Radius.circular(20))
                  : value == 'public'
                      ? const BorderRadius.horizontal(right: Radius.circular(20))
                      : BorderRadius.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showCheck && isSelected ? Icons.check : icon,
                  size: 16,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
      child: Row(
        children: [
          buildTab('moto', 'Moto', Icons.two_wheeler, showCheck: true),
          Container(width: 1.2, height: 40, color: borderColor),
          buildTab('private', 'Private', Icons.directions_car),
          Container(width: 1.2, height: 40, color: borderColor),
          buildTab('public', 'Public', Icons.directions_bus),
        ],
      ),
    );
  }

  Widget _buildCustomLocationField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    required VoidCallback onMapTap,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(10),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(prefixIcon, color: isDark ? Colors.white70 : Colors.black, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: true,
              onTap: onMapTap,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: GoogleFonts.poppins(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '$label is required.' : null,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.map_outlined,
              color: isDark ? Colors.white70 : Colors.black,
              size: 20,
            ),
            onPressed: onMapTap,
            tooltip: 'Select on map',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDropdown(bool isDark) {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: isDark ? const Color(0xFF131729) : Colors.white,
      ),
      child: DropdownButtonFormField<String>(
        value: _paymentMethod,
        dropdownColor: isDark ? const Color(0xFF131729) : Colors.white,
        decoration: InputDecoration(
          labelText: 'Payment Method',
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black,
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF6C63FF),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
          DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
          DropdownMenuItem(value: 'card', child: Text('Card')),
        ],
        onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
      ),
    );
  }

  Widget _buildSeatSelector(bool isDark) {
    return DropdownButtonFormField<int>(
      value: _seatCount,
      decoration: InputDecoration(
        labelText: 'Seats',
        labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: List.generate(6, (i) => i + 1)
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text('$v', style: GoogleFonts.poppins()),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _seatCount = v ?? 1),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return TextFormField(
      controller: _notesController,
      minLines: 1,
      maxLines: 3,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Notes for driver',
        labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildScheduleTile(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        value: _scheduleMode == 'scheduled',
        onChanged: (value) {
          if (value) {
            _pickSchedule();
          } else {
            setState(() => _scheduleMode = 'immediate');
          }
        },
        title: Text(
          'Schedule Trip',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _departureTime != null && _scheduleMode == 'scheduled'
              ? _departureTime!.toLocal().toString().substring(0, 16)
              : 'Immediate booking',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFareEstimate(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C57D6).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_rounded,
            color: Color(0xFF10B981),
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Fare',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'RWF ${_estimateFare().toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        child: _submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Request Trip Now',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
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
