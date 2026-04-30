import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

/// Ride requests tab: shows incoming passenger requests with accept/reject actions.
class DriverRequestsPage extends StatefulWidget {
  final bool isOnline;

  const DriverRequestsPage({super.key, required this.isOnline});

  @override
  State<DriverRequestsPage> createState() => _DriverRequestsPageState();
}

class _DriverRequestsPageState extends State<DriverRequestsPage> {
  final List<_DriverRideRequest> _requests = <_DriverRideRequest>[];
  final DriverLanguageService _lang = DriverLanguageService.instance;
  Timer? _countdownTimer;
  bool _loading = true;
  String? _error;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFEFF4FF);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _loadRequests();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _requests.isEmpty) return;
      setState(() {
        for (final request in _requests) {
          if (request.countdownSeconds > 0) {
            request.countdownSeconds -= 1;
          }
        }
        _requests.removeWhere((request) => request.countdownSeconds <= 0);
      });
    });
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = DriverApi.instance;
      final response = await api.getRequests();
      final parsed =
          response.map((item) {
            final id = api.readString(item, const ['id', '_id', 'request_id']);
            final passengerId = api.readString(item, const [
              'passenger_id',
              'user_id',
              'rider_id',
              'passengerId',
            ]);
            final passenger = api.readString(item, const [
              'passenger_name',
              'passenger',
              'name',
            ], fallback: _lang.t('home.requestPassenger'));
            final passengerObj = item['passenger'];
            final resolvedPassengerId =
                passengerId.isNotEmpty
                    ? passengerId
                    : (passengerObj is Map<String, dynamic>
                        ? api.readString(passengerObj, const [
                          'id',
                          '_id',
                          'user_id',
                        ])
                        : '');
            final pickup = api.readString(item, const [
              'pickup_address',
              'pickup',
              'pickup_location',
            ], fallback: _lang.t('home.requestPickupMissing'));
            final destination = api.readString(item, const [
              'dropoff_address',
              'destination',
              'dropoff',
              'dropoff_location',
            ], fallback: _lang.t('home.requestDestinationMissing'));
            final fare = api.readDouble(item, const [
              'fare',
              'amount',
              'price',
            ]);
            final distance = api.readDouble(item, const [
              'distance_km',
              'distance',
            ]);
            final rating = api.readDouble(item, const [
              'passenger_rating',
              'rating',
            ], fallback: 0);
            final countdown = api.readInt(item, const [
              'countdown_seconds',
              'expires_in',
              'ttl_seconds',
            ], fallback: 30);

            return _DriverRideRequest(
              id: id,
              passengerId: resolvedPassengerId,
              passenger: passenger,
              pickup: pickup,
              destination: destination,
              fare: fare,
              distanceKm: distance,
              rating: rating,
              countdownSeconds: countdown,
            );
          }).toList();

      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(parsed);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 14),
            Expanded(
              child:
                  widget.isOnline ? _buildRequestList() : _buildOfflineState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_taxi_rounded,
            color: Color(0xFF6C63FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lang.t('requests.title'),
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.isOnline
                  ? _lang.t('requests.onlineHint')
                  : _lang.t('requests.offlineHint'),
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadRequests,
                child: Text(_lang.t('common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        color: const Color(0xFF6C63FF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 360,
              child: Center(
                child: Text(
                  _lang.t('requests.none'),
                  style: GoogleFonts.poppins(color: _textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _RequestCard(
            isDarkMode: _isDarkMode,
            passenger: req.passenger,
            pickup: req.pickup,
            destination: req.destination,
            fare: '\$${req.fare.toStringAsFixed(2)}',
            distance: '${req.distanceKm.toStringAsFixed(1)} km',
            rating: req.rating <= 0 ? '--' : req.rating.toStringAsFixed(1),
            countdownText: _formatCountdown(req.countdownSeconds),
            onAccept: () => _handleAccept(index),
            onReject: () => _handleReject(index),
          );
        },
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B93A7).withValues(alpha: 0.15),
                border: Border.all(
                  color: const Color(0xFF8B93A7).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: Color(0xFF8B93A7),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _lang.t('requests.offlineTitle'),
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _lang.t('requests.offlineBody'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCountdown(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _handleAccept(int index) async {
    final req = _requests[index];
    try {
      var stage = DriverTripStage.accepted;
      if (req.id.isNotEmpty) {
        final acceptResponse = await DriverApi.instance.acceptRequest(req.id);
        final status = DriverApi.instance.readString(
          DriverApi.instance.extractDataMap(acceptResponse),
          const ['status', 'trip_status', 'request_status'],
        );
        stage = DriverTripStageX.fromBackendStatus(status);
      }
      await DriverApi.instance.notifyPassengerDecision(
        passengerId: req.passengerId,
        accepted: true,
        bookingDecision: false,
        passengerName: req.passenger,
        referenceId: req.id,
        pickup: req.pickup,
        dropoff: req.destination,
      );
      DriverSyncService.instance.setActiveTrip(
        DriverActiveTrip(
          requestId: req.id,
          passengerName: req.passenger,
          pickup: req.pickup,
          destination: req.destination,
          fare: req.fare,
          stage: stage,
        ),
      );
      if (!mounted) return;
      setState(() => _requests.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              _isDarkMode ? const Color(0xFF131729) : const Color(0xFFF8FAFF),
          behavior: SnackBarBehavior.floating,
          content: Text(
            _lang.t('requests.accepted', args: {'name': req.passenger}),
            style: GoogleFonts.poppins(
              color: _isDarkMode ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _handleReject(int index) async {
    final req = _requests[index];
    try {
      if (req.id.isNotEmpty) {
        await DriverApi.instance.rejectRequest(req.id);
      }
      await DriverApi.instance.notifyPassengerDecision(
        passengerId: req.passengerId,
        accepted: false,
        bookingDecision: false,
        passengerName: req.passenger,
        referenceId: req.id,
        pickup: req.pickup,
        dropoff: req.destination,
      );
      if (!mounted) return;
      setState(() => _requests.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              _isDarkMode ? const Color(0xFF131729) : const Color(0xFFF8FAFF),
          behavior: SnackBarBehavior.floating,
          content: Text(
            _lang.t('requests.rejected', args: {'name': req.passenger}),
            style: GoogleFonts.poppins(
              color: _isDarkMode ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF5E5B),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final bool isDarkMode;
  final String passenger;
  final String pickup;
  final String destination;
  final String fare;
  final String distance;
  final String rating;
  final String countdownText;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.isDarkMode,
    required this.passenger,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distance,
    required this.rating,
    required this.countdownText,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.92);
    final cardBorder =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFC9D6F2);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDarkMode ? Colors.white54 : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFF334155).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                child: Text(
                  passenger.isNotEmpty ? passenger[0].toUpperCase() : 'P',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger,
                      style: GoogleFonts.poppins(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '★ $rating • $distance',
                      style: GoogleFonts.poppins(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fare,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB020).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFB020).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFFFB020),
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  DriverLanguageService.instance.t(
                    'requests.expire',
                    args: {'time': countdownText},
                  ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD58A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _routeRow(
            Icons.radio_button_checked_rounded,
            const Color(0xFF10B981),
            pickup,
          ),
          const SizedBox(height: 8),
          _routeRow(
            Icons.location_on_rounded,
            const Color(0xFF6C63FF),
            destination,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFFF5E5B),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFF5E5B),
                    size: 16,
                  ),
                  label: Text(
                    DriverLanguageService.instance.t('requests.reject'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF5E5B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      DriverLanguageService.instance.t('requests.accept'),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : const Color(0xFF334155),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DriverRideRequest {
  _DriverRideRequest({
    required this.id,
    required this.passengerId,
    required this.passenger,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceKm,
    required this.rating,
    required this.countdownSeconds,
  });

  final String id;
  final String passengerId;
  final String passenger;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceKm;
  final double rating;
  int countdownSeconds;
}
