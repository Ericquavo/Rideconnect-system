import 'package:flutter/material.dart';

import '../../domain/matching_lifecycle_models.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final MatchingLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MatchingLifecycleStatus.completed => const Color(0xFF10B981),
      MatchingLifecycleStatus.cancelled ||
      MatchingLifecycleStatus.noDriversAvailable ||
      MatchingLifecycleStatus.driverRejected => const Color(0xFFFF5E5B),
      MatchingLifecycleStatus.driverAcknowledged ||
      MatchingLifecycleStatus.driverArriving ||
      MatchingLifecycleStatus.inProgress => const Color(0xFF3B82F6),
      _ => const Color(0xFF4C57D6),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
