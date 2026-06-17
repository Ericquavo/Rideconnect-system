import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/passenger_api.dart';

class SearchingDriverScreen extends StatefulWidget {
  final int tripId;

  const SearchingDriverScreen({super.key, required this.tripId});

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> {
  Timer? _statusTimer;
  Timer? _elapsedTimer;
  StreamSubscription<DatabaseEvent>? _rtdbSubscription;

  String _statusMessage = 'Finding nearby drivers...';
  String? _error;
  int _secondsElapsed = 0;

  String _tripStatus = 'PENDING';
  String? _matchingStatus;

  // Trip details for fallback assignment
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;
  String? _pickupLocation;
  String? _dropoffLocation;
  double? _estimatedFare;

  String _passengerName = 'Passenger';
  String _passengerPhone = '';

  final Set<int> _triedDriverIds = {};
  bool _isFallbackActive = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Matching] Passenger started searching screen for Trip ID: ${widget.tripId}');
    _loadPassengerProfile();
    _startPolling();
    _subscribeToRtdb();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });

        // 60-second timeout check
        if (_secondsElapsed >= 60 && !_isFallbackActive) {
          final isStillMatching = _tripStatus == 'PENDING' ||
              _tripStatus == 'REQUESTED' ||
              _tripStatus == 'MATCHING' ||
              _tripStatus == 'MATCHING_PENDING';
          if (isStillMatching) {
            _triggerFallbackAssignment();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _elapsedTimer?.cancel();
    _rtdbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPassengerProfile() async {
    try {
      final profile = await PassengerApi.instance.getProfile();
      final data = profile['data'] ?? profile;
      if (mounted) {
        setState(() {
          _passengerName = (data['name'] ?? 'Passenger').toString();
          _passengerPhone = (data['phone'] ?? '').toString();
        });
        debugPrint('[Matching] Loaded passenger profile: $_passengerName, phone: $_passengerPhone');
      }
    } catch (e) {
      debugPrint('[Matching] Error loading passenger profile: $e');
    }
  }

  void _subscribeToRtdb() {
    debugPrint('[Matching] Subscribing to RTDB node active_trips/${widget.tripId}');
    _rtdbSubscription = FirebaseDatabase.instance
        .ref('active_trips/${widget.tripId}')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        if (data is Map) {
          final typedData = Map<String, dynamic>.from(data);
          _handleStatusUpdate(typedData, 'RTDB');
        }
      }
    }, onError: (err) {
      debugPrint('[Matching] RTDB subscription error: $err');
    });
  }

  void _startPolling() {
    _checkStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      // Fetch trip details. We try the specific motor-vehicle endpoint first, then fallback.
      Map<String, dynamic> data = {};
      try {
        data = await PassengerApi.instance.getMotorVehicleTrip(widget.tripId);
      } catch (_) {
        data = await PassengerApi.instance.getTripStatus(widget.tripId);
      }
      
      _handleStatusUpdate(data, 'Polling');
    } catch (e) {
      // Ignore network hiccups, keep polling
      debugPrint('[Matching] Polling error: $e');
    }
  }

  void _handleStatusUpdate(Map<String, dynamic> data, String source) {
    if (!mounted) return;

    final newStatus = (data['status'] ?? data['trip_status'] ?? _tripStatus).toString().toUpperCase();
    final newMatchingStatus = data['matching_status']?.toString();

    // Parse coordinates and addresses
    _pickupLat = double.tryParse((data['pickup_lat'] ?? data['pickup_latitude'] ?? '').toString()) ?? _pickupLat;
    _pickupLng = double.tryParse((data['pickup_lng'] ?? data['pickup_longitude'] ?? '').toString()) ?? _pickupLng;
    _dropoffLat = double.tryParse((data['dropoff_lat'] ?? data['dropoff_latitude'] ?? '').toString()) ?? _dropoffLat;
    _dropoffLng = double.tryParse((data['dropoff_lng'] ?? data['dropoff_longitude'] ?? '').toString()) ?? _dropoffLng;
    _pickupLocation = (data['pickup_location'] ?? data['pickup_name'] ?? _pickupLocation)?.toString();
    _dropoffLocation = (data['dropoff_location'] ?? data['dropoff_name'] ?? _dropoffLocation)?.toString();
    _estimatedFare = double.tryParse((data['estimated_fare'] ?? data['fare'] ?? '').toString()) ?? _estimatedFare;

    setState(() {
      _tripStatus = newStatus;
      _matchingStatus = newMatchingStatus;
      if (!_isFallbackActive) {
        _statusMessage = _getStatusLabel(newStatus, newMatchingStatus);
      }
    });

    // PENDING -> SEARCHING -> MATCHED -> ACCEPTED -> DRIVER_ARRIVING -> DRIVER_ARRIVED -> IN_PROGRESS -> COMPLETED -> CANCELLED
    if (newStatus == 'ACCEPTED' ||
        newStatus == 'MATCHED' ||
        newStatus == 'DRIVER_ASSIGNED' ||
        newStatus == 'DRIVER_ARRIVING' ||
        newStatus == 'DRIVER_ARRIVED' ||
        newStatus == 'IN_PROGRESS') {
      _statusTimer?.cancel();
      _elapsedTimer?.cancel();
      _rtdbSubscription?.cancel();
      
      debugPrint('[Matching] Trip accepted/assigned! Navigating to tracking screen.');
      Navigator.pushReplacementNamed(
        context,
        '/trip/track/${widget.tripId}',
      );
    } else if (newStatus == 'CANCELLED' || newStatus == 'EXPIRED') {
      _statusTimer?.cancel();
      _elapsedTimer?.cancel();
      _rtdbSubscription?.cancel();
      setState(() {
        _error = 'Trip request was cancelled or expired.';
      });
    }
  }

  String _getStatusLabel(String status, String? matchingStatus) {
    if (status == 'PENDING' || status == 'REQUESTED') {
      return 'Creating ride request...';
    }
    if (status == 'MATCHING' || status == 'MATCHING_PENDING') {
      return 'Smart matching started...';
    }
    return 'Finding your driver...';
  }

  Future<void> _triggerFallbackAssignment() async {
    if (_isFallbackActive) return;
    setState(() => _isFallbackActive = true);

    debugPrint('[Matching] 60s timeout reached. Status is $_tripStatus. Triggering fallback assignment...');

    if (mounted) {
      setState(() {
        _statusMessage = "We're having trouble finding a driver using smart matching. Searching nearby available drivers...";
      });
    }

    try {
      final lat = _pickupLat;
      final lng = _pickupLng;

      if (lat == null || lng == null) {
        debugPrint('[Matching] Cannot run fallback matching: pickup coordinates are null.');
        setState(() => _isFallbackActive = false);
        return;
      }

      debugPrint('[Matching] Querying nearby drivers around ($lat, $lng)...');
      final drivers = await PassengerApi.instance.getNearbyDrivers(lat: lat, lng: lng);
      debugPrint('[Matching] Found ${drivers.length} nearby drivers.');

      if (drivers.isEmpty) {
        debugPrint('[Matching] No nearby drivers returned from API.');
        setState(() => _isFallbackActive = false);
        return;
      }

      final List<Map<String, dynamic>> eligibleDrivers = [];

      for (final driver in drivers) {
        final driverId = getDriverId(driver);
        if (driverId == null) continue;

        if (_triedDriverIds.contains(driverId)) {
          debugPrint('[Matching] Skipping driver $driverId (already tried).');
          continue;
        }

        // Query RTDB for drivers_online/{driverId} status
        final rtdbStatusRef = FirebaseDatabase.instance.ref('drivers_online/$driverId');
        final snapshot = await rtdbStatusRef.get();

        if (snapshot.exists) {
          final val = snapshot.value;
          if (val is Map) {
            final status = val['status']?.toString().toLowerCase();
            final available = val['available'] != false && val['available']?.toString().toLowerCase() != 'false';

            if (status == 'online' && available) {
              eligibleDrivers.add(driver);
            } else {
              debugPrint('[Matching] Driver $driverId not available (status=$status, available=$available).');
            }
          } else {
            eligibleDrivers.add(driver);
          }
        } else {
          eligibleDrivers.add(driver);
        }
      }

      if (eligibleDrivers.isEmpty) {
        debugPrint('[Matching] No online & available drivers found in database.');
        setState(() => _isFallbackActive = false);
        return;
      }

      // Sort by distance (Haversine)
      eligibleDrivers.sort((a, b) {
        final latA = getLat(a) ?? 0.0;
        final lngA = getLng(a) ?? 0.0;
        final latB = getLat(b) ?? 0.0;
        final lngB = getLng(b) ?? 0.0;

        final distA = calculateHaversineDistance(lat, lng, latA, lngA);
        final distB = calculateHaversineDistance(lat, lng, latB, lngB);
        return distA.compareTo(distB);
      });

      final nearestDriver = eligibleDrivers.first;
      final nearestDriverId = getDriverId(nearestDriver);
      final nearestDriverName = nearestDriver['name'] ?? nearestDriver['driver_name'] ?? 'Driver';
      final nearestDriverPhone = nearestDriver['phone'] ?? nearestDriver['driver_phone'] ?? '';

      if (nearestDriverId == null) {
        setState(() => _isFallbackActive = false);
        return;
      }

      debugPrint('[Matching] Nearest available driver selected: $nearestDriverName (ID: $nearestDriverId)');
      _triedDriverIds.add(nearestDriverId);

      // Perform direct assignment to RTDB
      debugPrint('[Matching] Writing assignment to RTDB...');
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final assignedTripPayload = {
        'trip_id': widget.tripId,
        'passenger_name': _passengerName,
        'passenger_phone': _passengerPhone,
        'pickup_location': _pickupLocation ?? 'Pickup',
        'dropoff_location': _dropoffLocation ?? 'Destination',
        'pickup_lat': lat,
        'pickup_lng': lng,
        'dropoff_lat': _dropoffLat ?? 0.0,
        'dropoff_lng': _dropoffLng ?? 0.0,
        'fare': _estimatedFare ?? 0.0,
        'status': 'ASSIGNED',
        'timestamp': timestamp,
      };

      await FirebaseDatabase.instance
          .ref('drivers_online/$nearestDriverId/assigned_trip')
          .set(assignedTripPayload);

      final activeTripPayload = {
        'trip_id': widget.tripId,
        'status': 'ASSIGNED',
        'driver_id': nearestDriverId,
        'driver_name': nearestDriverName,
        'driver_phone': nearestDriverPhone,
        'pickup_lat': lat,
        'pickup_lng': lng,
        'dropoff_lat': _dropoffLat ?? 0.0,
        'dropoff_lng': _dropoffLng ?? 0.0,
        'fare': _estimatedFare ?? 0.0,
        'updated_at': timestamp,
      };

      await FirebaseDatabase.instance
          .ref('active_trips/${widget.tripId}')
          .set(activeTripPayload);

      // Call backend API background fallbacks
      debugPrint('[Matching] Call fallback endpoints...');
      await PassengerApi.instance.assignDriverToTrip(widget.tripId, nearestDriverId);

      debugPrint('[Matching] Direct fallback assignment completed.');
    } catch (e) {
      debugPrint('[Matching] Error in fallback assignment: $e');
    } finally {
      if (mounted) {
        setState(() => _isFallbackActive = false);
      }
    }
  }

  double? getLat(Map<String, dynamic> driver) {
    final loc = driver['current_location'] ?? driver['location'] ?? driver;
    if (loc is Map) {
      return double.tryParse(loc['latitude']?.toString() ?? '') ?? 
             double.tryParse(loc['lat']?.toString() ?? '');
    }
    return null;
  }

  double? getLng(Map<String, dynamic> driver) {
    final loc = driver['current_location'] ?? driver['location'] ?? driver;
    if (loc is Map) {
      return double.tryParse(loc['longitude']?.toString() ?? '') ?? 
             double.tryParse(loc['lng']?.toString() ?? '');
    }
    return null;
  }

  int? getDriverId(Map<String, dynamic> driver) {
    final d = driver['driver'] ?? driver;
    if (d is Map) {
      return int.tryParse(d['driver_id']?.toString() ?? '') ??
             int.tryParse(d['user_id']?.toString() ?? '') ??
             int.tryParse(d['id']?.toString() ?? '');
    }
    return int.tryParse(driver['driver_id']?.toString() ?? '') ??
           int.tryParse(driver['id']?.toString() ?? '');
  }

  double calculateHaversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180.0;
  }

  int _getCurrentStep(String status, String? matchingStatus) {
    final s = status.toUpperCase();
    final ms = matchingStatus?.toUpperCase() ?? '';

    if (s == 'IN_PROGRESS' || s == 'COMPLETED' || s == 'DRIVER_ARRIVED') {
      return 5;
    }
    if (s == 'DRIVER_ACCEPTED' || s == 'ACCEPTED') {
      return 4;
    }
    if (s == 'ASSIGNED' || s == 'DRIVER_ASSIGNED' || s == 'DRIVER_NOTIFIED' || s == 'MATCHED') {
      return 3;
    }
    if (s == 'SEARCHING_CANDIDATES' || ms == 'SEARCHING' || ms == 'RETRYING' || _isFallbackActive) {
      return 2;
    }
    if (s == 'MATCHING' || s == 'MATCHING_PENDING') {
      return 1;
    }
    if (s == 'REQUESTED' || s == 'PENDING') {
      return 0;
    }
    return 0;
  }

  Future<void> _cancelTrip() async {
    _statusTimer?.cancel();
    _rtdbSubscription?.cancel();
    setState(() {
      _statusMessage = 'Cancelling request...';
    });

    try {
      try {
        await PassengerApi.instance.cancelMotorVehicleTrip(widget.tripId);
      } catch (_) {
        await PassengerApi.instance.cancelTrip(widget.tripId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip cancelled.')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cancelling trip: ${e.toString().replaceFirst('Exception: ', '')}';
        });
        _startPolling();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    final timerString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium header
                Text(
                  'Matching Status',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elapsed Time: $timerString',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                
                // Timeline checklist Progress Screen
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildVerticalTimeline(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                OutlinedButton.icon(
                  onPressed: _cancelTrip,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                  label: Text(
                    'Cancel Request',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalTimeline() {
    final currentStep = _getCurrentStep(_tripStatus, _matchingStatus);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF111827) 
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineStep('Trip Created', currentStep >= 0, currentStep == 0),
          _buildTimelineDivider(currentStep > 0),
          _buildTimelineStep('Matching Started', currentStep >= 1, currentStep == 1),
          _buildTimelineDivider(currentStep > 1),
          _buildTimelineStep('Looking for Nearby Drivers', currentStep >= 2, currentStep == 2),
          _buildTimelineDivider(currentStep > 2),
          _buildTimelineStep('Driver Assigned', currentStep >= 3, currentStep == 3),
          _buildTimelineDivider(currentStep > 3),
          _buildTimelineStep('Driver Accepted', currentStep >= 4, currentStep == 4),
          _buildTimelineDivider(currentStep > 4),
          _buildTimelineStep('Driver Arriving', currentStep >= 5, currentStep == 5),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String title, bool isCompleted, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isCompleted 
        ? const Color(0xFF10B981) 
        : (isActive ? const Color(0xFF2D8CFF) : Colors.grey[400]);
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color?.withOpacity(0.12),
            border: Border.all(
              color: color ?? Colors.grey,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF10B981))
                : (isActive
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF2D8CFF)),
                        ),
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[400],
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isCompleted || isActive ? FontWeight.w600 : FontWeight.w400,
              color: isCompleted || isActive
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : Colors.grey[500],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDivider(bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(left: 15),
      height: 20,
      width: 2,
      color: isCompleted ? const Color(0xFF10B981) : Colors.grey[300],
    );
  }
}
