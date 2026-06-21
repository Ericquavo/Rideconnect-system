import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/matching/matching_session.dart';
import '../../domain/matching_lifecycle_models.dart';
import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';
import 'trip_matching_page.dart';
import 'trip_information_page.dart';

class BestMatchesDriverPage extends ConsumerStatefulWidget {
  final int tripId;
  final List<DriverMatch> candidates;
  final double? initialFare;

  const BestMatchesDriverPage({
    super.key,
    required this.tripId,
    required this.candidates,
    this.initialFare,
  });

  @override
  ConsumerState<BestMatchesDriverPage> createState() => _BestMatchesDriverPageState();
}

class _BestMatchesDriverPageState extends ConsumerState<BestMatchesDriverPage> {
  bool _selecting = false;
  int? _selectedDriverId;
  String? _error;

  void _selectDriver(int driverId) {
    final selectedDriverMatch = widget.candidates.firstWhere(
      (c) => c.driverId == driverId,
      orElse: () => widget.candidates.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripInformationPage(
          tripId: widget.tripId,
          selectedDriver: selectedDriverMatch,
          initialFare: widget.initialFare,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          'Best Matches Driver',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Drivers Nearby',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select one of the drivers below to request a ride from them directly.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF5E5B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5E5B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF5E5B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: widget.candidates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.two_wheeler_rounded,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No drivers returned in range',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.candidates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final driver = widget.candidates[index];
                          final isThisSelected = _selectedDriverId == driver.driverId;

                          return GestureDetector(
                            onTap: _selecting ? null : () => _selectDriver(driver.driverId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131729) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isThisSelected
                                      ? const Color(0xFF6C63FF)
                                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                                  width: isThisSelected ? 2 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Driver Avatar
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                                    backgroundImage: driver.profilePhotoUrl != null
                                        ? NetworkImage(driver.profilePhotoUrl!)
                                        : null,
                                    child: driver.profilePhotoUrl == null
                                        ? const Icon(Icons.person_rounded, color: Color(0xFF6C63FF), size: 28)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  // Driver info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver.driverName,
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
                                              driver.displayRating,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${driver.distanceKm.toStringAsFixed(1)} km away',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: isDark ? Colors.white54 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (driver.vehicle != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '${driver.vehicle!.plateNumber} • ${driver.vehicle!.color} ${driver.vehicle!.vehicleType}',
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
                                  // Action or ETA / Fare
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'RWF ${driver.estimatedFare.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${driver.estimatedArrivalMinutes} min ETA',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6C63FF),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
