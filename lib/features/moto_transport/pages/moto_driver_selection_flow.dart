import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:rideconnect_app/models/matching/matching_session.dart';
import 'package:rideconnect_app/providers/matching_providers.dart';
import 'package:rideconnect_app/features/shared/widgets/driver_selection_card.dart';
import 'package:rideconnect_app/features/shared/widgets/matching_session_expired_banner.dart';
import 'package:rideconnect_app/realtime/realtime_event_handler.dart';
import 'package:rideconnect_app/models/matching/realtime_events.dart';

/// Moto Driver Selection Flow
///
/// Passengers select a driver for motorcycle rides
class MotoDriverSelectionFlow extends ConsumerStatefulWidget {
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropoffName;
  final double dropoffLat;
  final double dropoffLng;
  final VoidCallback? onDriverSelected;
  final Function(DriverMatch)? onConfirmRequest;

  const MotoDriverSelectionFlow({
    super.key,
    required this.pickupName,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffName,
    required this.dropoffLat,
    required this.dropoffLng,
    this.onDriverSelected,
    this.onConfirmRequest,
  });

  @override
  ConsumerState<MotoDriverSelectionFlow> createState() =>
      _MotoDriverSelectionFlowState();
}

class _MotoDriverSelectionFlowState
    extends ConsumerState<MotoDriverSelectionFlow> {
  late RealtimeEventHandler _realtimeHandler;
  Timer? _sessionExpirationTimer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _realtimeHandler = RealtimeEventHandler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initializeFlow());
    });
  }

  @override
  void dispose() {
    _sessionExpirationTimer?.cancel();
    _realtimeHandler.disconnect();
    super.dispose();
  }

  Future<void> _initializeFlow() async {
    // Fetch available drivers
    await _fetchDrivers();
    // Connect to realtime events
    await _connectRealtime();
    // Start session expiration timer
    _startSessionExpirationTimer();
  }

  Future<void> _fetchDrivers() async {
    final repository = ref.read(matchingRepositoryProvider);
    try {
      ref.read(driverSelectionLoadingProvider.notifier).state = true;
      ref.read(driverSelectionErrorProvider.notifier).state = null;
      ref.read(selectedDriverProvider.notifier).clearSelection();

      final session = await repository.getAvailableDrivers(
        transportType: 'MOTORCYCLE',
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        dropoffLat: widget.dropoffLat,
        dropoffLng: widget.dropoffLng,
      );

      if (mounted) {
        ref.read(matchingSessionProvider.notifier).updateSession(session);
      }
    } catch (e) {
      if (mounted) {
        ref.read(driverSelectionErrorProvider.notifier).state = e.toString();
        ref.read(matchingSessionProvider.notifier).clearSession();
      }
    } finally {
      if (mounted) {
        ref.read(driverSelectionLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtimeHandler.connect();

      // Subscribe to lock events
      _realtimeHandler.subscribeToEvent<DriverTemporarilyLockedEvent>().listen((
        event,
      ) {
        if (!mounted) return;
        ref.read(lockedDriversProvider.notifier).update((state) {
          return {...state, event.driverId};
        });
      });

      // Subscribe to rejection events
      _realtimeHandler.subscribeToEvent<DriverAssignmentRejectedEvent>().listen(
        (event) {
          if (!mounted) return;
          ref.read(rejectedDriversProvider.notifier).update((state) {
            return {...state, event.driverId};
          });
        },
      );

      // Subscribe to availability changes
      _realtimeHandler
          .subscribeToEvent<DriverMatchAvailabilityChangedEvent>()
          .listen((event) {
            // Remove driver from list if became unavailable
            if (event.availabilityStatus == 'offline' ||
                event.availabilityStatus == 'busy') {
              if (!mounted) return;
              final session = ref.read(matchingSessionProvider);
              if (session != null) {
                final updatedDrivers =
                    session.drivers
                        .where((d) => d.driverId != event.driverId)
                        .toList();
                ref
                    .read(matchingSessionProvider.notifier)
                    .updateSession(
                      MatchingSession(
                        matchingSessionId: session.matchingSessionId,
                        transportType: session.transportType,
                        responseVersion: session.responseVersion,
                        generatedAt: session.generatedAt,
                        expiresAt: session.expiresAt,
                        drivers: updatedDrivers,
                      ),
                    );
              }
            }
          });
    } catch (e) {
      debugPrint('Realtime connection error: $e');
    }
  }

  void _startSessionExpirationTimer() {
    _sessionExpirationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _selectDriver(DriverMatch driver) {
    ref.read(selectedDriverProvider.notifier).selectDriver(driver);
    widget.onDriverSelected?.call();
  }

  Future<void> _confirmRequest() async {
    final selectedDriver = ref.read(selectedDriverProvider);
    final session = ref.read(matchingSessionProvider);
    if (selectedDriver == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a driver')));
      return;
    }
    if (session == null || session.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search for drivers again')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(matchingRepositoryProvider)
          .requestMotoTrip(
            driverId: selectedDriver.driverId,
            matchingSessionId: session.matchingSessionId,
            pickupName: widget.pickupName,
            pickupLat: widget.pickupLat,
            pickupLng: widget.pickupLng,
            dropoffName: widget.dropoffName,
            dropoffLat: widget.dropoffLat,
            dropoffLng: widget.dropoffLng,
            idempotencyKey: ref.read(idempotencyKeyProvider),
          );
      if (!mounted) return;
      widget.onConfirmRequest?.call(selectedDriver);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request sent to driver')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _retryFetch() {
    _fetchDrivers();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isLoading = ref.watch(driverSelectionLoadingProvider);
    final error = ref.watch(driverSelectionErrorProvider);
    final session = ref.watch(matchingSessionProvider);
    final selectedDriver = ref.watch(selectedDriverProvider);
    final secondsRemaining = ref.watch(matchingSessionSecondsRemainingProvider);
    final lockedDrivers = ref.watch(lockedDriversProvider);
    final rejectedDrivers = ref.watch(rejectedDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Driver',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF0A0E1A) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: Column(
        children: [
          // Session expiration banner
          if (session != null)
            MatchingSessionExpiredBanner(
              secondsRemaining: secondsRemaining,
              onRetry: _retryFetch,
            ),
          // Content
          Expanded(
            child:
                isLoading
                    ? _buildLoadingState()
                    : error != null
                    ? _buildErrorState(error)
                    : session == null || session.drivers.isEmpty
                    ? _buildEmptyState()
                    : _buildDriversList(
                      session,
                      selectedDriver,
                      lockedDrivers,
                      rejectedDrivers,
                    ),
          ),
          // Confirm button
          if (selectedDriver != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B21B6),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isSubmitting ? 'Sending request...' : 'Confirm & Request',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Finding available drivers...',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading drivers',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _retryFetch, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No drivers available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again in a few moments',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _retryFetch, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList(
    MatchingSession session,
    DriverMatch? selectedDriver,
    Set<int> lockedDrivers,
    Set<int> rejectedDrivers,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: session.drivers.length,
      itemBuilder: (context, index) {
        final driver = session.drivers[index];
        final isSelected = selectedDriver?.driverId == driver.driverId;
        final isLocked = lockedDrivers.contains(driver.driverId);
        final isRejected = rejectedDrivers.contains(driver.driverId);

        return DriverSelectionCard(
          driver: driver,
          isSelected: isSelected,
          isLocked: isLocked,
          isRejected: isRejected,
          onTap: () => _selectDriver(driver),
        );
      },
    );
  }
}
