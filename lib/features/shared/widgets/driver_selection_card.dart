import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rideconnect_app/models/matching/matching_session.dart';

class DriverSelectionCard extends StatelessWidget {
  final DriverMatch driver;
  final bool isSelected;
  final bool isLocked;
  final bool isRejected;
  final VoidCallback onTap;

  const DriverSelectionCard({
    super.key,
    required this.driver,
    required this.isSelected,
    required this.isLocked,
    required this.isRejected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isRejected) {
      return _buildRejectedCard(context, isDarkMode);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: driver.canSelect && !isLocked ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? const Color(0xFF1A1F3A)
                    : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFF5B21B6)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.09)
                          : const Color(0xFFC9D6F2)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: const Color(0xFF5B21B6).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                    : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header: Avatar + Name + Rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade300,
                      ),
                      child:
                          driver.profilePhotoUrl != null
                              ? ClipOval(
                                child: Image.network(
                                  driver.profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Icon(
                                        Icons.person,
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                              )
                              : Icon(Icons.person, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    // Name + Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.driverName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color:
                                  isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Rating
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                driver.displayRating,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Behavior Score Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getBehaviorScoreColor(
                                    driver.behaviorScore,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  driver.behaviorScoreBadge,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Selection Indicator
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5B21B6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Vehicle Info
                if (driver.vehicle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color:
                              isDarkMode
                                  ? Colors.white60
                                  : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${driver.vehicle!.vehicleType} • ${driver.vehicle!.plateNumber}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color:
                                  isDarkMode
                                      ? Colors.white60
                                      : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Footer: ETA, Fare, Distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ETA
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ETA',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color:
                                isDarkMode
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${driver.estimatedArrivalMinutes} min',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    // Distance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Distance',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color:
                                isDarkMode
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${driver.distanceKm.toStringAsFixed(1)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    // Fare
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Fare',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color:
                                isDarkMode
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'RWF ${driver.estimatedFare.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Lock Status if locked
                if (isLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_clock,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Driver temporarily unavailable',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedCard(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? const Color(0xFF1A1F3A).withValues(alpha: 0.5)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.driverName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color:
                            isDarkMode ? Colors.white60 : Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rejected request',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBehaviorScoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 4.5) return Colors.green;
    if (score >= 4.0) return Colors.blue;
    if (score >= 3.5) return Colors.orange;
    return Colors.red;
  }
}
