import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/matching_lifecycle_models.dart';

class MatchingProgressWidget extends StatefulWidget {
  const MatchingProgressWidget({super.key, required this.status});

  final MatchingLifecycleStatus status;

  @override
  State<MatchingProgressWidget> createState() => _MatchingProgressWidgetState();
}

class _MatchingProgressWidgetState extends State<MatchingProgressWidget> {
  Timer? _timer;
  int _waitingTicks = 0;

  static const _steps = <_ProgressStep>[
    _ProgressStep(
      status: MatchingLifecycleStatus.tripRequested,
      label: 'Trip Requested',
      icon: Icons.check_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.searchingCandidates,
      label: 'Searching Driver',
      icon: Icons.search_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.mlMatching,
      label: 'ML Matching',
      icon: Icons.auto_awesome_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.driverSelected,
      label: 'Driver Selected',
      icon: Icons.person_search_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.driverNotified,
      label: 'Driver Notified',
      icon: Icons.notifications_active_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.driverAcknowledged,
      label: 'Driver Accepted',
      icon: Icons.verified_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.driverArriving,
      label: 'Driver Coming',
      icon: Icons.two_wheeler_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.pickedUp,
      label: 'Driver Arrived',
      icon: Icons.location_on_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.inProgress,
      label: 'Trip Started',
      icon: Icons.route_rounded,
    ),
    _ProgressStep(
      status: MatchingLifecycleStatus.completed,
      label: 'Completed',
      icon: Icons.flag_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _configureTicker();
  }

  @override
  void didUpdateWidget(covariant MatchingProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _waitingTicks = 0;
      _configureTicker();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _configureTicker() {
    _timer?.cancel();
    if (!_canLocallyAdvance(widget.status)) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _waitingTicks++);
    });
  }

  bool _canLocallyAdvance(MatchingLifecycleStatus status) {
    return status == MatchingLifecycleStatus.tripRequested ||
        status == MatchingLifecycleStatus.searchingCandidates;
  }

  int _indexFor(MatchingLifecycleStatus status) {
    final index = _steps.indexWhere((step) => step.status == status);
    if (index >= 0) return index;
    if (status == MatchingLifecycleStatus.reassigningDriver) return 2;
    if (status == MatchingLifecycleStatus.driverRejected) return 2;
    if (status == MatchingLifecycleStatus.noDriversAvailable) return 2;
    if (status == MatchingLifecycleStatus.cancelled) return 0;
    return 0;
  }

  int _displayIndex() {
    final actual = _indexFor(widget.status);
    if (widget.status == MatchingLifecycleStatus.tripRequested) {
      return (actual + _waitingTicks).clamp(0, 2);
    }
    if (widget.status == MatchingLifecycleStatus.searchingCandidates) {
      return (actual + (_waitingTicks ~/ 2)).clamp(actual, 2);
    }
    return actual;
  }

  Color _statusColor() {
    if (widget.status == MatchingLifecycleStatus.cancelled ||
        widget.status == MatchingLifecycleStatus.noDriversAvailable) {
      return const Color(0xFFFF5E5B);
    }
    if (widget.status == MatchingLifecycleStatus.completed) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFF4C57D6);
  }

  @override
  Widget build(BuildContext context) {
    final displayIndex = _displayIndex();
    final activeStep = _steps[displayIndex];
    final progress =
        widget.status.isTerminal
            ? 1.0
            : ((displayIndex + 1) / _steps.length).clamp(0.08, 1.0);
    final color = _statusColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(activeStep.icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeStep.label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _steps.map((step) {
                final index = _steps.indexOf(step);
                final done = index < displayIndex;
                final active = index == displayIndex;
                return _StepPill(
                  step: step,
                  done: done,
                  active: active,
                  color: color,
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.step,
    required this.done,
    required this.active,
    required this.color,
  });

  final _ProgressStep step;
  final bool done;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final borderColor = active || done ? color : Colors.black26;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_rounded
                : active
                ? step.icon
                : Icons.circle_outlined,
            size: 15,
            color: active || done ? color : Colors.black54,
          ),
          const SizedBox(width: 7),
          Text(
            step.label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep {
  const _ProgressStep({
    required this.status,
    required this.label,
    required this.icon,
  });

  final MatchingLifecycleStatus status;
  final String label;
  final IconData icon;
}
