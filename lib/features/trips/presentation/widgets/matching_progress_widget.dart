import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/matching_lifecycle_models.dart';

class MatchingProgressWidget extends StatelessWidget {
  const MatchingProgressWidget({super.key, required this.status});

  final MatchingLifecycleStatus status;

  static const _steps = <MatchingLifecycleStatus>[
    MatchingLifecycleStatus.tripRequested,
    MatchingLifecycleStatus.searchingCandidates,
    MatchingLifecycleStatus.mlMatching,
    MatchingLifecycleStatus.driverSelected,
    MatchingLifecycleStatus.driverNotified,
    MatchingLifecycleStatus.driverAcknowledged,
  ];

  @override
  Widget build(BuildContext context) {
    final index = _steps.indexOf(status).clamp(0, _steps.length - 1);
    final progress = (index + 1) / _steps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4C57D6)),
            const SizedBox(width: 8),
            Text(
              status.label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: status.isTerminal ? 1 : progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            color:
                status == MatchingLifecycleStatus.noDriversAvailable ||
                        status == MatchingLifecycleStatus.cancelled
                    ? const Color(0xFFFF5E5B)
                    : const Color(0xFF4C57D6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _steps.map((step) {
                final done = _steps.indexOf(step) <= index;
                return Chip(
                  avatar: Icon(
                    done ? Icons.check_rounded : Icons.circle_outlined,
                    size: 16,
                  ),
                  label: Text(step.label),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
        ),
      ],
    );
  }
}
