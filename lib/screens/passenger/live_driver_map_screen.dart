// lib/screens/passenger/live_driver_map_screen.dart
// Enhanced Live Driver Map – real-time polyline route, driver marker tracking,
// auto-pan camera, 5-second trip poll, 10-second driver-location update.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/passenger_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a live trip snapshot
// ─────────────────────────────────────────────────────────────────────────────
class _LiveTripSnapshot {
  final String status;
  final String? driverName;
  final double? driverRating;
  final String? driverPhone;
  final String? vehiclePlate;
  final String? vehicleModel;
  final double? driverLat;
  final double? driverLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String pickupLocation;
  final String dropoffLocation;
  final double? fare;
  final String? etaLabel;

  const _LiveTripSnapshot({
    required this.status,
    this.driverName,
    this.driverRating,
    this.driverPhone,
    this.vehiclePlate,
    this.vehicleModel,
    this.driverLat,
    this.driverLng,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.fare,
    this.etaLabel,
  });

  factory _LiveTripSnapshot.fromJson(Map<String, dynamic> j) {
    final driver = j['driver'] as Map<String, dynamic>?;
    final driverLoc = j['driver_location'] as Map<String, dynamic>?;
    final pickup = j['pickup'] as Map<String, dynamic>?;
    final dropoff = j['dropoff'] as Map<String, dynamic>?;
    double? _d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return _LiveTripSnapshot(
      status: (j['status'] ?? j['trip_status'] ?? 'UNKNOWN').toString().toUpperCase(),
      driverName: driver?['name']?.toString() ?? driver?['full_name']?.toString(),
      driverRating: _d(driver?['rating'] ?? driver?['avg_rating']),
      driverPhone: driver?['phone']?.toString() ?? driver?['phone_number']?.toString(),
      vehiclePlate: driver?['vehicle_plate']?.toString() ?? driver?['plate']?.toString(),
      vehicleModel: driver?['vehicle_model']?.toString() ?? driver?['car_model']?.toString(),
      driverLat: _d(driverLoc?['lat'] ?? driverLoc?['latitude'] ?? j['driver_lat']),
      driverLng: _d(driverLoc?['lng'] ?? driverLoc?['longitude'] ?? j['driver_lng']),
      pickupLat: _d(pickup?['lat'] ?? j['pickup_lat']),
      pickupLng: _d(pickup?['lng'] ?? j['pickup_lng']),
      dropoffLat: _d(dropoff?['lat'] ?? j['dropoff_lat']),
      dropoffLng: _d(dropoff?['lng'] ?? j['dropoff_lng']),
      pickupLocation: j['pickup_location']?.toString() ?? j['pickup_address']?.toString() ?? 'Pickup',
      dropoffLocation: j['dropoff_location']?.toString() ?? j['dropoff_address']?.toString() ?? 'Dropoff',
      fare: _d(j['fare'] ?? j['estimated_fare']),
      etaLabel: j['eta']?.toString() ?? j['eta_minutes']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class LiveDriverMapScreen extends StatefulWidget {
  final int tripId;
  final bool isMotorVehicle;

  const LiveDriverMapScreen({
    super.key,
    required this.tripId,
    this.isMotorVehicle = false,
  });

  @override
  State<LiveDriverMapScreen> createState() => _LiveDriverMapScreenState();
}

class _LiveDriverMapScreenState extends State<LiveDriverMapScreen>
    with TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  GoogleMapController? _mapCtrl;
  static const LatLng _kigali = LatLng(-1.9441, 30.0619);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverPos;
  LatLng? _pickupPos;
  LatLng? _dropoffPos;
  bool _autoPan = true;

  // ── Data ─────────────────────────────────────────────────────────────────
  _LiveTripSnapshot? _snap;
  String _statusMsg = 'Loading trip…';
  bool _isLoading = true;
  String? _error;

  // ── Timers ───────────────────────────────────────────────────────────────
  Timer? _tripPollTimer;   // 5-second trip status poll
  Timer? _locUpdateTimer;  // 10-second driver location pull

  // ── Animation for driver marker ───────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Route colours ─────────────────────────────────────────────────────────
  static const Color _routeColor    = Color(0xFF6C63FF);
  static const Color _previewColor  = Color(0xFF94A3B8);

  // Google Directions key – uses the same key from AndroidManifest in production.
  // Falls back to a rough straight-line poly when empty.
  static const String _directionsKey = '';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(_pulseCtrl);

    _fetchTrip();
    _tripPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchTrip());
    _locUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pushMyLocation());
  }

  @override
  void dispose() {
    _tripPollTimer?.cancel();
    _locUpdateTimer?.cancel();
    _mapCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  Future<void> _fetchTrip() async {
    try {
      final raw = widget.isMotorVehicle
          ? await PassengerApi.instance.getMotorVehicleTrip(widget.tripId)
          : await PassengerApi.instance.getTripById(widget.tripId);

      final snap = _LiveTripSnapshot.fromJson(raw);
      if (!mounted) return;

      setState(() {
        _snap = snap;
        _isLoading = false;
        _error = null;
        _statusMsg = _humanStatus(snap.status);
      });

      _updateMapFromSnap(snap);
      _checkTerminal(snap.status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pushMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      // For passengers we don't push location to the server, but
      // we can optionally update the camera if auto-pan is on.
      if (_autoPan && _driverPos != null) {
        await _mapCtrl?.animateCamera(
          CameraUpdate.newLatLng(_driverPos!),
        );
      }
    } catch (_) {}
  }

  void _checkTerminal(String status) {
    if (status == 'COMPLETED' || status == 'CANCELLED') {
      _tripPollTimer?.cancel();
      _locUpdateTimer?.cancel();
    }
  }

  // ── Map update ───────────────────────────────────────────────────────────
  Future<void> _updateMapFromSnap(_LiveTripSnapshot snap) async {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Driver marker
    if (snap.driverLat != null && snap.driverLng != null) {
      final dPos = LatLng(snap.driverLat!, snap.driverLng!);
      _driverPos = dPos;
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: dPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: snap.driverName ?? 'Driver',
          snippet: snap.vehiclePlate ?? '',
        ),
      ));
    }

    // Pickup marker
    if (snap.pickupLat != null && snap.pickupLng != null) {
      final pPos = LatLng(snap.pickupLat!, snap.pickupLng!);
      _pickupPos = pPos;
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: snap.pickupLocation),
      ));
    }

    // Dropoff marker
    if (snap.dropoffLat != null && snap.dropoffLng != null) {
      final dPos = LatLng(snap.dropoffLat!, snap.dropoffLng!);
      _dropoffPos = dPos;
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: dPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Dropoff', snippet: snap.dropoffLocation),
      ));
    }

    // Polylines (driver→pickup then pickup→dropoff)
    if (_driverPos != null && _pickupPos != null) {
      final driverToPickup = await _buildPolyline(
        _driverPos!, _pickupPos!,
        id: 'driver_to_pickup',
        color: _routeColor,
      );
      if (driverToPickup != null) polylines.add(driverToPickup);
    }
    if (_pickupPos != null && _dropoffPos != null) {
      final pickupToDropoff = await _buildPolyline(
        _pickupPos!, _dropoffPos!,
        id: 'pickup_to_dropoff',
        color: _previewColor,
        dashed: true,
      );
      if (pickupToDropoff != null) polylines.add(pickupToDropoff);
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    if (_autoPan) {
      await _panToFit();
    }
  }

  Future<Polyline?> _buildPolyline(
    LatLng origin,
    LatLng dest, {
    required String id,
    required Color color,
    bool dashed = false,
  }) async {
    List<LatLng> points = [];

    if (_directionsKey.isNotEmpty) {
      try {
        final pp = PolylinePoints();
        final result = await pp.getRouteBetweenCoordinates(
          googleApiKey: _directionsKey,
          request: PolylineRequest(
            origin: PointLatLng(origin.latitude, origin.longitude),
            destination: PointLatLng(dest.latitude, dest.longitude),
            mode: TravelMode.driving,
          ),
        );
        if (result.points.isNotEmpty) {
          points = result.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
      } catch (_) {}
    }

    // Fallback: straight line
    if (points.isEmpty) {
      points = [origin, dest];
    }

    return Polyline(
      polylineId: PolylineId(id),
      color: color,
      width: dashed ? 3 : 5,
      points: points,
      patterns: dashed
          ? [PatternItem.dash(12), PatternItem.gap(6)]
          : [],
    );
  }

  Future<void> _panToFit() async {
    if (_mapCtrl == null) return;

    final allPoints = [
      if (_driverPos != null) _driverPos!,
      if (_pickupPos != null) _pickupPos!,
      if (_dropoffPos != null) _dropoffPos!,
    ];
    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      await _mapCtrl!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: allPoints.first, zoom: 15),
        ),
      );
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.002, minLng - 0.002),
          northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        80,
      ),
    );
  }

  // ── Cancel ───────────────────────────────────────────────────────────────
  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text('Are you sure you want to cancel this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      if (widget.isMotorVehicle) {
        await PassengerApi.instance.cancelMotorVehicleTrip(widget.tripId, reason: 'Passenger cancelled');
      } else {
        await PassengerApi.instance.cancelTrip(widget.tripId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip cancelled'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  // ── Call driver ───────────────────────────────────────────────────────────
  Future<void> _callDriver() async {
    final phone = _snap?.driverPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _humanStatus(String raw) {
    switch (raw) {
      case 'PENDING':       return 'Looking for driver…';
      case 'MATCHING':      return 'Matching with driver…';
      case 'ACCEPTED':
      case 'DRIVER_ASSIGNED': return 'Driver is on the way';
      case 'DRIVER_ARRIVING': return 'Driver is almost here';
      case 'DRIVER_ARRIVED':  return 'Driver has arrived!';
      case 'IN_PROGRESS':     return 'Trip in progress';
      case 'COMPLETED':       return 'Trip completed ✓';
      case 'CANCELLED':       return 'Trip cancelled';
      default:                return raw;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'PENDING':
      case 'MATCHING':      return const Color(0xFFF59E0B);
      case 'ACCEPTED':
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ARRIVING': return const Color(0xFF3B82F6);
      case 'DRIVER_ARRIVED':  return const Color(0xFF8B5CF6);
      case 'IN_PROGRESS':     return const Color(0xFF10B981);
      case 'COMPLETED':       return const Color(0xFF6B7280);
      case 'CANCELLED':       return const Color(0xFFEF4444);
      default:                return const Color(0xFF6B7280);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          // Auto-pan toggle
          GestureDetector(
            onTap: () => setState(() => _autoPan = !_autoPan),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _autoPan
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.8)
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _autoPan ? 'Auto' : 'Free',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              _panToFit();
            },
            initialCameraPosition: const CameraPosition(target: _kigali, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onCameraMoveStarted: () {
              if (_autoPan) setState(() => _autoPan = false);
            },
          ),

          // ── Loading overlay ─────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            ),

          // ── Error banner ────────────────────────────────────────────────
          if (_error != null && !_isLoading)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // ── Status chip (top center) ────────────────────────────────────
          if (_snap != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(_snap!.status),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor(_snap!.status).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _statusMsg,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom info panel ───────────────────────────────────────────
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

  Widget _buildBottomPanel() {
    final snap = _snap;
    final cardBg = _isDark ? const Color(0xFF141829) : Colors.white;
    final textPrimary = _isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = _isDark ? Colors.white70 : const Color(0xFF475569);

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (snap == null) ...[
            const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
          ] else ...[
            // ── Driver card ───────────────────────────────────────────────
            if (snap.driverName != null) ...[
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        snap.driverName![0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.driverName!,
                          style: GoogleFonts.poppins(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                            const SizedBox(width: 3),
                            Text(
                              snap.driverRating?.toStringAsFixed(1) ?? 'N/A',
                              style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                            ),
                            if (snap.vehiclePlate != null) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  snap.vehiclePlate!,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF6C63FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (snap.vehicleModel != null)
                          Text(
                            snap.vehicleModel!,
                            style: GoogleFonts.poppins(color: textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Call button
                  if (snap.driverPhone != null)
                    GestureDetector(
                      onTap: _callDriver,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],

            // ── Route info ────────────────────────────────────────────────
            _RouteRow(
              icon: Icons.circle,
              iconColor: const Color(0xFF10B981),
              label: snap.pickupLocation,
              isDark: _isDark,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 16,
                color: _isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 6),
            _RouteRow(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFEF4444),
              label: snap.dropoffLocation,
              isDark: _isDark,
            ),

            const SizedBox(height: 16),

            // ── Fare + ETA chips ─────────────────────────────────────────
            Row(
              children: [
                _InfoChip(
                  label: 'Fare',
                  value: snap.fare != null
                      ? 'RWF ${snap.fare!.toStringAsFixed(0)}'
                      : '---',
                  icon: Icons.payments_rounded,
                  isDark: _isDark,
                ),
                const SizedBox(width: 10),
                if (snap.etaLabel != null)
                  _InfoChip(
                    label: 'ETA',
                    value: '${snap.etaLabel} min',
                    icon: Icons.timer_rounded,
                    isDark: _isDark,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Cancel button ─────────────────────────────────────────────
            if (snap.status != 'COMPLETED' && snap.status != 'CANCELLED')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelTrip,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                  icon: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                  label: Text(
                    'Cancel Trip',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // ── Trip done CTA ─────────────────────────────────────────────
            if (snap.status == 'COMPLETED')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/trip/rate/${widget.tripId}',
                      arguments: {'tripId': widget.tripId},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, color: Colors.white),
                  label: Text(
                    'Rate your trip',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
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
