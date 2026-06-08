import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/trip_lifecycle_state.dart';
import '../providers/trip_providers.dart';
import 'live_trip_tracking_page.dart';
import 'trip_completion_page.dart';

class TripMatchingPage extends ConsumerStatefulWidget {
  const TripMatchingPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripMatchingPage> createState() => _TripMatchingPageState();
}

class _TripMatchingPageState extends ConsumerState<TripMatchingPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(motorVehicleTripMatchingProvider(widget.tripId).notifier);
    if (state == AppLifecycleState.paused) {
      notifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      notifier.resume();
    }
  }

  void _routeIfNeeded(TripLifecycleState state) {
    if (!mounted) return;
    if (state.phase == TripLifecyclePhase.tripStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LiveTripTrackingPage(tripId: widget.tripId)),
        );
      });
    } else if (state.phase == TripLifecyclePhase.tripCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TripCompletionPage(tripId: widget.tripId)),
        );
      });
    }
  }

  Future<void> _cancelTrip() async {
    await ref.read(tripRepositoryProvider).cancelPassengerTrip(widget.tripId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TripLifecycleState>>(
      motorVehicleTripMatchingProvider(widget.tripId),
      (previous, next) {
        final current = next.valueOrNull;
        if (current == null) return;
        final previousPhase = previous?.valueOrNull?.phase;
        if (previousPhase != current.phase) {
          _routeIfNeeded(current);
        }
      },
    );

    final state = ref.watch(motorVehicleTripMatchingProvider(widget.tripId));
    final current = state.valueOrNull ?? TripLifecycleState.initial(tripId: widget.tripId);
    final phase = current.phase;
    final title = phase.label;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(child: _buildBodyForState(current, state.isLoading)),
              const Spacer(),
              if (current.phase == TripLifecyclePhase.noDriversFound ||
                  current.phase == TripLifecyclePhase.matchTimeout)
                ElevatedButton.icon(
                  onPressed: _cancelTrip,
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Cancel Trip'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyForState(TripLifecycleState state, bool isLoading) {
    if (isLoading && state.phase == TripLifecyclePhase.requestReceived) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Preparing your ride request...', style: GoogleFonts.poppins()),
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.searchingCandidates) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(state.statusLabel, style: GoogleFonts.poppins()),
          const SizedBox(height: 8),
          if (state.searchRadiusKm != null)
            Text('Searching within ${state.searchRadiusKm!.toStringAsFixed(1)} km',
                style: GoogleFonts.poppins(color: Colors.grey[700])),
          if (state.driversFound > 0)
            Text('${state.driversFound} drivers found so far',
                style: GoogleFonts.poppins(color: Colors.grey[700])),
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.driversFound ||
        state.phase == TripLifecyclePhase.contactingDrivers ||
        state.phase == TripLifecyclePhase.driverAccepted ||
        state.phase == TripLifecyclePhase.driverArriving) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.local_taxi_outlined, size: 64),
          const SizedBox(height: 12),
          Text(state.statusLabel, style: GoogleFonts.poppins(fontSize: 18)),
          const SizedBox(height: 16),
          if (state.driversFound > 0)
            Text('${state.driversFound} drivers matched', style: GoogleFonts.poppins()),
          if (state.etaMinutes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('ETA ${state.etaMinutes} min', style: GoogleFonts.poppins(color: Colors.grey[700])),
            ),
          if (state.estimatedFare != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Estimated fare ${state.estimatedFare}',
                  style: GoogleFonts.poppins(color: Colors.grey[700])),
            ),
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.driverArrived) {
      return Column(
        children: [
          const Icon(Icons.location_on_outlined, size: 64),
          const SizedBox(height: 12),
          Text('Driver has arrived at pickup', style: GoogleFonts.poppins(fontSize: 18)),
          if (state.driver != null) ...[
            const SizedBox(height: 12),
            Text(state.driver!.name ?? '', style: GoogleFonts.poppins()),
            Text(state.driver!.phone ?? '', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ],
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.tripStarted) {
      return Column(
        children: [
          const Icon(Icons.directions_car, size: 64),
          const SizedBox(height: 12),
          Text(state.statusLabel, style: GoogleFonts.poppins(fontSize: 18)),
          if (state.driver != null) ...[
            const SizedBox(height: 12),
            Text(state.driver!.name ?? '', style: GoogleFonts.poppins()),
            Text(state.driver!.phone ?? '', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ],
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.noDriversFound ||
        state.phase == TripLifecyclePhase.matchTimeout) {
      return Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Color(0xFFFF5E5B)),
          const SizedBox(height: 12),
          Text(state.statusLabel, style: GoogleFonts.poppins(fontSize: 16)),
          const SizedBox(height: 8),
          if (state.retryCount > 0)
            Text('Retry count: ${state.retryCount}/${state.maxRetries}',
                style: GoogleFonts.poppins(color: Colors.grey[700])),
        ],
      );
    }

    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(state.statusLabel, style: GoogleFonts.poppins()),
      ],
    );
  }
}
