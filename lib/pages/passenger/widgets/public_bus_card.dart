import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../public_bus_models.dart';

class PublicBusCard extends StatelessWidget {
  const PublicBusCard({
    super.key,
    required this.assignment,
    required this.selected,
    required this.onSelect,
    required this.onDetails,
    required this.selectLabel,
    required this.selectedLabel,
  });

  final PublicBusAssignment assignment;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDetails;
  final String selectLabel;
  final String selectedLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        selected
            ? const Color(0xFF3B82F6)
            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));
    final background = isDark ? const Color(0xFF11162A) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
            boxShadow: [
              BoxShadow(
                color:
                    selected
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.06),
                blurRadius: selected ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BusAvatar(photoUrl: assignment.busPhotoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              assignment.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          _BusBadge(
                            label: '${assignment.availableSeats ?? 0}',
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          _BusBadge(
                            label: 'ETA ${assignment.etaLabel}',
                            color: const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.driverSummary,
                        style: GoogleFonts.poppins(
                          color:
                              isDark ? Colors.white70 : const Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.footerSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color:
                              isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onSelect,
                          icon: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.touch_app_rounded,
                            size: 18,
                          ),
                          label: Text(selected ? selectedLabel : selectLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusAvatar extends StatelessWidget {
  const _BusAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF64748B)),
    );

    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: 56, height: 56, child: fallback),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _BusBadge extends StatelessWidget {
  const _BusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
