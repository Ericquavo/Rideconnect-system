import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/trip_models.dart';
import 'trip_status_timeline.dart';

class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({
    super.key,
    required this.trip,
    this.onTrack,
    this.onCancel,
    this.onPrimaryAction,
    this.primaryLabel,
  });

  final Trip trip;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onPrimaryAction;
  final String? primaryLabel;

  @override
  Widget build(BuildContext context) {
    final driver = trip.driver;
    final vehicle = trip.vehicle;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFF4C57D6,
                  ).withValues(alpha: 0.15),
                  backgroundImage:
                      driver?.photoUrl.isNotEmpty == true
                          ? NetworkImage(driver!.photoUrl)
                          : null,
                  child:
                      driver?.photoUrl.isNotEmpty == true
                          ? null
                          : const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF4C57D6),
                          ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver?.name ?? 'Matching driver',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          if ((driver?.rating ?? 0) > 0)
                            '${driver!.rating.toStringAsFixed(1)} rating',
                          if (vehicle?.model.isNotEmpty == true) vehicle!.model,
                          if (vehicle?.plateNumber.isNotEmpty == true)
                            vehicle!.plateNumber,
                        ].join(' | '),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(trip.status.label)),
              ],
            ),
            const SizedBox(height: 12),
            _RouteLine(
              pickup: trip.pickup.label,
              destination: trip.destination.label,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(
                  label: 'ETA',
                  value: trip.etaText.isEmpty ? '--' : trip.etaText,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Fare',
                  value: trip.fare <= 0 ? '--' : trip.fare.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TripStatusTimeline(status: trip.status),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onTrack != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTrack,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Track'),
                    ),
                  ),
                if (onTrack != null &&
                    (onCancel != null || onPrimaryAction != null))
                  const SizedBox(width: 8),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                if (onPrimaryAction != null) ...[
                  if (onCancel != null) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPrimaryAction,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(primaryLabel ?? 'Continue'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.pickup, required this.destination});

  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          Icons.radio_button_checked_rounded,
          const Color(0xFF10B981),
          pickup,
        ),
        const SizedBox(height: 8),
        _row(Icons.location_on_rounded, const Color(0xFF4C57D6), destination),
      ],
    );
  }

  Widget _row(IconData icon, Color color, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
