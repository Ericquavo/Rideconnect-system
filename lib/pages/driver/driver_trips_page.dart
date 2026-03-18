import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

/// Driver trips tab: history of completed/cancelled trips.
class DriverTripsPage extends StatefulWidget {
  const DriverTripsPage({super.key});

  @override
  State<DriverTripsPage> createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  late Future<List<_Trip>> _tripsFuture;
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverSyncService _sync = DriverSyncService.instance;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _tripsFuture = _loadTrips();
    _sync.dataVersionNotifier.addListener(_onSyncDataChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _sync.dataVersionNotifier.removeListener(_onSyncDataChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() => _tripsFuture = _loadTrips());
  }

  void _onSyncDataChanged() {
    if (!mounted) return;
    setState(() => _tripsFuture = _loadTrips());
  }

  Future<void> _refresh() async {
    setState(() => _tripsFuture = _loadTrips());
    await _tripsFuture;
  }

  Future<List<_Trip>> _loadTrips() async {
    final api = DriverApi.instance;
    final raw = await api.getTrips();
    return raw.map((item) {
      final pickup = api.readString(item, const [
        'pickup_address',
        'pickup',
        'pickup_location',
      ], fallback: _lang.t('trips.unknownPickup'));
      final destination = api.readString(item, const [
        'dropoff_address',
        'destination',
        'dropoff',
        'dropoff_location',
      ], fallback: _lang.t('trips.unknownDestination'));
      final date = api.readString(item, const [
        'created_at',
        'date',
        'trip_date',
        'started_at',
      ], fallback: _lang.t('trips.unknownTime'));
      final amount = api.readDouble(item, const ['fare', 'amount', 'price']);
      final status = api.readString(item, const [
        'status',
        'trip_status',
      ], fallback: _lang.t('trips.defaultStatus'));
      final rating = api.readDouble(item, const [
        'passenger_rating',
        'rating',
      ], fallback: 0);

      return _Trip(
        pickup: pickup,
        destination: destination,
        date: date,
        fare: amount,
        status: status,
        passengerRating: rating,
      );
    }).toList();
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF6C63FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _lang.t('trips.title'),
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_Trip>>(
                future: _tripsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snapshot.error.toString().replaceFirst(
                                'Exception: ',
                                '',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: _textSecondary),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _refresh,
                              child: Text(_lang.t('common.retry')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final trips = snapshot.data ?? const <_Trip>[];
                  if (trips.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: const Color(0xFF6C63FF),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 360,
                            child: Center(
                              child: Text(
                                _lang.t('trips.empty'),
                                style: GoogleFonts.poppins(
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: const Color(0xFF6C63FF),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: trips.length,
                      itemBuilder:
                          (_, index) => _TripCard(
                            trip: trips[index],
                            isDarkMode: _isDarkMode,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Trip {
  final String pickup;
  final String destination;
  final String date;
  final double fare;
  final String status;
  final double passengerRating;

  const _Trip({
    required this.pickup,
    required this.destination,
    required this.date,
    required this.fare,
    required this.status,
    required this.passengerRating,
  });
}

class _TripCard extends StatelessWidget {
  final _Trip trip;
  final bool isDarkMode;

  const _TripCard({required this.trip, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = trip.status.trim().toLowerCase();
    final isCompleted =
        normalizedStatus == 'completed' || normalizedStatus == 'done';
    final statusColor =
        isCompleted ? const Color(0xFF10B981) : const Color(0xFFFF5E5B);

    final cardBg =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.92);
    final cardBorder =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFC9D6F2);
    final textMuted = isDarkMode ? Colors.white38 : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trip.status,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '\$${trip.fare.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: isCompleted ? const Color(0xFF10B981) : textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _route(
            Icons.radio_button_checked_rounded,
            const Color(0xFF10B981),
            trip.pickup,
          ),
          const SizedBox(height: 8),
          _route(
            Icons.location_on_rounded,
            const Color(0xFF6C63FF),
            trip.destination,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.date,
                  style: GoogleFonts.poppins(color: textMuted, fontSize: 11),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trip.passengerRating <= 0
                      ? DriverLanguageService.instance.t(
                        'trips.passengerRatingMissing',
                      )
                      : DriverLanguageService.instance.t(
                        'trips.passengerRating',
                        args: {
                          'value': trip.passengerRating.toStringAsFixed(1),
                        },
                      ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _route(IconData icon, Color color, String text) {
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
