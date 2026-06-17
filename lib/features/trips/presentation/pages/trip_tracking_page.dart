import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/trip_models.dart';
import 'trip_completion_page.dart';

/// Trip Tracking Page - Shows live driver location and trip status
class TripTrackingPage extends ConsumerStatefulWidget {
  final int tripId;
  final TripData tripData;

  const TripTrackingPage({
    super.key,
    required this.tripId,
    required this.tripData,
  });

  @override
  ConsumerState<TripTrackingPage> createState() => _TripTrackingPageState();
}

class _TripTrackingPageState extends ConsumerState<TripTrackingPage> {
  late TripData _currentTrip;
  String _tripStatus = 'PENDING_DRIVER';
  bool _driverArrived = false;
  bool _tripStarted = false;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.tripData;
    _simulateTripProgress();
  }

  void _simulateTripProgress() {
    // Simulate trip status updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _tripStatus = 'DRIVER_ACCEPTED';
        });
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _tripStatus = 'DRIVER_ARRIVING';
        });
      }
    });

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _driverArrived = true;
          _tripStatus = 'DRIVER_ARRIVED';
        });
      }
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _tripStarted = true;
          _tripStatus = 'TRIP_STARTED';
        });
      }
    });

    // Simulate trip completion after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _tripStatus = 'TRIP_COMPLETED';
        });

        // Navigate to completion page
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TripCompletionPage(
                    tripId: widget.tripId,
                    tripData: _currentTrip,
                  ),
            ),
          );
        });
      }
    });
  }

  void _handleEmergency() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Emergency',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Contacting emergency services...',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(color: const Color(0xFF4C57D6)),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip in Progress',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4C57D6),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Map placeholder with trip status
          Expanded(
            child: Container(
              color: Colors.grey.shade300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Live Tracking Map',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Status indicator
                  _TripStatusIndicator(status: _tripStatus),
                ],
              ),
            ),
          ),
          // Driver Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Information',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C57D6).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Color(0xFF4C57D6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTrip.driver?.name ?? 'Driver Name',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentTrip.driver?.rating.toStringAsFixed(1) ?? '4.8'} (234 trips)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.call,
                            color: Color(0xFF4C57D6),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Calling driver...'),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.message,
                            color: Color(0xFF4C57D6),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Message sent to driver'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_currentTrip.driver?.vehicleModel != null)
                  Text(
                    'Vehicle: ${_currentTrip.driver!.vehicleModel} (${_currentTrip.driver!.vehiclePlate})',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          // Trip Details and Emergency
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Trip details row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TripDetailWidget(
                      icon: Icons.timer,
                      label: 'Time',
                      value: '${_currentTrip.duration ?? 12} min',
                    ),
                    _TripDetailWidget(
                      icon: Icons.location_on,
                      label: 'Distance',
                      value:
                          '${(_currentTrip.distance ?? 2.5).toStringAsFixed(1)} km',
                    ),
                    _TripDetailWidget(
                      icon: Icons.local_offer,
                      label: 'Fare',
                      value: '₦${_currentTrip.estimatedFare}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Emergency button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _handleEmergency,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Emergency',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripStatusIndicator extends StatelessWidget {
  final String status;

  const _TripStatusIndicator({required this.status});

  String _getStatusText() {
    switch (status) {
      case 'PENDING_DRIVER':
        return 'Waiting for driver...';
      case 'DRIVER_ACCEPTED':
        return 'Driver accepted';
      case 'DRIVER_ARRIVING':
        return 'Driver arriving';
      case 'DRIVER_ARRIVED':
        return 'Driver arrived';
      case 'TRIP_STARTED':
        return 'Trip in progress';
      case 'TRIP_COMPLETED':
        return 'Trip completed';
      default:
        return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4C57D6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4C57D6), width: 2),
      ),
      child: Text(
        _getStatusText(),
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4C57D6),
        ),
      ),
    );
  }
}

class _TripDetailWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TripDetailWidget({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4C57D6)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
