import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/passenger_api.dart';
import '../../services/passenger_language_service.dart';
import '../../features/trips/data/passenger_trips_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Passenger Home Page  –  RideConnect Main Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  final String passengerName;

  /// Switches the dashboard to the Book Ride tab.
  final VoidCallback? onGoToBookRide;

  /// Unread notification count passed from the dashboard.
  final int notifCount;

  /// Opens notifications content previously shown in the Alerts tab.
  final VoidCallback? onOpenNotifications;

  const HomePage({
    super.key,
    required this.passengerName,
    this.onGoToBookRide,
    this.notifCount = 0,
    this.onOpenNotifications,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _driverCtrl;
  late final Animation<double> _driverAnim;

  // ── API data state ─────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = <String, dynamic>{};
  List<RideSummary> _availableRides = <RideSummary>[];

  // ── Static fallback driver data ────────────────────────────────────────────
  static const _nearbyDrivers = [
    {
      'name': 'Ahmed K.',
      'rating': '4.9',
      'dist': '0.8 km',
      'car': 'Toyota Corolla',
      'trips': '1.2k',
    },
    {
      'name': 'Sara M.',
      'rating': '4.7',
      'dist': '1.2 km',
      'car': 'Honda Civic',
      'trips': '876',
    },
    {
      'name': 'James O.',
      'rating': '4.8',
      'dist': '1.5 km',
      'car': 'Hyundai Elantra',
      'trips': '2.1k',
    },
  ];

  // ── Static ride options ────────────────────────────────────────────────────
  static const _staticRideOpts = [
    {
      'label': 'Economy',
      'desc': 'Affordable everyday',
      'price': r'From $3.50',
      'eta': '3 min',
      'colorVal': 0xFF3B82F6,
    },
    {
      'label': 'Premium',
      'desc': 'Luxury & comfort',
      'price': r'From $8.00',
      'eta': '5 min',
      'colorVal': 0xFF6C63FF,
    },
    {
      'label': 'Bike',
      'desc': 'Quick short trips',
      'price': r'From $1.20',
      'eta': '2 min',
      'colorVal': 0xFF10B981,
    },
    {
      'label': 'Shared',
      'desc': 'Share & save more',
      'price': r'From $2.00',
      'eta': '7 min',
      'colorVal': 0xFFF59E0B,
    },
  ];

  // ── Static saved places ────────────────────────────────────────────────────
  static const _savedPlacesData = [
    {
      'label': 'Home',
      'addr': '123 Main Street',
      'colorVal': 0xFF6C63FF,
      'iconIdx': 0,
    },
    {
      'label': 'Work',
      'addr': '456 Business Ave',
      'colorVal': 0xFF3B82F6,
      'iconIdx': 1,
    },
    {
      'label': 'Campus',
      'addr': 'University Road',
      'colorVal': 0xFF10B981,
      'iconIdx': 2,
    },
    {
      'label': 'Mall',
      'addr': 'City Shopping',
      'colorVal': 0xFFF59E0B,
      'iconIdx': 3,
    },
  ];
  static const _savedIcons = <IconData>[
    Icons.home_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.shopping_bag_rounded,
  ];
  static const _recentDests = [
    {'label': 'Central Hospital', 'dist': '3.2 km'},
    {'label': 'Airport Terminal', 'dist': '12.8 km'},
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _setupAnimations();
    _loadDashboardData();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _setupAnimations() {
    // Pulsing location pin
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Floating driver dots
    _driverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _driverAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _driverCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _pulseCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await PassengerApi.instance.getStats();
      final rides = await passengerTripsApi.fetchAvailableRides();
      if (!mounted) return;
      setState(() {
        _stats = _extractDataMap(stats);
        _availableRides = rides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e is ApiException
                ? e.message
                : e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF090D1A), Color(0xFF131729)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1A1F3A),
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1 – Header
                _buildHeader(),
                if (_isLoading) _buildLoadingBar(),
                if (_error != null) _buildErrorBanner(),

                const SizedBox(height: 20),

                // 2 – Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchBar(),
                ),

                const SizedBox(height: 16),

                // 3 – Saved places
                _buildSavedPlaces(),

                const SizedBox(height: 20),

                // 3 – Map preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMapPreview(),
                ),

                const SizedBox(height: 20),

                // 4 – Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatsRow(),
                ),

                const SizedBox(height: 24),

                // 5 – Ride options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionHeader(
                    _lang.t('home.quickRideOptions'),
                    null,
                  ),
                ),
                const SizedBox(height: 14),
                _buildRideOptions(),

                const SizedBox(height: 24),

                // 6 – Nearby drivers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionHeader(
                    _lang.t('home.nearbyDrivers'),
                    _lang.t('home.seeAll'),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildNearbyDrivers(),
                ),

                const SizedBox(height: 24),

                // 7 – Promo banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildPromoBanner(),
                ),

                const SizedBox(height: 24),

                // 8 – Book a Ride CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: _buildBookRideCTA(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Section builders
  // ══════════════════════════════════════════════════════════════════════════

  // ── 1. Header: greeting + notification bell + avatar ─────────────────────
  Widget _buildHeader() {
    final firstName = widget.passengerName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lang.t('home.greeting', args: {'name': firstName}),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _lang.t('home.whereTo'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildNotifBell(),
          const SizedBox(width: 10),
          _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildNotifBell() {
    return GestureDetector(
      onTap: widget.onOpenNotifications,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
          if (widget.notifCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  widget.notifCount > 9 ? '9+' : '${widget.notifCount}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.passengerName.isNotEmpty
              ? widget.passengerName[0].toUpperCase()
              : 'P',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return LinearProgressIndicator(
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
      minHeight: 2,
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF7A7A),
                  fontSize: 12,
                ),
              ),
            ),
            GestureDetector(
              onTap: _loadDashboardData,
              child: Text(
                _lang.t('common.retry'),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Search bar ─────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: widget.onGoToBookRide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lang.t('home.searchPrompt'),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _lang.t('home.searchSubPrompt'),
                    style: GoogleFonts.poppins(
                      color: Colors.white30,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF6C63FF),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Saved places ───────────────────────────────────────────────────────
  Widget _buildSavedPlaces() {
    final totalItems = _savedPlacesData.length + _recentDests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _lang.t('home.savedPlaces'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                _lang.t('home.addPlace'),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: totalItems,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i < _savedPlacesData.length) {
                final p = _savedPlacesData[i];
                return _SavedPlaceChip(
                  icon: _savedIcons[p['iconIdx'] as int],
                  label: p['label'] as String,
                  address: p['addr'] as String,
                  color: Color(p['colorVal'] as int),
                  onTap: widget.onGoToBookRide,
                );
              }
              final r = _recentDests[i - _savedPlacesData.length];
              return _SavedPlaceChip(
                icon: Icons.history_rounded,
                label: r['label'] as String,
                address: r['dist'] as String,
                color: const Color(0xFF64748B),
                onTap: widget.onGoToBookRide,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 4. Map preview with animated pin + driver dots ────────────────────────
  Widget _buildMapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with live-driver badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _lang.t('home.mapOverview'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _lang.t('home.driversNearby'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // The map card
        Container(
          height: 210,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Map background (roads + grid + buildings)
                SizedBox.expand(child: CustomPaint(painter: _MapPainter())),

                // Animated driver dots
                AnimatedBuilder(
                  animation: _driverAnim,
                  builder:
                      (_, __) => SizedBox.expand(
                        child: CustomPaint(
                          painter: _DriverDotsPainter(
                            animValue: _driverAnim.value,
                          ),
                        ),
                      ),
                ),

                // Pulsing user location pin
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder:
                        (_, __) => Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48 * _pulseAnim.value,
                              height: 48 * _pulseAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6C63FF).withValues(
                                  alpha: (1.6 - _pulseAnim.value) * 0.22,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF6C63FF),
                              size: 38,
                              shadows: [
                                Shadow(
                                  color: Color(0x886C63FF),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                ),

                // Your Location chip – top left
                Positioned(
                  top: 14,
                  left: 14,
                  child: _MapChip(
                    icon: Icons.my_location_rounded,
                    text: _lang.t('home.yourLocation'),
                    bg: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

                // Live Map chip – top right
                Positioned(
                  top: 14,
                  right: 14,
                  child: _MapChip(
                    icon: Icons.gps_fixed_rounded,
                    text: 'Live Map',
                    bg: const Color(0xFF6C63FF).withValues(alpha: 0.88),
                    fgColor: Colors.white,
                  ),
                ),

                // Request Driver pill – bottom centre
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: widget.onGoToBookRide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6C63FF,
                              ).withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_car_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Request a Driver',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 5. Stats strip ────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final totalTrips =
        (_stats['total_rides'] ?? _stats['totalTrips'] ?? 0).toString();
    final activeRides =
        (_stats['active_rides'] ?? _stats['activeRides'] ?? 0).toString();
    final spent =
        (_stats['total_spent'] ?? _stats['totalSpent'] ?? _stats['spent'] ?? 0)
            .toString();
    return Row(
      children: [
        _StatCard(
          icon: Icons.route_rounded,
          label: 'Total Trips',
          value: totalTrips,
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.directions_car_rounded,
          label: 'Active',
          value: activeRides,
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.wallet_rounded,
          label: 'Spent',
          value: '\$$spent',
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String? actionLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6C63FF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  // ── 6. Ride options (horizontal scroll) ───────────────────────────────────
  Widget _buildRideOptions() {
    final List<Map<String, dynamic>> opts =
        _availableRides.isNotEmpty
            ? _availableRides.map((RideSummary r) {
              final type = r.rideType.isNotEmpty ? r.rideType : 'Economy';
              String eta = '--';
              if (r.departureTime != null) {
                final h = r.departureTime!.hour.toString().padLeft(2, '0');
                final m = r.departureTime!.minute.toString().padLeft(2, '0');
                eta = '$h:$m';
              }
              return <String, dynamic>{
                'label': type,
                'desc': '${r.availableSeats} seat(s) \u2022 ${r.status}',
                'price': 'From \$${r.pricePerSeat.toStringAsFixed(2)}',
                'eta': eta,
                'icon': _typeIcon(type),
                'color': Color(_typeColorVal(type)),
              };
            }).toList()
            : _staticRideOpts
                .map(
                  (o) => <String, dynamic>{
                    'label': o['label']!,
                    'desc': o['desc']!,
                    'price': o['price']!,
                    'eta': o['eta']!,
                    'icon': _iconForLabel(o['label'] as String),
                    'color': Color(o['colorVal'] as int),
                  },
                )
                .toList();

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: opts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final opt = opts[i];
          final Color col = opt['color'] as Color;
          return GestureDetector(
            onTap: widget.onGoToBookRide,
            child: Container(
              width: 152,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: col.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: col.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          color: col,
                          size: 20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          opt['eta'] as String,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    opt['label'] as String,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    opt['desc'] as String,
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    opt['price'] as String,
                    style: GoogleFonts.poppins(
                      color: col,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 7. Nearby drivers ─────────────────────────────────────────────────────
  Widget _buildNearbyDrivers() {
    // RideSummary carries no driver info; always use static fallback data.
    const source = _nearbyDrivers;

    return Column(
      children: List.generate(source.length, (i) {
        final d = source[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with online dot
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (d['name'] as String)[0],
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1A1F3A),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name + car + trip count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['name'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d['car'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.route_rounded,
                          color: Color(0xFF6C63FF),
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${d['trips']} trips',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Rating + distance + Book button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFBBF24),
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          d['rating'] as String,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        color: Color(0xFF3B82F6),
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        d['dist'] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onGoToBookRide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'Book',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── 8. Promo banner ───────────────────────────────────────────────────────
  Widget _buildPromoBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\u{1F389}  LIMITED OFFER',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '20% Off Your\nNext 3 Rides',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use code: RIDE20',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Claim Offer  \u2192',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6C63FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.local_offer_rounded, color: Colors.white, size: 72),
        ],
      ),
    );
  }

  // ── 9. Book a Ride CTA ────────────────────────────────────────────────────
  Widget _buildBookRideCTA() {
    return GestureDetector(
      onTap: widget.onGoToBookRide,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              _lang.t('book.title'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  int _typeColorVal(String type) {
    final t = type.toLowerCase();
    if (t.contains('premium')) return 0xFF6C63FF;
    if (t.contains('bike')) return 0xFF10B981;
    if (t.contains('shared')) return 0xFFF59E0B;
    return 0xFF3B82F6;
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('premium')) return Icons.star_rounded;
    if (t.contains('bike')) return Icons.electric_bike_rounded;
    if (t.contains('shared')) return Icons.local_taxi_rounded;
    return Icons.directions_car_rounded;
  }

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'premium':
        return Icons.star_rounded;
      case 'bike':
        return Icons.electric_bike_rounded;
      case 'shared':
        return Icons.local_taxi_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }
}

// =============================================================================
//  Reusable helper widgets
// =============================================================================

/// Small chip for a saved / recent place.
class _SavedPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;
  final VoidCallback? onTap;

  const _SavedPlaceChip({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact stat card with icon + value + label.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small info chip for the map overlay.
class _MapChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fgColor;

  const _MapChip({
    required this.icon,
    required this.text,
    required this.bg,
    this.fgColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  Custom Painters
// =============================================================================

/// Stylised dark map: grid lines, roads, and block buildings.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D1B3E),
    );

    // Grid
    final grid =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Major roads
    final road =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.56),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, 0),
      Offset(size.width * 0.42, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, 0),
      Offset(size.width * 0.60, size.height),
      road,
    );

    // Minor roads
    final minor =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width, size.height * 0.68),
      minor,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.22),
      Offset(size.width * 0.55, size.height * 0.18),
      minor,
    );

    // Block buildings
    final bldg =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..style = PaintingStyle.fill;
    for (final b in [
      Rect.fromLTWH(size.width * 0.05, size.height * 0.08, 44, 32),
      Rect.fromLTWH(size.width * 0.56, size.height * 0.06, 52, 38),
      Rect.fromLTWH(size.width * 0.76, size.height * 0.62, 40, 28),
      Rect.fromLTWH(size.width * 0.08, size.height * 0.66, 38, 26),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(3)),
        bldg,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}

/// Three driver dots that float gently via sine/cosine offsets.
class _DriverDotsPainter extends CustomPainter {
  final double animValue;
  const _DriverDotsPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final bases = [
      Offset(size.width * 0.20, size.height * 0.28),
      Offset(size.width * 0.76, size.height * 0.24),
      Offset(size.width * 0.80, size.height * 0.72),
    ];

    for (int i = 0; i < bases.length; i++) {
      final phase = animValue * math.pi * 2 + i * 1.2;
      final pos =
          bases[i] + Offset(math.sin(phase) * 4.0, math.cos(phase) * 3.0);

      // Glow halo
      canvas.drawCircle(
        pos,
        16,
        Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.18),
      );
      // Filled dot
      canvas.drawCircle(pos, 8, Paint()..color = const Color(0xFF3B82F6));
      // White highlight
      canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_DriverDotsPainter old) => old.animValue != animValue;
}
