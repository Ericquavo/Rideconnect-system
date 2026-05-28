import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/trip_models.dart';

class TripStatusTimeline extends StatelessWidget {
  const TripStatusTimeline({super.key, required this.status});

  final TripStatus status;

  static const _steps = <TripStatus>[
    TripStatus.requested,
    TripStatus.matched,
    TripStatus.driverConfirmed,
    TripStatus.driverArriving,
    TripStatus.pickedUp,
    TripStatus.inProgress,
    TripStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _steps.indexOf(status);
    final isCancelled =
        status == TripStatus.cancelled || status == TripStatus.disputed;
    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isDone = !isCancelled && activeIndex >= index;
        final isCurrent = !isCancelled && activeIndex == index;
        final color =
            isCancelled
                ? const Color(0xFFFF5E5B)
                : isDone
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.circle,
                  color: Colors.white,
                  size: isDone ? 16 : 8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
