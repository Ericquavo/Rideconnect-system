import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/trip_lifecycle_state.dart';
import '../providers/trip_providers.dart';
import 'live_trip_tracking_page.dart';
import 'trip_completion_page.dart';

class TripMatchingPage extends ConsumerStatefulWidget {
  const TripMatchingPage({
    super.key,
    required this.tripId,
    this.initialStatus,
    this.initialMatchingStatus,
    this.initialData = const <String, dynamic>{},
  });

  final int tripId;
  final String? initialStatus;
  final String? initialMatchingStatus;
  final Map<String, dynamic> initialData;

  @override
  ConsumerState<TripMatchingPage> createState() => _TripMatchingPageState();
}

class _TripMatchingPageState extends ConsumerState<TripMatchingPage>
    with WidgetsBindingObserver {
  late final MotorVehicleTripMatchingRequest _matchingRequest;
  late final DateTime _openedAt;
  Timer? _screenTimer;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _matchingRequest = MotorVehicleTripMatchingRequest(
      tripId: widget.tripId,
      initialStatus: widget.initialStatus,
      initialMatchingStatus: widget.initialMatchingStatus,
      initialData: widget.initialData,
    );
    WidgetsBinding.instance.addObserver(this);
    _screenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _screenTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(
      motorVehicleTripMatchingProvider(_matchingRequest).notifier,
    );
    if (state == AppLifecycleState.paused) {
      notifier.pause();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      notifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      notifier.resume();
      notifier.refreshTripState();
    }
  }

  void _routeIfNeeded(TripLifecycleState state) {
    if (!mounted) return;
    if (state.phase == TripLifecyclePhase.tripStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LiveTripTrackingPage(tripId: widget.tripId),
          ),
        );
      });
    } else if (state.phase == TripLifecyclePhase.tripCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripCompletionPage(tripId: widget.tripId),
          ),
        );
      });
    } else if (state.phase == TripLifecyclePhase.driverArrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Driver Arrived'),
            content: const Text('Your driver has arrived at the pickup location!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _cancelTrip() async {
    await ref.read(tripRepositoryProvider).cancelPassengerTrip(widget.tripId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    await launchUrl(uri);
  }

  Future<void> _messageDriver(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'sms', path: phone.trim());
    await launchUrl(uri);
  }

  void _trackDriver() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveTripTrackingPage(tripId: widget.tripId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TripLifecycleState>>(
      motorVehicleTripMatchingProvider(_matchingRequest),
      (previous, next) {
        final current = next.valueOrNull;
        if (current == null) return;
        final previousPhase = previous?.valueOrNull?.phase;
        if (previousPhase != current.phase) {
          if (current.phase == TripLifecyclePhase.matchTimeout) {
            ref.read(tripRepositoryProvider).acknowledgeTripStatus(widget.tripId, 'matchTimeout');
          } else if (current.phase == TripLifecyclePhase.driverAccepted) {
            ref.read(tripRepositoryProvider).acknowledgeTripStatus(widget.tripId, 'accepted');
          }
          _routeIfNeeded(current);
        }
      },
    );

    final state = ref.watch(motorVehicleTripMatchingProvider(_matchingRequest));
    final current =
        state.valueOrNull ?? TripLifecycleState.initial(tripId: widget.tripId);
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
              if (current.offline) _offlineBanner(),
              const SizedBox(height: 12),
              Center(child: _buildBodyForState(current, state.isLoading)),
              const Spacer(),
              if (current.canCancel ||
                  current.phase == TripLifecyclePhase.noDriversFound ||
                  current.phase == TripLifecyclePhase.matchTimeout)
                OutlinedButton.icon(
                  onPressed: current.offline ? null : _cancelTrip,
                  icon: const Icon(Icons.cancel_rounded),
                  label: Text(
                    current.canCancel ? 'Cancel Ride' : 'Close Request',
                  ),
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
          _radar(),
          const SizedBox(height: 16),
          Text(
            state.statusLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Matching for ${_elapsedLabel()}',
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated wait 1-3 min',
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          if (state.searchRadiusKm != null)
            Text(
              'Searching within ${state.searchRadiusKm!.toStringAsFixed(1)} km',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          if (state.driversFound > 0)
            Text(
              '${state.driversFound} drivers found so far',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
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
          if (state.phase == TripLifecyclePhase.driversFound ||
              state.phase == TripLifecyclePhase.contactingDrivers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Waiting for driver confirmation...',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
          const SizedBox(height: 16),
          _driverCard(state),
          if (state.etaMinutes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'ETA ${state.etaMinutes} min',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
          if (state.distanceToPickupKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${state.distanceToPickupKm!.toStringAsFixed(1)} km from pickup',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
          if (state.estimatedFare != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Estimated fare ${state.estimatedFare}',
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
            ),
          if (state.phase == TripLifecyclePhase.driverAccepted ||
              state.phase == TripLifecyclePhase.driverArriving)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: state.offline ? null : _trackDriver,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Track driver'),
              ),
            ),
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.driverArrived) {
      return Column(
        children: [
          const Icon(Icons.location_on_outlined, size: 64),
          const SizedBox(height: 12),
          Text(
            'Driver has arrived at pickup',
            style: GoogleFonts.poppins(fontSize: 18),
          ),
          if (state.driver != null) ...[
            const SizedBox(height: 12),
            Text(state.driver!.name ?? '', style: GoogleFonts.poppins()),
            Text(
              state.driver!.phone ?? '',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
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
            Text(
              state.driver!.phone ?? '',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ],
        ],
      );
    }

    if (state.phase == TripLifecyclePhase.noDriversFound ||
        state.phase == TripLifecyclePhase.matchTimeout) {
      return Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Color(0xFFFF5E5B),
          ),
          const SizedBox(height: 12),
          Text(state.statusLabel, style: GoogleFonts.poppins(fontSize: 16)),
          const SizedBox(height: 8),
          if (state.retryCount > 0)
            Text(
              'Retry count: ${state.retryCount}/${state.maxRetries}',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
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

  Widget _offlineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFF97316)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFF97316)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline. Trying to reconnect...',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radar() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120 * value,
                height: 120 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4C57D6).withValues(alpha: 0.10),
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4C57D6).withValues(alpha: 0.16),
                ),
              ),
              const Icon(
                Icons.two_wheeler_rounded,
                size: 38,
                color: Color(0xFF4C57D6),
              ),
            ],
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _driverCard(TripLifecycleState state) {
    final driver = state.driver;
    if (driver == null) {
      return Text(
        state.driversFound > 0
            ? '${state.driversFound} drivers matched'
            : 'Waiting for driver confirmation...',
        style: GoogleFonts.poppins(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person_rounded)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name ?? 'Driver assigned',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        if (driver.rating != null)
                          '${driver.rating!.toStringAsFixed(1)} rating',
                        if (driver.vehiclePlate != null) driver.vehiclePlate!,
                      ].join(' • '),
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                    state.offline ? null : () => _callDriver(driver.phone),
                icon: const Icon(Icons.call_rounded),
                tooltip: 'Call driver',
              ),
              IconButton(
                onPressed:
                    state.offline ? null : () => _messageDriver(driver.phone),
                icon: const Icon(Icons.message_rounded),
                tooltip: 'Message driver',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _elapsedLabel() {
    final elapsed = DateTime.now().difference(_openedAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
