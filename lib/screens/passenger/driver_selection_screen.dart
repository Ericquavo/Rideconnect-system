import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../models/matching/matching_session.dart';
import '../../providers/matching_providers.dart';
import '../../features/shared/widgets/driver_selection_card.dart';
import '../../features/shared/widgets/matching_session_expired_banner.dart';
import '../../services/matching/matching_repository.dart';

class DriverSelectionScreen extends ConsumerStatefulWidget {
  const DriverSelectionScreen({super.key});

  @override
  ConsumerState<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends ConsumerState<DriverSelectionScreen> {
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fetchDrivers());
    });
  }

  Future<void> _fetchDrivers() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final repository = ref.read(matchingRepositoryProvider);

    try {
      ref.read(driverSelectionLoadingProvider.notifier).state = true;
      ref.read(driverSelectionErrorProvider.notifier).state = null;
      ref.read(selectedDriverProvider.notifier).clearSelection();

      final session = await repository.getAvailableDrivers(
        transportType: 'CAR',
        pickupLat: args['pickup_lat'],
        pickupLng: args['pickup_lng'],
        dropoffLat: args['dropoff_lat'],
        dropoffLng: args['dropoff_lng'],
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

  Future<void> _confirmRequest() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final selectedDriver = ref.read(selectedDriverProvider);
    final session = ref.read(matchingSessionProvider);

    if (selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a driver')),
      );
      return;
    }
    if (session == null || session.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please search again.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(matchingRepositoryProvider);
      final scheduleTime = args['schedule_time'] as DateTime?;

      if (scheduleTime != null) {
        // Scheduled booking
        final result = await repository.requestPrivateCarBooking(
          driverId: selectedDriver.driverId,
          matchingSessionId: session.matchingSessionId,
          seats: args['seats'] ?? 1,
          pickupName: args['pickup_name'],
          pickupLat: args['pickup_lat'],
          pickupLng: args['pickup_lng'],
          dropoffName: args['dropoff_name'],
          dropoffLat: args['dropoff_lat'],
          dropoffLng: args['dropoff_lng'],
          scheduleTime: scheduleTime,
          idempotencyKey: ref.read(idempotencyKeyProvider),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        // On-demand trip
        // Re-use matching repository requests by creating trip
        final result = await repository.requestMotoTrip(
          driverId: selectedDriver.driverId,
          matchingSessionId: session.matchingSessionId,
          pickupName: args['pickup_name'],
          pickupLat: args['pickup_lat'],
          pickupLng: args['pickup_lng'],
          dropoffName: args['dropoff_name'],
          dropoffLat: args['dropoff_lat'],
          dropoffLng: args['dropoff_lng'],
          idempotencyKey: ref.read(idempotencyKeyProvider),
        );
        final tripId = result['id'] ?? result['trip_id'] ?? 0;
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/trip/searching/$tripId',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && _isSubmitting) setState(() => _isSubmitting = false);
    }
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
      ),
      body: Column(
        children: [
          if (session != null)
            MatchingSessionExpiredBanner(
              secondsRemaining: secondsRemaining,
              onRetry: _fetchDrivers,
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $error', style: GoogleFonts.poppins()),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchDrivers, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : session == null || session.drivers.isEmpty
                        ? Center(
                            child: Text('No drivers available', style: GoogleFonts.poppins()),
                          )
                        : ListView.builder(
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
                                onTap: () {
                                  ref.read(selectedDriverProvider.notifier).selectDriver(driver);
                                },
                              );
                            },
                          ),
          ),
          if (selectedDriver != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmRequest,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isSubmitting ? 'Requesting...' : 'Confirm Request',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
