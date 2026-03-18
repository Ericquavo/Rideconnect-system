import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/mobile/data/mobile_flow_api_service.dart';
import '../../services/passenger_language_service.dart';

class ImmediateTripRequestPage extends StatefulWidget {
  final VoidCallback? onRequestLifecycleUpdate;

  const ImmediateTripRequestPage({super.key, this.onRequestLifecycleUpdate});

  @override
  State<ImmediateTripRequestPage> createState() =>
      _ImmediateTripRequestPageState();
}

class _ImmediateTripRequestPageState extends State<ImmediateTripRequestPage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _fareController = TextEditingController(
    text: '3500',
  );

  List<OnlineDriver> _drivers = <OnlineDriver>[];
  bool _loadingDrivers = true;
  bool _submitting = false;
  String? _error;

  int? _selectedDriverId;
  int? _activeTripId;
  PassengerTripSnapshot? _activeTrip;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _pickupController.text = 'Kigali Heights';
    _dropoffController.text = 'Kimironko Market';
    _loadDrivers();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _pollTimer?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    _fareController.dispose();
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
      final drivers = await mobileFlowApi.getOnlineDrivers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _selectedDriverId = drivers.isNotEmpty ? drivers.first.id : null;
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

    final driverId = _selectedDriverId;
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    final fare = double.tryParse(_fareController.text.trim());

    if (driverId == null) {
      _showSnack(_lang.t('request.pickDriverError'));
      return;
    }
    if (pickup.isEmpty || dropoff.isEmpty) {
      _showSnack(_lang.t('request.locationRequired'));
      return;
    }
    if (fare == null || fare <= 0) {
      _showSnack(_lang.t('request.fareError'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await mobileFlowApi.createRideRequest(
        RideRequestPayload(
          driverId: driverId,
          pickupLocation: pickup,
          pickupLat: -1.9441,
          pickupLng: 30.0619,
          dropoffLocation: dropoff,
          dropoffLat: -1.9411,
          dropoffLng: 30.1098,
          fare: fare,
        ),
      );

      final tripId = result.tripId;
      if (tripId == null || tripId <= 0) {
        throw Exception(_lang.t('request.tripIdMissing'));
      }

      _activeTripId = tripId;
      await _pollTripStatus();
      _startPolling();

      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onRequestLifecycleUpdate?.call();
      _showSnack(_lang.t('request.submitted'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnack(_error!);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollTripStatus();
    });
  }

  Future<void> _pollTripStatus() async {
    final tripId = _activeTripId;
    if (tripId == null || tripId <= 0) return;

    try {
      final snapshot = await mobileFlowApi.getPassengerTripById(tripId);
      if (!mounted) return;

      setState(() {
        _activeTrip = snapshot;
      });

      final lower = snapshot.status.toLowerCase();
      final isTerminal =
          lower.contains('accepted') ||
          lower.contains('reject') ||
          lower.contains('cancel') ||
          lower.contains('complete');

      if (isTerminal) {
        _pollTimer?.cancel();
        widget.onRequestLifecycleUpdate?.call();
      }
    } catch (_) {
      // Polling errors are intentionally silent to avoid noisy UI.
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF131729),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0A0E1A), Color(0xFF1A1F3A)],
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
              _buildActiveStatusCard(),
              const SizedBox(height: 16),
              _buildDriversSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
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
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

  Widget _buildActiveStatusCard() {
    final active = _activeTrip;
    if (active == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          _lang.t('request.noActive'),
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final statusColor = _statusColor(active.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_lang.t('request.currentStatus')}: ${active.status}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_lang.t('trips.driver')}: ${active.driverName}',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '${_lang.t('request.route')}: ${active.pickup} -> ${active.dropoff}',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversSection() {
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
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _lang.t('request.onlineDrivers'),
          style: GoogleFonts.poppins(
            color: Colors.white,
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
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? const Color(0xFF3B82F6)
                    : Colors.white.withValues(alpha: 0.08),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${driver.vehicle} • ★ ${driver.rating.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('accept')) return const Color(0xFF10B981);
    if (lower.contains('reject') || lower.contains('cancel')) {
      return const Color(0xFFFF5E5B);
    }
    if (lower.contains('complete')) return const Color(0xFF6C63FF);
    return const Color(0xFF3B82F6);
  }
}
