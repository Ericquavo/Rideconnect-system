import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/matching/matching_session.dart';
import '../../../../providers/auth_provider.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import 'trip_matching_page.dart';

class TripInformationPage extends ConsumerStatefulWidget {
  final int tripId;
  final DriverMatch selectedDriver;
  final double? initialFare;

  const TripInformationPage({
    super.key,
    required this.tripId,
    required this.selectedDriver,
    this.initialFare,
  });

  @override
  ConsumerState<TripInformationPage> createState() => _TripInformationPageState();
}

class _TripInformationPageState extends ConsumerState<TripInformationPage> with SingleTickerProviderStateMixin {
  bool _notifying = false;
  bool _notified = false;
  String? _error;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _notifyDriver() async {
    setState(() {
      _notifying = true;
      _error = null;
    });

    try {
      final tripRepo = ref.read(tripRepositoryProvider);
      debugPrint('[TripInformationPage] Notifying driver ${widget.selectedDriver.driverId}...');
      await tripRepo.selectDriver(
        tripId: widget.tripId,
        driverId: widget.selectedDriver.driverId,
      );

      if (mounted) {
        setState(() {
          _notifying = false;
          _notified = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifying = false;
          _error = 'Failed to notify driver: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(authStateProvider);
    final matchState = ref.watch(tripMatchingProvider(widget.tripId));

    // Listen to real-time status changes
    ref.listen<AsyncValue<MatchingLifecycleSnapshot>>(
      tripMatchingProvider(widget.tripId),
      (prev, next) {
        final snap = next.valueOrNull;
        if (snap != null) {
          // If driver confirms, or trip starts, transition immediately to the tracker screen
          if (snap.status == MatchingLifecycleStatus.driverAcknowledged ||
              snap.status == MatchingLifecycleStatus.driverArriving ||
              snap.status == MatchingLifecycleStatus.pickedUp ||
              snap.status == MatchingLifecycleStatus.inProgress) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TripMatchingPage(
                  tripId: widget.tripId,
                  initialStatus: snap.status.apiValue,
                ),
              ),
            );
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          'Trip Information',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: matchState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text(
              'Failed to load trip: $err',
              style: GoogleFonts.poppins(color: const Color(0xFFFF5E5B)),
            ),
          ),
          data: (snapshot) {
            final trip = snapshot.trip;
            final pickupLabel = trip?.pickup.label ?? 'Detecting pickup...';
            final destinationLabel = trip?.destination.label ?? 'Detecting destination...';
            final fareValue = trip?.fare ?? widget.initialFare ?? widget.selectedDriver.estimatedFare;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Trip Card Info
                _buildSectionHeader('Trip details', Icons.route_outlined, isDark),
                const SizedBox(height: 10),
                _buildInfoCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      _buildDetailRow(
                        title: 'Pickup Location',
                        value: pickupLabel,
                        icon: Icons.my_location_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                      const Divider(height: 24, thickness: 1),
                      _buildDetailRow(
                        title: 'Destination',
                        value: destinationLabel,
                        icon: Icons.location_on_rounded,
                        iconColor: const Color(0xFFFF5E5B),
                        isDark: isDark,
                      ),
                      const Divider(height: 24, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Fare',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RWF ${fareValue.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Cash Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Passenger Card Info
                _buildSectionHeader('Passenger details', Icons.person_outline_rounded, isDark),
                const SizedBox(height: 10),
                _buildInfoCard(
                  isDark: isDark,
                  child: userState.when(
                    data: (user) => Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                          child: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Passenger',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.phone ?? 'Contact info not set',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text('Passenger details unavailable', style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Driver Card Info
                _buildSectionHeader('Selected Driver details', Icons.motorcycle_rounded, isDark),
                const SizedBox(height: 10),
                _buildInfoCard(
                  isDark: isDark,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                        backgroundImage: widget.selectedDriver.profilePhotoUrl != null
                            ? NetworkImage(widget.selectedDriver.profilePhotoUrl!)
                            : null,
                        child: widget.selectedDriver.profilePhotoUrl == null
                            ? const Icon(Icons.person_rounded, color: Color(0xFF6C63FF), size: 28)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedDriver.driverName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  widget.selectedDriver.displayRating,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${widget.selectedDriver.distanceKm.toStringAsFixed(1)} km away',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.selectedDriver.vehicle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${widget.selectedDriver.vehicle!.plateNumber} • ${widget.selectedDriver.vehicle!.color} ${widget.selectedDriver.vehicle!.vehicleType}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF5E5B).withOpacity(0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.poppins(color: const Color(0xFFFF5E5B), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Area: Notify Driver or Wait for Feedback
                if (!_notified)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _notifying ? null : _notifyDriver,
                      icon: _notifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.notifications_active_rounded),
                      label: Text(
                        _notifying ? 'Sending request...' : 'Notify Driver',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 2,
                      ),
                    ),
                  )
                else
                  // Widget stating "Wait for driver Feedback"
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Wait for driver Feedback',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required Widget child, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131729) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
