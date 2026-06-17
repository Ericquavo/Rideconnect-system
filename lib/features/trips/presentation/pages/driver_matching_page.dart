import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/trip_models.dart';
import '../providers/trips_provider.dart';
import '../../../auth/presentation/widgets/error_dialog.dart';
import 'trip_tracking_page.dart';

/// Driver Matching Page - Shows searching for driver UI and handles trip creation
class DriverMatchingPage extends ConsumerStatefulWidget {
  final String transportType;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final int estimatedFare;
  final RouteData routeData;

  const DriverMatchingPage({
    super.key,
    required this.transportType,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.estimatedFare,
    required this.routeData,
  });

  @override
  ConsumerState<DriverMatchingPage> createState() => _DriverMatchingPageState();
}

class _DriverMatchingPageState extends ConsumerState<DriverMatchingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _candidateCount = 0;
  bool _tripCreated = false;
  TripData? _createdTrip;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _createTrip();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _createTrip() async {
    try {
      final repository = ref.read(tripsRepositoryProvider);
      final createRequest = CreateTripRequest(
        originLat: widget.pickupLat,
        originLng: widget.pickupLng,
        originAddress: widget.pickupAddress,
        destinationLat: widget.destinationLat,
        destinationLng: widget.destinationLng,
        destinationAddress: widget.destinationAddress,
        transportType: widget.transportType,
        estimatedFare: widget.estimatedFare,
      );

      final tripData = await repository.createTrip(createRequest, widget.transportType);

      if (mounted) {
        setState(() {
          _tripCreated = true;
          _createdTrip = tripData;
        });

        // Simulate candidate count updates
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _candidateCount = 2);
          }
        });

        // Auto navigate to tracking after 5 seconds or when driver accepts
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _createdTrip != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => TripTrackingPage(
                      tripId: _createdTrip!.tripId,
                      tripData: _createdTrip!,
                    ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(message: e.toString()),
        );
      }
    }
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Cancel Trip',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure you want to cancel this trip?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'No',
                  style: GoogleFonts.poppins(color: const Color(0xFF4C57D6)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  'Yes',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleCancel();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Finding Driver',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF4C57D6),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body:
            !_tripCreated
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4C57D6)),
                  ),
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated search icon
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C57D6).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search,
                          size: 60,
                          color: Color(0xFF4C57D6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Looking for drivers...',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_candidateCount > 0)
                      Text(
                        'Found $_candidateCount driver(s)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      Text(
                        'Searching in your area',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Trip Details
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: Color(0xFF4C57D6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      widget.pickupAddress,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: Color(0xFF4C57D6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      widget.destinationAddress,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimated Fare',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '₦${widget.estimatedFare}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4C57D6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Cancel Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _handleCancel,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
