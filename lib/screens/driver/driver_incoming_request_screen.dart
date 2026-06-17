// lib/screens/driver/driver_incoming_request_screen.dart
// Incoming trip request modal with countdown timer

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service_v2.dart';
import 'driver_active_trip_screen.dart';

class DriverIncomingRequestScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String authToken;

  const DriverIncomingRequestScreen({
    super.key,
    required this.payload,
    required this.authToken,
  });

  @override
  State<DriverIncomingRequestScreen> createState() =>
      _DriverIncomingRequestScreenState();
}

class _DriverIncomingRequestScreenState
    extends State<DriverIncomingRequestScreen> {
  late int _secondsRemaining;
  late Timer _countdownTimer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.payload['expires_at'] as String);
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  void _startCountdown(String expiresAtIso) {
    final expiresAt = DateTime.parse(expiresAtIso).toLocal();
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    _secondsRemaining = remaining.clamp(0, 60);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining <= 0) {
          t.cancel();
          _autoReject();
        } else {
          _secondsRemaining--;
        }
      });
    });
  }

  Future<void> _accept() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final tripId = widget.payload['trip_id'] as int;
      final service = TripServiceV2(authToken: widget.authToken);
      final result = await service.respondToTrip(
        tripId: tripId,
        action: 'accept',
      );

      final trip = TripModel.fromJson(result['data'] as Map<String, dynamic>);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => DriverActiveTripScreen(
                  trip: trip,
                  authToken: widget.authToken,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _autoReject() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final tripId = widget.payload['trip_id'] as int;
      final service = TripServiceV2(authToken: widget.authToken);
      await service.respondToTrip(
        tripId: tripId,
        action: 'reject',
        reason: 'timeout',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // Force pop even if the API call fails so the driver isn't stuck
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _reject() async {
    const reasons = ['too_far', 'wrong_direction', 'vehicle_issue', 'other'];

    final selected = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Reject Trip'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    reasons
                        .map(
                          (reason) => ListTile(
                            title: Text(
                              reason.replaceAll('_', ' ').toUpperCase(),
                            ),
                            onTap: () => Navigator.pop(context, reason),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
    );

    if (selected != null) {
      if (_isProcessing) return;

      setState(() => _isProcessing = true);
      try {
        final tripId = widget.payload['trip_id'] as int;
        final service = TripServiceV2(authToken: widget.authToken);
        await service.respondToTrip(
          tripId: tripId,
          action: 'reject',
          reason: selected,
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickupLocation = widget.payload['pickup_location'] as String;
    final dropoffLocation = widget.payload['dropoff_location'] as String;
    final fare = double.tryParse(widget.payload['fare'].toString()) ?? 0;
    final transportType = widget.payload['transport_type'] as String? ?? 'car';
    final passengerName =
        widget.payload['passenger_name'] as String? ?? 'Passenger';

    final iconMap = {'moto': '🏍️', 'car': '🚗', 'bus': '🚌'};
    final icon = iconMap[transportType] ?? '🚗';

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔔 New Ride Request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Passenger:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(passengerName),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transport:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('$icon ${transportType.toUpperCase()}'),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📍 Pickup:\n',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Expanded(child: Text(pickupLocation)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🏁 Dropoff:\n',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Expanded(child: Text(dropoffLocation)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fare:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'RWF ${fare.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⏱ Expires in: '),
                  Text(
                    _secondsRemaining.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const Text(' seconds'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    onPressed: _isProcessing ? null : _reject,
                    child: const Text(
                      '✗ Reject',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: _isProcessing ? null : _accept,
                    child:
                        _isProcessing
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              '✓ Accept',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
