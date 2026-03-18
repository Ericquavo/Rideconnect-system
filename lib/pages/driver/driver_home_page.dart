import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

/// Driver home page: online toggle, map preview, request preview, and daily stats.
class DriverHomePage extends StatefulWidget {
  final String driverName;
  final bool isOnline;
  final ValueChanged<bool> onStatusChanged;

  const DriverHomePage({
    super.key,
    required this.driverName,
    required this.isOnline,
    required this.onStatusChanged,
  });

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  late Future<_DriverHomeData> _homeFuture;
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverSyncService _sync = DriverSyncService.instance;
  bool _processingTripAction = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _cardBg =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFC9D6F2);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF475569);
  Color get _textMuted =>
      _isDarkMode ? Colors.white38 : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _homeFuture = _loadHomeData();
    _sync.dataVersionNotifier.addListener(_onSyncDataChanged);
    _sync.activeTripNotifier.addListener(_onActiveTripChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _sync.dataVersionNotifier.removeListener(_onSyncDataChanged);
    _sync.activeTripNotifier.removeListener(_onActiveTripChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSyncDataChanged() {
    if (!mounted) return;
    setState(() {
      _homeFuture = _loadHomeData();
    });
  }

  void _onActiveTripChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _homeFuture = _loadHomeData();
    });
    await _homeFuture;
  }

  Future<void> _handleActiveTripAction() async {
    final activeTrip = _sync.activeTripNotifier.value;
    if (activeTrip == null || _processingTripAction) {
      return;
    }

    if (activeTrip.stage != DriverTripStage.inProgress) {
      _sync.advanceActiveTripStage();
      if (!mounted) return;
      final updated = _sync.activeTripNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _lang.t(
              'home.stageUpdate',
              args: {
                'stage':
                    updated?.stage == DriverTripStage.accepted
                        ? _lang.t('timeline.accepted')
                        : updated?.stage == DriverTripStage.onRoute
                        ? _lang.t('timeline.onRoute')
                        : _lang.t('timeline.inProgress'),
              },
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
      return;
    }

    if (activeTrip.requestId.isEmpty) {
      _sync.clearActiveTrip();
      return;
    }

    setState(() => _processingTripAction = true);
    try {
      await DriverApi.instance.completeRequest(activeTrip.requestId);
      _sync.clearActiveTrip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _lang.t(
              'home.tripCompleted',
              args: {'name': activeTrip.passengerName},
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF5E5B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingTripAction = false);
      }
    }
  }

  Future<_DriverHomeData> _loadHomeData() async {
    final api = DriverApi.instance;
    final statsResponse = await api.getStats();
    final requests = await api.getRequests();

    final stats = api.extractDataMap(statsResponse);

    final todayTrips = api.readInt(stats, const [
      'today_trips',
      'trips_today',
      'rides_today',
      'total_trips_today',
    ]);
    final todayEarnings = api.readDouble(stats, const [
      'today_earnings',
      'earnings_today',
      'daily_earnings',
    ]);
    final rating = api.readDouble(stats, const [
      'rating',
      'driver_rating',
      'avg_rating',
    ]);

    return _DriverHomeData(
      todayTrips: todayTrips,
      todayEarnings: todayEarnings,
      rating: rating,
      requests: requests,
    );
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
        child: FutureBuilder<_DriverHomeData>(
          future: _homeFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final hasError = snapshot.hasError;
            final data = snapshot.data;

            return RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildOnlineToggleCard(),
                    const SizedBox(height: 20),
                    _buildMapPreview(),
                    const SizedBox(height: 22),
                    _buildSectionTitle(_lang.t('home.tripStatus')),
                    const SizedBox(height: 12),
                    _buildCurrentTripStatus(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(_lang.t('home.requests')),
                    const SizedBox(height: 12),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      )
                    else if (hasError)
                      _errorCard(_lang.t('home.errorRequests'))
                    else
                      _buildRequestPreviewCard(data?.requests ?? const []),
                    const SizedBox(height: 20),
                    _buildSectionTitle(_lang.t('home.stats')),
                    const SizedBox(height: 12),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      )
                    else if (hasError)
                      _errorCard(_lang.t('home.errorStats'))
                    else
                      _buildStatsGrid(data),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _lang.t(
                  'home.welcome',
                  args: {'name': widget.driverName.split(' ').first},
                ),
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lang.t('home.ready'),
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.driverName.isNotEmpty
                  ? widget.driverName[0].toUpperCase()
                  : 'D',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineToggleCard() {
    final statusColor =
        widget.isOnline ? const Color(0xFF10B981) : const Color(0xFF8B93A7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.power_settings_new_rounded, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOnline
                      ? _lang.t('home.online')
                      : _lang.t('home.offline'),
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.isOnline
                      ? _lang.t('home.onlineHint')
                      : _lang.t('home.offlineHint'),
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: widget.isOnline,
            onChanged: widget.onStatusChanged,
            activeColor: statusColor,
            activeTrackColor: statusColor.withValues(alpha: 0.25),
            inactiveThumbColor: _isDarkMode ? Colors.white38 : Colors.white,
            inactiveTrackColor:
                _isDarkMode
                    ? Colors.white12
                    : const Color(0xFFCBD5E1).withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors:
              _isDarkMode
                  ? const [Color(0xFF1B2A4A), Color(0xFF0D1B3E)]
                  : const [Color(0xFFEAF2FF), Color(0xFFDCE8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _cardBorder),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _MapGridPainter(isDarkMode: _isDarkMode),
          ),
          const Center(
            child: Icon(
              Icons.local_taxi_rounded,
              color: Color(0xFF6C63FF),
              size: 38,
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _chip(
              Icons.my_location_rounded,
              _lang.t('home.driverLocation'),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _chip(Icons.gps_fixed_rounded, _lang.t('home.liveMap')),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            _isDarkMode
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFBFCAE2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _isDarkMode ? Colors.white70 : _textSecondary,
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: _isDarkMode ? Colors.white70 : _textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPreviewCard(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return _emptyCard(_lang.t('requests.none'));
    }

    final api = DriverApi.instance;
    final top = requests.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < top.length; i++) ...[
            _requestRow(
              api.readString(top[i], const [
                'passenger_name',
                'passenger',
                'name',
              ], fallback: _lang.t('home.requestPassenger')),
              api.readString(top[i], const [
                'pickup_address',
                'pickup',
                'pickup_location',
              ], fallback: _lang.t('home.requestPickupMissing')),
              api.readString(top[i], const [
                'dropoff_address',
                'destination',
                'dropoff',
                'dropoff_location',
              ], fallback: _lang.t('home.requestDestinationMissing')),
              api.readDouble(top[i], const ['fare', 'amount', 'price']),
              api.readDouble(top[i], const ['distance_km', 'distance']),
              api.readDouble(top[i], const [
                'passenger_rating',
                'rating',
              ], fallback: 0),
            ),
            if (i != top.length - 1) Divider(color: _cardBorder, height: 18),
          ],
        ],
      ),
    );
  }

  Widget _requestRow(
    String name,
    String pickup,
    String destination,
    double fare,
    double distanceKm,
    double rating,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
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
                name,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '$pickup  ->  $destination',
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${fare.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${distanceKm.toStringAsFixed(1)} km • ★${rating <= 0 ? '--' : rating.toStringAsFixed(1)}',
              style: GoogleFonts.poppins(color: _textMuted, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(_DriverHomeData? data) {
    final trips = data?.todayTrips ?? 0;
    final earnings = data?.todayEarnings ?? 0;
    final rating = data?.rating ?? 0;

    return Row(
      children: [
        _StatCard(
          title: _lang.t('stats.trips'),
          value: '$trips',
          subtitle: _lang.t('stats.today'),
          icon: Icons.route_rounded,
          color: const Color(0xFF3B82F6),
          textPrimary: _textPrimary,
          textSecondary: _textMuted,
        ),
        const SizedBox(width: 12),
        _StatCard(
          title: _lang.t('stats.earnings'),
          value: '\$${earnings.toStringAsFixed(2)}',
          subtitle: _lang.t('stats.today'),
          icon: Icons.payments_rounded,
          color: const Color(0xFF10B981),
          textPrimary: _textPrimary,
          textSecondary: _textMuted,
        ),
        const SizedBox(width: 12),
        _StatCard(
          title: _lang.t('stats.rating'),
          value: rating <= 0 ? '--' : '${rating.toStringAsFixed(1)} ★',
          subtitle: _lang.t('stats.driverScore'),
          icon: Icons.star_rounded,
          color: const Color(0xFF6C63FF),
          textPrimary: _textPrimary,
          textSecondary: _textMuted,
        ),
      ],
    );
  }

  Widget _buildCurrentTripStatus() {
    final activeTrip = _sync.activeTripNotifier.value;

    if (activeTrip != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lang.t(
                          'home.activeTrip',
                          args: {'name': activeTrip.passengerName},
                        ),
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activeTrip.pickup} -> ${activeTrip.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${activeTrip.fare.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActiveTripTimeline(activeTrip.stage),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _processingTripAction ? null : _handleActiveTripAction,
                icon: Icon(
                  activeTrip.stage == DriverTripStage.inProgress
                      ? Icons.check_circle_rounded
                      : Icons.directions_rounded,
                ),
                label:
                    _processingTripAction
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          activeTrip.stage == DriverTripStage.accepted
                              ? _lang.t('home.markOnRoute')
                              : activeTrip.stage == DriverTripStage.onRoute
                              ? _lang.t('home.markInProgress')
                              : _lang.t('home.completeTrip'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activeTrip.stage == DriverTripStage.inProgress
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule_rounded, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOnline
                      ? _lang.t('home.waiting')
                      : _lang.t('home.offlineState'),
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isOnline
                      ? _lang.t('home.waitingHint')
                      : _lang.t('home.offlineStateHint'),
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripTimeline(DriverTripStage stage) {
    final labels = [
      _lang.t('timeline.accepted'),
      _lang.t('timeline.onRoute'),
      _lang.t('timeline.inProgress'),
      _lang.t('timeline.completed'),
    ];
    final activeIndex = switch (stage) {
      DriverTripStage.accepted => 0,
      DriverTripStage.onRoute => 1,
      DriverTripStage.inProgress => 2,
    };

    return Row(
      children: List.generate(labels.length, (index) {
        final isDone = index <= activeIndex;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B93A7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color:
                      isDone
                          ? (_isDarkMode
                              ? Colors.white70
                              : const Color(0xFF334155))
                          : _textMuted,
                  fontSize: 9,
                  fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: _textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5E5B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5E5B).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFB3B1),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DriverHomeData {
  final int todayTrips;
  final double todayEarnings;
  final double rating;
  final List<Map<String, dynamic>> requests;

  const _DriverHomeData({
    required this.todayTrips,
    required this.todayEarnings,
    required this.rating,
    required this.requests,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color textPrimary;
  final Color textSecondary;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              '$title • $subtitle',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDarkMode;

  const _MapGridPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color =
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFF94A3B8).withValues(alpha: 0.22)
          ..strokeWidth = 1;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final road =
        Paint()
          ..color =
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFF64748B).withValues(alpha: 0.26)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
