import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/driver_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
class DriverNavigationScreen extends StatefulWidget {
  final int tripId;
  final double? passengerLat;
  final double? passengerLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String passengerName;
  final String passengerPhone;
  final String pickupAddress;
  final String dropoffAddress;
  final double? estimatedFare;

  const DriverNavigationScreen({
    super.key,
    required this.tripId,
    this.passengerLat,
    this.passengerLng,
    this.dropoffLat,
    this.dropoffLng,
    this.passengerName = 'Passenger',
    this.passengerPhone = '',
    this.pickupAddress = 'Pickup Location',
    this.dropoffAddress = 'Dropoff Location',
    this.estimatedFare,
  });

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen>
    with TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  static const LatLng _kigali = LatLng(-1.9441, 30.0619);
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ── Driver live position ─────────────────────────────────────────────────
  LatLng? _driverPos;
  LatLng? _passengerPos;
  LatLng? _dropoffPos;

  // ── Trip state ────────────────────────────────────────────────────────────
  // Phases: 0 = en_route_to_passenger, 1 = waiting, 2 = trip_in_progress, 3 = completed
  int _phase = 0;
  bool _actionLoading = false;
  String? _actionError;

  // ── Distance / ETA ────────────────────────────────────────────────────────
  String _distanceLabel = '--';
  String _etaLabel = '--';

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _locationTimer; // 10-second driver location push
  StreamSubscription<Position>? _positionStream;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    if (widget.passengerLat != null && widget.passengerLng != null) {
      _passengerPos = LatLng(widget.passengerLat!, widget.passengerLng!);
    }
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      _dropoffPos = LatLng(widget.dropoffLat!, widget.dropoffLng!);
    }

    _startLocationTracking();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pushLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _mapCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Location tracking ─────────────────────────────────────────────────────
  void _startLocationTracking() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() => _driverPos = p);
        _updateMarkers();
        _buildRoute();
        _mapCtrl?.animateCamera(CameraUpdate.newLatLng(p));
      });
    } catch (_) {}
  }

  Future<void> _pushLocation() async {
    if (_driverPos == null) return;
    try {
      await DriverApi.instance.postLocation(
        latitude: _driverPos!.latitude,
        longitude: _driverPos!.longitude,
      );
    } catch (_) {}
  }

  // ── Markers ───────────────────────────────────────────────────────────────
  void _updateMarkers() {
    final markers = <Marker>{};

    if (_driverPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    // Show passenger marker when going to pick up
    if (_phase == 0 && _passengerPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('passenger'),
        position: _passengerPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.passengerName, snippet: widget.pickupAddress),
      ));
    }

    // Show dropoff marker when trip is in progress
    if (_phase == 2 && _dropoffPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Dropoff', snippet: widget.dropoffAddress),
      ));
    }

    if (!mounted) return;
    setState(() => _markers = markers);
  }

  // ── Polyline ──────────────────────────────────────────────────────────────
  Future<void> _buildRoute() async {
    if (_driverPos == null) return;

    LatLng? destination;
    String polylineId;

    if (_phase == 0 && _passengerPos != null) {
      destination = _passengerPos;
      polylineId = 'to_passenger';
    } else if (_phase == 2 && _dropoffPos != null) {
      destination = _dropoffPos;
      polylineId = 'to_dropoff';
    } else {
      return;
    }

    if (destination == null) return;

    List<LatLng> points = [_driverPos!, destination];

    // Calculate rough distance for ETA display
    final distKm = Geolocator.distanceBetween(
      _driverPos!.latitude, _driverPos!.longitude,
      destination.latitude, destination.longitude,
    ) / 1000;

    final etaMin = (distKm / 30 * 60).round(); // rough 30 km/h avg
    if (mounted) {
      setState(() {
        _distanceLabel = '${distKm.toStringAsFixed(1)} km';
        _etaLabel = etaMin <= 1 ? '< 1 min' : '$etaMin min';
      });
    }

    final poly = Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: const Color(0xFF6C63FF),
      width: 5,
    );

    if (!mounted) return;
    setState(() => _polylines = {poly});
  }

  // ── Trip actions ──────────────────────────────────────────────────────────
  Future<void> _onPrimaryAction() async {
    setState(() { _actionLoading = true; _actionError = null; });
    try {
      switch (_phase) {
        case 0: // arrived at pickup
          await DriverApi.instance.updateRide(
            widget.tripId,
            {'status': 'driver_arrived'},
          );
          setState(() => _phase = 1);
          break;
        case 1: // start trip
          await DriverApi.instance.startTrip(widget.tripId);
          setState(() => _phase = 2);
          _buildRoute();
          break;
        case 2: // complete trip
          await DriverApi.instance.completeRequest(widget.tripId);
          setState(() => _phase = 3);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _callPassenger() async {
    final phone = widget.passengerPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _openGoogleMapsNavigation() async {
    LatLng? dest;
    if (_phase == 0 || _phase == 1) dest = _passengerPos;
    if (_phase == 2) dest = _dropoffPos;
    if (dest == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${dest.latitude},${dest.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: GestureDetector(
          onTap: () => _confirmExit(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          // Open in Google Maps
          GestureDetector(
            onTap: _openGoogleMapsNavigation,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Navigate',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _phase == 3
          ? _buildTripComplete()
          : Stack(
              children: [
                // ── Map ───────────────────────────────────────────────────
                GoogleMap(
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    _buildRoute();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _driverPos ?? _passengerPos ?? _kigali,
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),

                // ── Phase status chip ─────────────────────────────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildPhaseChip()),
                ),

                // ── Bottom panel ──────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildPhaseChip() {
    final labels = [
      'En route to passenger',
      'Waiting for passenger',
      'Trip in progress',
    ];
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    final color = _phase < colors.length ? colors[_phase] : colors.last;
    final label = _phase < labels.length ? labels[_phase] : '';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4 + 0.2 * _pulseCtrl.value),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _phase == 0 ? Icons.directions_car_rounded :
              _phase == 1 ? Icons.person_pin_circle_rounded :
              Icons.trip_origin_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final cardBg = _isDark ? const Color(0xFF141829) : Colors.white;
    final textPrimary = _isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = _isDark ? Colors.white70 : const Color(0xFF475569);

    final primaryLabel = _phase == 0
        ? 'I\'ve Arrived at Pickup'
        : _phase == 1
            ? 'Start Trip'
            : 'Complete Trip';
    final primaryIcon = _phase == 0
        ? Icons.location_on_rounded
        : _phase == 1
            ? Icons.play_arrow_rounded
            : Icons.flag_rounded;
    final primaryColor = _phase == 0
        ? const Color(0xFF3B82F6)
        : _phase == 1
            ? const Color(0xFF10B981)
            : const Color(0xFF6C63FF);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Passenger info ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.passengerName.isNotEmpty
                        ? widget.passengerName[0].toUpperCase()
                        : 'P',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.passengerName,
                      style: GoogleFonts.poppins(
                        color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _phase == 0 || _phase == 1
                          ? widget.pickupAddress
                          : widget.dropoffAddress,
                      style: GoogleFonts.poppins(color: textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Call button
              if (widget.passengerPhone.isNotEmpty)
                GestureDetector(
                  onTap: _callPassenger,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.phone_rounded, color: Color(0xFF10B981), size: 22,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Distance + ETA chips ──────────────────────────────────────────
          Row(
            children: [
              _Chip(icon: Icons.straighten_rounded, label: 'Distance', value: _distanceLabel, isDark: _isDark),
              const SizedBox(width: 10),
              _Chip(icon: Icons.timer_rounded, label: 'ETA', value: _etaLabel, isDark: _isDark),
              if (widget.estimatedFare != null) ...[
                const SizedBox(width: 10),
                _Chip(
                  icon: Icons.payments_rounded,
                  label: 'Fare',
                  value: 'RWF ${widget.estimatedFare!.toStringAsFixed(0)}',
                  isDark: _isDark,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── Error ─────────────────────────────────────────────────────────
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _actionError!,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFEF4444), fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Primary CTA ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _actionLoading ? null : _onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              icon: _actionLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    )
                  : Icon(primaryIcon, color: Colors.white),
              label: Text(
                _actionLoading ? 'Processing…' : primaryLabel,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripComplete() {
    final textPrimary = _isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = _isDark ? Colors.white70 : const Color(0xFF475569);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                ),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
            ),
            const SizedBox(height: 24),
            Text(
              'Trip Completed!',
              style: GoogleFonts.poppins(
                color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Great job! You\'ve completed the trip.',
              style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (widget.estimatedFare != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      'Earned',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'RWF ${widget.estimatedFare!.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size(200, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Back to Dashboard',
                style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Navigation?'),
        content: const Text(
          'The trip is still active. Are you sure you want to leave this screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave', style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
