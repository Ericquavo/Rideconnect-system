// lib/ui/driver/driver_match_modal.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service_v2.dart';

/// A bottom sheet modal that displays incoming trip request details
/// and allows the driver to accept or decline the request.
class DriverMatchModal extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String token;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const DriverMatchModal({
    Key? key,
    required this.tripData,
    required this.token,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  _DriverMatchModalState createState() => _DriverMatchModalState();

  /// Helper to show the modal.
  static void show(
    BuildContext context,
    Map<String, dynamic> tripData,
    String token,
    VoidCallback onAccept,
    VoidCallback onDecline,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (_) => DriverMatchModal(
        tripData: tripData,
        token: token,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }
}

class _DriverMatchModalState extends State<DriverMatchModal> {
  late int _secondsRemaining;
  late Timer _countdownTimer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.tripData['expires_at'] as String);
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
          Navigator.of(context).pop();
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
      final tripId = widget.tripData['trip_id'] as int;
      final service = TripServiceV2(authToken: widget.token);
      final result = await service.respondToTrip(
        tripId: tripId,
        action: 'accept',
      );
      final trip = TripModel.fromJson(result['data'] as Map<String, dynamic>);
      widget.onAccept();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamed(
          '/driver/navigate/${tripId}',
          arguments: {
            'passengerLat': trip.pickupLat,
            'passengerLng': trip.pickupLng,
            'dropoffLat': trip.dropoffLat,
            'dropoffLng': trip.dropoffLng,
            'passengerName': widget.tripData['passenger_name'] ?? 'Passenger',
            'passengerPhone': widget.tripData['passenger_phone'] ?? '',
            'pickupAddress': trip.pickupLocation,
            'dropoffAddress': trip.dropoffLocation,
            'estimatedFare': trip.fare,
          },
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

  Future<void> _reject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final tripId = widget.tripData['trip_id'] as int;
      final service = TripServiceV2(authToken: widget.token);
      await service.respondToTrip(
        tripId: tripId,
        action: 'reject',
        reason: 'driver_decline',
      );
      widget.onDecline();
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

  @override
  Widget build(BuildContext context) {
    final pickup = widget.tripData['pickup_location'] as String;
    final dropoff = widget.tripData['dropoff_location'] as String;
    final fare = double.tryParse(widget.tripData['fare'].toString()) ?? 0;
    final transport = widget.tripData['transport_type'] as String? ?? 'car';
    final passenger = widget.tripData['passenger_name'] as String? ?? 'Passenger';
    final iconMap = {'moto': '🏍️', 'car': '🚗', 'bus': '🚌'};
    final icon = iconMap[transport] ?? '🚗';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔔 New Ride Request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _infoCard('Passenger', passenger),
            const SizedBox(height: 12),
            _infoCard('Transport', '$icon ${transport.toUpperCase()}'),
            const Divider(height: 20),
            _infoCard('📍 Pickup', pickup),
            const SizedBox(height: 12),
            _infoCard('🏁 Dropoff', dropoff),
            const Divider(height: 20),
            _infoCard('Fare', 'RWF ${fare.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            _countdownWidget(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    onPressed: _isProcessing ? null : _reject,
                    child: const Text('✗ Reject', style: TextStyle(color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _isProcessing ? null : _accept,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('✓ Accept', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _countdownWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[700]),
          ),
          const Text(' seconds'),
        ],
      ),
    );
  }
}

// End of file
