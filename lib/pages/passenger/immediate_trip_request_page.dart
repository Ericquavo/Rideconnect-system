import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/trips/domain/matching_lifecycle_models.dart';
import '../../features/trips/domain/trip_models.dart';
import '../../features/trips/presentation/pages/trip_matching_page.dart';
import '../../features/trips/presentation/providers/trip_providers.dart';
import '../../features/mobile/data/mobile_flow_api_service.dart';
import '../../services/passenger_api.dart';
import '../../services/passenger_location_helper.dart';
import '../../services/passenger_language_service.dart';

class ImmediateTripRequestPage extends ConsumerStatefulWidget {
  final VoidCallback? onRequestLifecycleUpdate;

  const ImmediateTripRequestPage({super.key, this.onRequestLifecycleUpdate});

  @override
  ConsumerState<ImmediateTripRequestPage> createState() =>
      _ImmediateTripRequestPageState();
}

class _ImmediateTripRequestPageState
    extends ConsumerState<ImmediateTripRequestPage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _fareController = TextEditingController(
    text: '3500',
  );
  final TextEditingController _seatsController = TextEditingController(
    text: '1',
  );

  List<OnlineDriver> _drivers = <OnlineDriver>[];
  bool _loadingDrivers = true;
  bool _submitting = false;
  String? _error;

  int? _selectedDriverId;
  String _selectedRideType = 'CAR';
  LatLng? _pickupLatLng;
  final LatLng _dropoffLatLng = const LatLng(-1.9411, 30.1098);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _pickupController.text = 'Kigali Heights';
    _dropoffController.text = 'Kimironko Market';
    _loadDrivers();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _pickupController.dispose();
    _dropoffController.dispose();
    _fareController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loadingDrivers = true;
      _error = null;
    });

    try {
      final pickupPoint = await _ensurePickupPoint();
      if (pickupPoint == null) {
        if (!mounted) return;
        setState(() => _loadingDrivers = false);
        return;
      }

      final driversRaw = await PassengerApi.instance.getMatchedDrivers(
        transportType: _selectedRideType,
        pickupLat: pickupPoint.latitude,
        pickupLng: pickupPoint.longitude,
        dropoffLat: _dropoffLatLng.latitude,
        dropoffLng: _dropoffLatLng.longitude,
      );
      if (!mounted) return;
      setState(() {
        _drivers =
            driversRaw.map((driver) {
              return OnlineDriver(
                id: _readInt(driver, <String>['id', 'driver_id']) ?? 0,
                name:
                    _readString(driver, <String>['name', 'driver_name']) ??
                    'Driver',
                rating:
                    _readDouble(driver, <String>['rating', 'avg_rating']) ?? 0,
                vehicle:
                    _readString(driver, <String>['vehicle', 'vehicle_name']) ??
                    'Vehicle',
              );
            }).toList();
        _selectedDriverId = _drivers.isNotEmpty ? _drivers.first.id : null;
        _loadingDrivers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDrivers = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitRideRequest() async {
    if (_submitting) return;

    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    final fare = double.tryParse(_fareController.text.trim());
    final seats = int.tryParse(_seatsController.text.trim()) ?? 1;

    if (pickup.isEmpty || dropoff.isEmpty) {
      _showSnack(_lang.t('request.locationRequired'));
      return;
    }
    if (fare == null || fare <= 0) {
      _showSnack(_lang.t('request.fareError'));
      return;
    }
    if (seats < 1 || seats > 8) {
      _showSnack(_lang.t('request.seatRangeError'));
      return;
    }

    final pickupPoint = await _ensurePickupPoint();
    if (pickupPoint == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final tripRepo = ref.read(tripRepositoryProvider);
      final request = TripRequest(
        pickup: TripLocation(
          label: pickup,
          lat: pickupPoint.latitude,
          lng: pickupPoint.longitude,
        ),
        destination: TripLocation(
          label: dropoff,
          lat: _dropoffLatLng.latitude,
          lng: _dropoffLatLng.longitude,
        ),
        vehicleType: _selectedRideType,
        seatCount: _selectedRideType == 'MOTORCYCLE' ? 1 : seats,
        tripType: _selectedRideType == 'BUS' ? 'public' : 'private',
        scheduleMode: 'immediate',
        paymentMethod: 'cash',
        estimatedFare: fare,
      );

      final snapshot =
          _selectedRideType == 'MOTORCYCLE'
              ? await tripRepo.requestMotorVehicleTrip(request)
              : await () async {
                final matchingSession = await tripRepo.matchPassengerDrivers(
                  transportType: _selectedRideType,
                  pickupLat: pickupPoint.latitude,
                  pickupLng: pickupPoint.longitude,
                  dropoffLat: _dropoffLatLng.latitude,
                  dropoffLng: _dropoffLatLng.longitude,
                );

                if (matchingSession.drivers.isEmpty) {
                  throw Exception(_lang.t('request.noDrivers'));
                }

                final matchedDriver = matchingSession.drivers.first;
                return tripRepo.requestMatchedTrip(
                  request.copyWith(
                    driverId: matchedDriver.driverId,
                    matchingSessionId: matchingSession.matchingSessionId,
                  ),
                );
              }();

      final tripId = snapshot.trip?.id;
      if (tripId == null || tripId <= 0) {
        throw Exception(_lang.t('request.tripIdMissing'));
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onRequestLifecycleUpdate?.call();
      _showSnack(_lang.t('request.submitted'));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => TripMatchingPage(
                tripId: tripId,
                initialStatus:
                    snapshot.trip?.status.apiValue ?? snapshot.status.apiValue,
                initialMatchingStatus: snapshot.status.apiValue,
                initialData: <String, dynamic>{
                  'estimated_fare': fare,
                  if (snapshot.selectedDriver != null)
                    'driver': <String, dynamic>{
                      'id': snapshot.selectedDriver!.driverId,
                      'name': snapshot.selectedDriver!.driverName,
                      'rating': snapshot.selectedDriver!.rating,
                      'photo_url': snapshot.selectedDriver!.profilePhotoUrl,
                    },
                },
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      if (PassengerLocationHelper.isLocationValidationError(e)) {
        await PassengerLocationHelper.showLocationSettingsPrompt(
          context,
          message: passengerLocationValidationMessage,
        );
        return;
      }
      _showSnack(_error!);
    }
  }

  Future<LatLng?> _ensurePickupPoint() async {
    if (_pickupLatLng != null) return _pickupLatLng;

    final resolved = await PassengerLocationHelper.resolveRideLocation(context);
    if (!mounted || resolved == null) return null;

    setState(() => _pickupLatLng = resolved.point);
    return resolved.point;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF131729) : Colors.white,
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? const <Color>[Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                  : const <Color>[Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDrivers,
          color: const Color(0xFF6C63FF),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              _buildTitle(),
              const SizedBox(height: 16),
              _buildRequestForm(),
              const SizedBox(height: 16),
              _buildDriversSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_taxi_rounded,
            color: Color(0xFF3B82F6),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _lang.t('request.title'),
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.92);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1);
    final fieldBg =
        isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC);
    final fieldBorder =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: <Widget>[
          _field(
            controller: _pickupController,
            icon: Icons.radio_button_checked_rounded,
            label: _lang.t('request.pickup'),
          ),
          const SizedBox(height: 10),
          _field(
            controller: _dropoffController,
            icon: Icons.location_on_rounded,
            label: _lang.t('request.dropoff'),
          ),
          const SizedBox(height: 10),
          _field(
            controller: _fareController,
            icon: Icons.payments_rounded,
            label: _lang.t('request.fare'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _field(
                  controller: _seatsController,
                  icon: Icons.event_seat_rounded,
                  label: _lang.t('request.seats'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRideType,
                  dropdownColor:
                      isDark ? const Color(0xFF1A1F3A) : Colors.white,
                  style: GoogleFonts.poppins(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _lang.t('request.rideType'),
                    labelStyle: GoogleFonts.poppins(color: textSecondary),
                    filled: true,
                    fillColor: fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                  ),
                  items:
                      const <String>['BUS', 'CAR', 'MOTORCYCLE'].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(_rideTypeLabel(type)),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRideType = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitRideRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              icon:
                  _submitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.send_rounded),
              label: Text(
                _submitting
                    ? _lang.t('request.sending')
                    : _lang.t('request.submit'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF5E5B),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriversSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadingDrivers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_drivers.isEmpty) {
      return Center(
        child: Text(
          _lang.t('request.noDrivers'),
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _lang.t('request.onlineDrivers'),
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        ..._drivers.map(_driverCard),
      ],
    );
  }

  Widget _driverCard(OnlineDriver driver) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = driver.id == _selectedDriverId;
    return GestureDetector(
      onTap: () => setState(() => _selectedDriverId = driver.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? const Color(0xFF3B82F6)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.22),
              child: Text(
                driver.name.isEmpty ? 'D' : driver.name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    driver.name,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${driver.vehicle} • ★ ${driver.rating.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final fieldBg =
        isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC);
    final fieldBorder =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: textSecondary),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        filled: true,
        fillColor: fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
      ),
    );
  }

  String _rideTypeLabel(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('bus')) return _lang.t('transportType.public');
    if (lower.contains('motor')) return _lang.t('transportType.motorVehicle');
    return _lang.t('transportType.private');
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
