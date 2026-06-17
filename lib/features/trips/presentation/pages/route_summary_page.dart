import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/trip_models.dart';
import '../providers/trips_provider.dart';
import '../../../auth/presentation/widgets/error_dialog.dart';
import 'driver_matching_page.dart';

/// Route Summary Page - Shows map, distance, duration, and estimated fare
class RouteSummaryPage extends ConsumerStatefulWidget {
  final String transportType;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;

  const RouteSummaryPage({
    super.key,
    required this.transportType,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  ConsumerState<RouteSummaryPage> createState() => _RouteSummaryPageState();
}

class _RouteSummaryPageState extends ConsumerState<RouteSummaryPage> {
  RouteData? _routeData;
  bool _isLoading = true;
  String? _error;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _computeRoute();
  }

  Future<void> _computeRoute() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(tripsRepositoryProvider);
      final request = RouteComputeRequest(
        originLat: widget.pickupLat,
        originLng: widget.pickupLng,
        destinationLat: widget.destinationLat,
        destinationLng: widget.destinationLng,
        transportType: widget.transportType,
      );

      final routeData = await repository.computeRoute(request);

      setState(() {
        _routeData = routeData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleBooking() {
    if (_routeData == null) {
      _showErrorDialog('No route data available');
      return;
    }

    if (!_agreedToTerms) {
      _showErrorDialog('Please agree to terms and conditions');
      return;
    }

    // Navigate to create trip page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DriverMatchingPage(
              transportType: widget.transportType,
              pickupAddress: widget.pickupAddress,
              pickupLat: widget.pickupLat,
              pickupLng: widget.pickupLng,
              destinationAddress: widget.destinationAddress,
              destinationLat: widget.destinationLat,
              destinationLng: widget.destinationLng,
              estimatedFare: _routeData!.estimatedFare,
              routeData: _routeData!,
            ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip Summary',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4C57D6),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF4C57D6)),
                ),
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Computing Route',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _computeRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C57D6),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // Map placeholder
                  Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey.shade300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Route Map (placeholder)',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trip Details
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _DetailCard(
                          icon: Icons.location_on,
                          label: 'Pickup',
                          value: widget.pickupAddress,
                        ),
                        const SizedBox(height: 12),
                        _DetailCard(
                          icon: Icons.location_on,
                          label: 'Destination',
                          value: widget.destinationAddress,
                        ),
                        const SizedBox(height: 24),
                        // Pricing Details
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Distance',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '${_routeData!.distance.toStringAsFixed(1)} km',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Duration',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '${_routeData!.durationInMinutes} mins',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Estimated Fare',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₦${_routeData!.estimatedFare}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4C57D6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Terms Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreedToTerms = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF4C57D6),
                            ),
                            Expanded(
                              child: Text(
                                'I agree to the terms and conditions',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Book Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _handleBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C57D6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Confirm Booking',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4C57D6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
