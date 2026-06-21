import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../core/services/rtdb_service.dart';
import '../../features/trips/services/motor_vehicle_trip_service.dart';
import '../../features/trips/services/trip_realtime_service.dart';
import '../../features/trips/services/realtime_event_router.dart';
import '../../features/trips/models/motor_vehicle_trip_status.dart';
import '../../models/matching/driver_match_state.dart';

/// Screen displayed while searching for nearby drivers after trip request is created
class DriverMatchingScreen extends ConsumerStatefulWidget {
  final int tripRequestId;
  final String pickupAddress;
  final String dropoffAddress;

  const DriverMatchingScreen({
    super.key,
    required this.tripRequestId,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  ConsumerState<DriverMatchingScreen> createState() =>
      _DriverMatchingScreenState();
}

class _DriverMatchingScreenState extends ConsumerState<DriverMatchingScreen> {
  late final Logger _logger = Logger();
  late final TripRealtimeService _realtimeService;
  late final MotorVehicleTripService _tripService;
  StreamSubscription<dynamic>? _realtimeSubscription;

  DriverMatchState? _matchState;
  bool _isConnected = false;
  String _statusMessage = 'Finding nearby drivers...';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _realtimeService = TripRealtimeService();
    _tripService = MotorVehicleTripService();
    _setupEventCallbacks();
    _initializeRealtime();
  }

  /// Register event callbacks with the event router
  void _setupEventCallbacks() {
    RideConnectEventRouter.onDriverAssigned = _handleDriverAssigned;
    RideConnectEventRouter.onTripCancelled = _handleTripCancelled;
    RideConnectEventRouter.onDriverAccepted = _handleDriverAccepted;
  }

  /// Initialize realtime connection and subscribe to trip channel
  Future<void> _initializeRealtime() async {
    try {
      _logger.i(
        '[DriverMatchingScreen] Initializing realtime for trip ${widget.tripRequestId}',
      );

      // Use Firestore stream listener (watchTrip returns Stream<TripRealtimeEvent>)
      final eventStream = _realtimeService.watchTrip(widget.tripRequestId);
      if (eventStream == null) {
        _logger.w('[DriverMatchingScreen] Realtime unavailable, using polling');
        if (!_isDisposed && mounted) {
          setState(() => _statusMessage = 'Connecting to service...');
        }
        _startPollingFallback();
        return;
      }

      if (!_isDisposed && mounted) {
        setState(() => _isConnected = true);
      }

      // Subscribe to Firestore stream
      _realtimeSubscription = eventStream.listen(
        (event) {
          // Event stream listener - events handled via RideConnectEventRouter
          _logger.d(
            '[DriverMatchingScreen] Received realtime event: ${event.event}',
          );
        },
        onError: (error) {
          _logger.e('[DriverMatchingScreen] Stream error: $error');
          _startPollingFallback();
        },
      );
      _logger.d('[DriverMatchingScreen] Subscribed to trip realtime stream');
    } catch (e, st) {
      _logger.e(
        '[DriverMatchingScreen] Realtime init error: $e',
        error: e,
        stackTrace: st,
      );
      _startPollingFallback();
    }
  }

  /// Handle DriverAssigned event
  void _handleDriverAssigned(Map<String, dynamic> payload) {
    final tripId = payload['trip_id'] as int?;
    if (tripId == null || tripId != widget.tripRequestId) return;

    _logger.i('[DriverMatchingScreen] Driver assigned');

    try {
      final driverId = payload['driver_id'] as int?;
      if (driverId == null) {
        _logger.w('[DriverMatchingScreen] Missing driver_id');
        return;
      }

      final driverData = payload['data'] is Map ? payload['data'] : payload;
      _matchState = DriverMatchState(
        tripId: tripId,
        driverId: driverId,
        driverName: driverData['driver_name'] as String? ?? 'Driver',
        driverRating: (driverData['driver_rating'] as num?)?.toDouble() ?? 0.0,
        driverPhoto: driverData['driver_photo'] as String?,
        vehicleName: driverData['vehicle_name'] as String?,
        licensePlate: driverData['license_plate'] as String?,
        phoneNumber: driverData['phone_number'] as String?,
        status: 'matched',
        matchedAt: DateTime.now(),
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _statusMessage = 'Driver found! Waiting for acceptance...';
        });
        _showToast('Driver found: ${_matchState?.driverName}', Colors.green);
      }
    } catch (e, st) {
      _logger.e(
        '[DriverMatchingScreen] Error processing event: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Handle TripCancelled event
  void _handleTripCancelled(Map<String, dynamic> payload) {
    final tripId = payload['trip_id'] as int?;
    if (tripId == null || tripId != widget.tripRequestId) return;

    _logger.w('[DriverMatchingScreen] Trip cancelled');

    final reason = payload['reason'] as String? ?? 'Unknown reason';
    if (!_isDisposed && mounted) {
      _showToast('Trip cancelled: $reason', Colors.red);
      Navigator.of(context).pop();
    }
  }

  /// Handle DriverAccepted event
  void _handleDriverAccepted(Map<String, dynamic> payload) {
    final tripId = payload['trip_id'] as int?;
    if (tripId == null || tripId != widget.tripRequestId) return;

    _logger.i('[DriverMatchingScreen] Driver accepted');

    if (!_isDisposed && mounted) {
      _showToast('Driver accepted! Tracking now.', Colors.green);
      Navigator.of(
        context,
      ).pushReplacementNamed('/trip-tracking', arguments: widget.tripRequestId);
    }
  }

  /// Fallback polling with exponential backoff
  Future<void> _startPollingFallback() async {
    const intervals = [2, 3, 5, 8];
    var intervalIndex = 0;

    while (!_isDisposed && mounted) {
      try {
        await Future.delayed(
          Duration(
            seconds:
                intervals[intervalIndex >= intervals.length
                    ? intervals.length - 1
                    : intervalIndex],
          ),
        );

        if (_isDisposed || !mounted) break;

        final tripStatus = await _tripService.getTripRequest(
          widget.tripRequestId,
        );
        final phase = tripStatus.phase;

        _logger.d('[DriverMatchingScreen] Poll status: $phase');

        if (_isDisposed || !mounted) break;

        // Use the extension method isTerminal
        if (phase.isTerminal) {
          if (phase == TripLifecyclePhase.tripCompleted) {
            if (!_isDisposed && mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/trip-tracking',
                arguments: widget.tripRequestId,
              );
            }
          } else {
            if (!_isDisposed && mounted) {
              _showToast('Trip ${phase.name}', Colors.red);
              Navigator.of(context).pop();
            }
          }
          return;
        }

        // Increase backoff (capped at 8s)
        if (intervalIndex < intervals.length - 1) {
          intervalIndex++;
        }
      } catch (e) {
        _logger.e('[DriverMatchingScreen] Polling error: $e');
        if (intervalIndex < intervals.length - 1) {
          intervalIndex++;
        }
      }
    }
  }

  /// Show toast using context
  void _showToast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Cancel the trip
  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Trip?'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Looking'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      _showToast('Cancelling...', Colors.orange);
      await _tripService.cancelTripRequest(
        widget.tripRequestId,
        reason: 'User cancelled',
      );
      if (!_isDisposed && mounted) {
        _showToast('Trip cancelled', Colors.green);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('[DriverMatchingScreen] Cancel error: $e');
      if (!_isDisposed && mounted) {
        _showToast('Cancel failed: $e', Colors.red);
      }
    }
  }

  /// Call the driver
  void _callDriver() {
    if (_matchState?.phoneNumber == null) {
      _showToast('No phone available', Colors.red);
      return;
    }
    _logger.i('[DriverMatchingScreen] Call: ${_matchState?.phoneNumber}');
    _showToast('Calling ${_matchState?.driverName}...', Colors.blue);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _realtimeSubscription?.cancel();
    _realtimeService.dispose();
    RideConnectEventRouter.onDriverAssigned = null;
    RideConnectEventRouter.onTripCancelled = null;
    RideConnectEventRouter.onDriverAccepted = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _tripService.cancelTripRequest(widget.tripRequestId, reason: 'User navigated back').catchError((_) {});
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finding Driver'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child:
                      _matchState == null
                          ? _buildSearchingState()
                          : _buildDriverMatchedState(),
                ),
              ),
              _buildTripDetailsSection(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).primaryColor,
                ),
              ),
              Icon(
                Icons.location_searching,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _statusMessage,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _isConnected
            ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Real-time connected',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            )
            : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Connecting...',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildDriverMatchedState() {
    final driver = _matchState!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).primaryColor, width: 3),
          ),
          child: ClipOval(
            child:
                driver.driverPhoto != null
                    ? Image.network(
                      driver.driverPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                    : _defaultAvatar(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          driver.driverName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              driver.driverRating.toStringAsFixed(1),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Waiting for acceptance...',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.person, size: 50, color: Colors.grey[600]),
    );
  }

  Widget _buildTripDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trip Details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _addressRow('Pickup', widget.pickupAddress, Colors.green),
          const SizedBox(height: 12),
          _addressRow('Dropoff', widget.dropoffAddress, Colors.red),
        ],
      ),
    );
  }

  Widget _addressRow(String label, String address, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.location_on, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelTrip,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          if (_matchState != null)
            Expanded(
              child: ElevatedButton(
                onPressed: _callDriver,
                child: const Text('Call Driver'),
              ),
            ),
        ],
      ),
    );
  }
}
