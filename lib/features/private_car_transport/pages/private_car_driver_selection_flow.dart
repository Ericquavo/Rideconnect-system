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

/// Private Car Driver Selection Flow
///
/// Passengers select a driver for private car rides with seat selection
class PrivateCarDriverSelectionFlow extends ConsumerStatefulWidget {
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropoffName;
  final double dropoffLat;
  final double dropoffLng;
  final VoidCallback? onDriverSelected;
  final Function(DriverMatch, int)? onConfirmRequest;

  const PrivateCarDriverSelectionFlow({
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
  ConsumerState<PrivateCarDriverSelectionFlow> createState() =>
      _PrivateCarDriverSelectionFlowState();
}

class _PrivateCarDriverSelectionFlowState
    extends ConsumerState<PrivateCarDriverSelectionFlow> {
  late RealtimeEventHandler _realtimeHandler;
  Timer? _sessionExpirationTimer;
  int _selectedSeats = 1;
  DateTime? _scheduleTime;
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
    await _fetchDrivers();
    await _connectRealtime();
    _startSessionExpirationTimer();
  }

  Future<void> _fetchDrivers() async {
    final repository = ref.read(matchingRepositoryProvider);
    try {
      ref.read(driverSelectionLoadingProvider.notifier).state = true;
      ref.read(driverSelectionErrorProvider.notifier).state = null;
      ref.read(selectedDriverProvider.notifier).clearSelection();

      final session = await repository.getAvailableDrivers(
        transportType: 'CAR',
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

      // Subscribe to driver locked events
      _realtimeHandler.subscribeToEvent<DriverTemporarilyLockedEvent>().listen((
        event,
      ) {
        if (mounted) {
          ref
              .read(lockedDriversProvider.notifier)
              .update((state) => {...state, event.driverId});
        }
      });

      // Subscribe to driver assignment rejected events
      _realtimeHandler.subscribeToEvent<DriverAssignmentRejectedEvent>().listen(
        (event) {
          if (mounted) {
            ref
                .read(rejectedDriversProvider.notifier)
                .update((state) => {...state, event.driverId});
          }
        },
      );

      // Subscribe to availability changed events (driver went offline/busy)
      _realtimeHandler
          .subscribeToEvent<DriverMatchAvailabilityChangedEvent>()
          .listen((event) {
            if (event.availabilityStatus != 'online' && mounted) {
              // Remove driver from available list if offline or busy
              final currentSession = ref.read(matchingSessionProvider);
              if (currentSession != null) {
                final updatedSession = MatchingSession(
                  matchingSessionId: currentSession.matchingSessionId,
                  transportType: currentSession.transportType,
                  responseVersion: currentSession.responseVersion,
                  generatedAt: currentSession.generatedAt,
                  expiresAt: currentSession.expiresAt,
                  drivers:
                      currentSession.drivers
                          .where((d) => d.driverId != event.driverId)
                          .toList(),
                );
                if (mounted) {
                  ref
                      .read(matchingSessionProvider.notifier)
                      .updateSession(updatedSession);
                }
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
        setState(() {
          // Trigger UI rebuild for countdown display
        });
      }
    });
  }

  void _selectDriver(DriverMatch driver) {
    ref.read(selectedDriverProvider.notifier).selectDriver(driver);
    widget.onDriverSelected?.call();
  }

  Future<void> _selectScheduleTime() async {
    final now = DateTime.now();
    final initialTime = _scheduleTime ?? now.add(const Duration(hours: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      final timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialTime),
      );

      if (timePicked != null) {
        setState(() {
          _scheduleTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  Future<void> _confirmRequest() async {
    final selectedDriver = ref.read(selectedDriverProvider);
    final session = ref.read(matchingSessionProvider);
    if (selectedDriver == null) return;
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
          .requestPrivateCarBooking(
            driverId: selectedDriver.driverId,
            matchingSessionId: session.matchingSessionId,
            seats: _selectedSeats,
            pickupName: widget.pickupName,
            pickupLat: widget.pickupLat,
            pickupLng: widget.pickupLng,
            dropoffName: widget.dropoffName,
            dropoffLat: widget.dropoffLat,
            dropoffLng: widget.dropoffLng,
            scheduleTime: _scheduleTime,
            idempotencyKey: ref.read(idempotencyKeyProvider),
          );
      if (!mounted) return;
      widget.onConfirmRequest?.call(selectedDriver, _selectedSeats);
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
    final isLoading = ref.watch(driverSelectionLoadingProvider);
    final error = ref.watch(driverSelectionErrorProvider);
    final session = ref.watch(matchingSessionProvider);
    final drivers = session?.drivers ?? [];
    final selectedDriver = ref.watch(selectedDriverProvider);
    final secondsRemaining = ref.watch(matchingSessionSecondsRemainingProvider);
    final lockedDrivers = ref.watch(lockedDriversProvider);
    final rejectedDrivers = ref.watch(rejectedDriversProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Driver'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      ),
      body: Column(
        children: [
          if (session != null)
            MatchingSessionExpiredBanner(
              secondsRemaining: secondsRemaining,
              onRetry: _retryFetch,
            ),
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.purple[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Finding drivers...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.grey[400] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : error != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load drivers',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    isDarkMode ? Colors.grey[400] : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _retryFetch,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : drivers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 64,
                            color: Colors.grey[400],
                          ),
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
                            'Try again later',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.grey[400] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Number of Seats',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: List.generate(4, (index) {
                                    final seats = index + 1;
                                    return ChoiceChip(
                                      label: Text(
                                        '$seats',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      selected: _selectedSeats == seats,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedSeats = seats;
                                        });
                                      },
                                      selectedColor: Colors.purple[400],
                                      labelStyle: TextStyle(
                                        color:
                                            _selectedSeats == seats
                                                ? Colors.white
                                                : (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Schedule Time (Optional)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _selectScheduleTime,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.schedule),
                                        const SizedBox(width: 12),
                                        Text(
                                          _scheduleTime == null
                                              ? 'Immediate ride'
                                              : _formatDateTime(_scheduleTime!),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Available Drivers',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: drivers.length,
                            itemBuilder: (context, index) {
                              final driver = drivers[index];
                              final isSelected =
                                  selectedDriver?.driverId == driver.driverId;
                              final isLocked = lockedDrivers.contains(
                                driver.driverId,
                              );
                              final isRejected = rejectedDrivers.contains(
                                driver.driverId,
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: DriverSelectionCard(
                                  driver: driver,
                                  isSelected: isSelected,
                                  isLocked: isLocked,
                                  isRejected: isRejected,
                                  onTap: () => _selectDriver(driver),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    selectedDriver != null && !_isSubmitting
                        ? _confirmRequest
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selectedDriver != null
                          ? Colors.purple[400]
                          : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isSubmitting
                      ? 'Sending request...'
                      : selectedDriver != null
                      ? 'Confirm Selection'
                      : 'Select a Driver',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
