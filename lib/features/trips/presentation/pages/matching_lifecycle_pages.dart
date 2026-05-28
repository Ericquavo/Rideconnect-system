import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/matching_lifecycle_models.dart';
import '../providers/trip_providers.dart';
import '../widgets/assignment_attempts_widget.dart';
import '../widgets/matching_progress_widget.dart';
import '../widgets/status_badge.dart';
import '../widgets/trip_error_view.dart';
import 'driver_arriving_page.dart';
import 'live_trip_tracking_page.dart';
import 'trip_completion_page.dart';

class MatchingInProgressPage extends ConsumerWidget {
  const MatchingInProgressPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripMatchingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('AI Matching')),
      body: state.when(
        loading: () => const _MatchingLoading(),
        error:
            (error, _) => TripErrorView(
              message: error.toString(),
              onRetry:
                  () => ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
        data: (snapshot) {
          _routeForStatus(context, snapshot);
          return _MatchingBody(
            snapshot: snapshot,
            onRefresh:
                () => ref.read(tripMatchingProvider(tripId).notifier).refresh(),
          );
        },
      ),
    );
  }

  void _routeForStatus(
    BuildContext context,
    MatchingLifecycleSnapshot snapshot,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final tripId = snapshot.trip?.id ?? this.tripId;
      switch (snapshot.status) {
        case MatchingLifecycleStatus.driverSelected:
        case MatchingLifecycleStatus.driverNotified:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DriverAssignmentPendingPage(tripId: tripId),
            ),
          );
          break;
        case MatchingLifecycleStatus.driverAcknowledged:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DriverAcknowledgementPage(tripId: tripId),
            ),
          );
          break;
        case MatchingLifecycleStatus.driverRejected:
        case MatchingLifecycleStatus.reassigningDriver:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MatchingRetryPage(tripId: tripId)),
          );
          break;
        case MatchingLifecycleStatus.noDriversAvailable:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => NoDriversFoundPage(tripId: tripId)),
          );
          break;
        case MatchingLifecycleStatus.driverArriving:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => DriverArrivingPage(tripId: tripId)),
          );
          break;
        case MatchingLifecycleStatus.pickedUp:
        case MatchingLifecycleStatus.inProgress:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LiveTripTrackingPage(tripId: tripId),
            ),
          );
          break;
        case MatchingLifecycleStatus.completed:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => TripCompletionPage(tripId: tripId)),
          );
          break;
        case MatchingLifecycleStatus.cancelled:
        case MatchingLifecycleStatus.tripRequested:
        case MatchingLifecycleStatus.searchingCandidates:
        case MatchingLifecycleStatus.mlMatching:
          break;
      }
    });
  }
}

class DriverAssignmentPendingPage extends ConsumerWidget {
  const DriverAssignmentPendingPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripMatchingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Assignment')),
      body: state.when(
        loading: () => const _MatchingLoading(),
        error:
            (error, _) => TripErrorView(
              message: error.toString(),
              onRetry:
                  () => ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
        data:
            (snapshot) => _MatchingBody(
              snapshot: snapshot,
              headline: 'Waiting for driver acknowledgement',
              onRefresh:
                  () =>
                      ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
      ),
    );
  }
}

class DriverAcknowledgementPage extends ConsumerWidget {
  const DriverAcknowledgementPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripMatchingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Acknowledged')),
      body: state.when(
        loading: () => const _MatchingLoading(),
        error:
            (error, _) => TripErrorView(
              message: error.toString(),
              onRetry:
                  () => ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
        data:
            (snapshot) => _MatchingBody(
              snapshot: snapshot,
              headline: 'Driver confirmed your trip',
              primaryLabel: 'Track Driver',
              onPrimary:
                  () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LiveTripTrackingPage(tripId: tripId),
                    ),
                  ),
              onRefresh:
                  () =>
                      ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
      ),
    );
  }
}

class NoDriversFoundPage extends ConsumerWidget {
  const NoDriversFoundPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('No Drivers Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 54, color: Color(0xFFFF5E5B)),
              const SizedBox(height: 12),
              Text(
                'No available drivers matched this trip right now.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'You can retry matching, change pickup details, or cancel this request.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed:
                    () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => MatchingRetryPage(tripId: tripId),
                      ),
                    ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Matching'),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(tripRepositoryProvider).cancelPassengerTrip(tripId);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Cancel Trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchingRetryPage extends ConsumerWidget {
  const MatchingRetryPage({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripMatchingProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Reassigning Driver')),
      body: state.when(
        loading: () => const _MatchingLoading(),
        error:
            (error, _) => TripErrorView(
              message: error.toString(),
              onRetry:
                  () => ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
        data:
            (snapshot) => _MatchingBody(
              snapshot: snapshot,
              headline: 'Finding another available driver',
              primaryLabel: 'Refresh status',
              onPrimary:
                  () =>
                      ref.read(tripMatchingProvider(tripId).notifier).refresh(),
              onRefresh:
                  () =>
                      ref.read(tripMatchingProvider(tripId).notifier).refresh(),
            ),
      ),
    );
  }
}

class _MatchingLoading extends StatelessWidget {
  const _MatchingLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MatchingBody extends StatelessWidget {
  const _MatchingBody({
    required this.snapshot,
    required this.onRefresh,
    this.headline,
    this.primaryLabel,
    this.onPrimary,
  });

  final MatchingLifecycleSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final String? headline;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headline ?? 'Matching your trip with the best driver',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              StatusBadge(status: snapshot.status),
            ],
          ),
          const SizedBox(height: 14),
          MatchingProgressWidget(status: snapshot.status),
          if (snapshot.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(snapshot.message, style: GoogleFonts.poppins(color: Colors.grey)),
          ],
          const SizedBox(height: 18),
          if (snapshot.selectedDriver != null)
            _DriverCandidateTile(
              rank: 1,
              name: snapshot.selectedDriver!.driverName,
              eta: snapshot.selectedDriver!.estimatedArrivalMinutes,
              fare: snapshot.selectedDriver!.estimatedFare,
              rating: snapshot.selectedDriver!.displayRating,
              selected: true,
            ),
          if (snapshot.candidates.isNotEmpty) ...[
            Text(
              'Ranked candidates',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...snapshot.candidates.take(5).indexed.map(
                  (entry) => _DriverCandidateTile(
                    rank: entry.$1 + 1,
                    name: entry.$2.driverName,
                    eta: entry.$2.estimatedArrivalMinutes,
                    fare: entry.$2.estimatedFare,
                    rating: entry.$2.displayRating,
                    selected:
                        snapshot.selectedDriver?.driverId == entry.$2.driverId,
                  ),
                ),
          ],
          const SizedBox(height: 18),
          AssignmentAttemptsWidget(attempts: snapshot.attempts),
          if (onPrimary != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(primaryLabel ?? 'Continue'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverCandidateTile extends StatelessWidget {
  const _DriverCandidateTile({
    required this.rank,
    required this.name,
    required this.eta,
    required this.fare,
    required this.rating,
    this.selected = false,
  });

  final int rank;
  final String name;
  final int eta;
  final double fare;
  final String rating;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(child: Text('$rank')),
        title: Text(name),
        subtitle: Text('$eta min ETA | $rating rating'),
        trailing: Text(fare <= 0 ? '--' : fare.toStringAsFixed(0)),
        selected: selected,
      ),
    );
  }
}
