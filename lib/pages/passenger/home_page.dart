import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// image picker and base64 encoding removed with quick-profile editor
import 'dart:typed_data';

import '../../models/ride_type_model.dart';
import '../../services/passenger_api.dart';
import '../../services/passenger_language_service.dart';
import '../../services/passenger_preferences_service.dart';
import '../../services/currency_formatter.dart';

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

  /// Opens profile from avatar tap.
  final VoidCallback? onOpenProfile;
  final void Function({
    required String name,
    required String email,
    Uint8List? avatarBytes,
  })?
  onProfileUpdated;

  const HomePage({
    super.key,
    required this.passengerName,
    this.onGoToBookRide,
    this.notifCount = 0,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onProfileUpdated,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  static const LatLng _kigaliCenter = LatLng(-1.9441, 30.0619);

  // Rwanda geographical boundaries
  static const double _rwandaNorthLat = -1.04;
  static const double _rwandaSouthLat = -2.84;
  static const double _rwandaWestLng = 28.84;
  static const double _rwandaEastLng = 30.90;
  static final LatLngBounds _rwandaBounds = LatLngBounds(
    southwest: const LatLng(_rwandaSouthLat, _rwandaWestLng),
    northeast: const LatLng(_rwandaNorthLat, _rwandaEastLng),
  );

  GoogleMapController? _homeMapController;
  LatLng? _currentLatLng;
  bool _hasLocationPermission = false;
  bool _isLocating = false;
  double _mapZoom = 14;
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _cardBg =>
      _isDarkMode
          ? const Color(0xFF1A1F3A)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.09)
          : const Color(0xFFC9D6F2);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white70 : const Color(0xFF334155);
  Color get _textMuted =>
      _isDarkMode ? Colors.white38 : const Color(0xFF475569);

  // ── API data state ─────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = <String, dynamic>{};

  // ── Ride types state (for dynamic ride type loading) ───────────────────────
  List<Ride> _carRides = [];
  List<Ride> _motorcycleRides = [];
  bool _isLoadingRideTypes = true;
  String? _rideTypeError;
  bool _rideTypeFallbackMode = false;
  // ── Static transport options retained for the dashboard visual summary. ─
  // static const _staticRideOpts = [
  //   {
  //     'label': 'Economy',
  //     'desc': 'Affordable everyday',
  //     'price': r'From $3.50',
  //     'eta': '3 min',
  //     'colorVal': 0xFF3B82F6,
  //   },
  //   {
  //     'label': 'Premium',
  //     'desc': 'Luxury & comfort',
  //     'price': r'From $8.00',
  //     'eta': '5 min',
  //     'colorVal': 0xFF6C63FF,
  //   },
  //   {
  //     'label': 'Bike',
  //     'desc': 'Quick short trips',
  //     'price': r'From $1.20',
  //     'eta': '2 min',
  //     'colorVal': 0xFF10B981,
  //   },
  //   {
  //     'label': 'Shared',
  //     'desc': 'Share & save more',
  //     'price': r'From $2.00',
  //     'eta': '7 min',
  //     'colorVal': 0xFFF59E0B,
  //   },
  // ];

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
    _initCurrentLocation();
    _loadDashboardData();
    _loadAvailableRideTypes();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _homeMapController?.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    if (_isLocating) return;

    if (!PassengerPreferencesService.locationSharing) {
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = false;
        _isLocating = false;
      });
      return;
    }

    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _hasLocationPermission = false;
          _isLocating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _hasLocationPermission = false;
          _isLocating = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      final point = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _currentLatLng = point;
        _hasLocationPermission = true;
        _isLocating = false;
      });

      await _homeMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: point, zoom: _mapZoom),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = false;
        _isLocating = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await PassengerApi.instance.getStats();
      if (!mounted) return;
      setState(() {
        _stats = _extractDataMap(stats);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e is PassengerApiException
                ? e.message
                : e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Load available ride types (CAR and MOTORCYCLE) from API
  Future<void> _loadAvailableRideTypes() async {
    setState(() {
      _isLoadingRideTypes = true;
      _rideTypeError = null;
      _rideTypeFallbackMode = false;
    });
    try {
      // Fetch CAR on-demand rides
      final carRidesRaw = await PassengerApi.instance.getRidesByType(
        transportType: 'CAR',
        travelMode: 'ON_DEMAND',
        availableOnly: true,
      );

      // Fetch MOTORCYCLE on-demand rides
      final motorcycleRidesRaw = await PassengerApi.instance.getRidesByType(
        transportType: 'MOTORCYCLE',
        travelMode: 'ON_DEMAND',
        availableOnly: true,
      );

      if (!mounted) return;

      setState(() {
        _carRides = carRidesRaw.map((r) => Ride.fromJson(r)).toList();
        _motorcycleRides =
            motorcycleRidesRaw.map((r) => Ride.fromJson(r)).toList();
        _isLoadingRideTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep transport selection usable even when the availability API is unstable.
        _rideTypeFallbackMode = true;
        if (e is PassengerApiException && e.statusCode >= 500) {
          _rideTypeError = 'Transport availability is temporarily unavailable.';
        } else if (e is PassengerApiException) {
          _rideTypeError = e.message;
        } else {
          _rideTypeError = 'Unable to load transport availability right now.';
        }
        _isLoadingRideTypes = false;
      });
    }
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  Set<Marker> _homeMapMarkers() {
    final center = _currentLatLng ?? _kigaliCenter;
    return <Marker>{
      Marker(
        markerId: const MarkerId('you'),
        position: center,
        infoWindow: InfoWindow(
          title: 'Your Location',
          snippet:
              _currentLatLng != null
                  ? '${_currentLatLng!.latitude.toStringAsFixed(4)}, ${_currentLatLng!.longitude.toStringAsFixed(4)}'
                  : 'Default location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _currentLatLng != null
              ? BitmapDescriptor.hueBlue
              : BitmapDescriptor.hueRed,
        ),
      ),
    };
  }

  Future<void> _zoomIn() async {
    _mapZoom = (_mapZoom + 1).clamp(3, 20).toDouble();
    await _homeMapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
  }

  Future<void> _zoomOut() async {
    _mapZoom = (_mapZoom - 1).clamp(3, 20).toDouble();
    await _homeMapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
  }

  // ── Root build ─────────────────────────────────────────────────────────────
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
        child: RefreshIndicator(
          color: const Color(0xFF6C63FF),
          backgroundColor: _cardBg,
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

                // 5 – Ride type options (Private/Public)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionHeader(_lang.t('home.rideType'), null),
                ),
                const SizedBox(height: 14),
                _buildRideTypeOptions(),

                const SizedBox(height: 24),

                // 6 – Promo banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildPromoBanner(),
                ),

                const SizedBox(height: 24),

                // 7 – Book a Ride CTA
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
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _lang.t('home.whereTo'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _textSecondary,
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
              color:
                  _isDarkMode
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFD5E1F7),
              ),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: _isDarkMode ? Colors.white70 : const Color(0xFF475569),
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
      child: Container(
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
        child: ClipOval(
          child: ValueListenableBuilder(
            valueListenable: PassengerPreferencesService.profilePhotoNotifier,
            builder: (context, photoBytes, _) {
              if (photoBytes != null && photoBytes.isNotEmpty) {
                return Image.memory(photoBytes, fit: BoxFit.cover);
              }
              return Center(
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
              );
            },
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
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _isDarkMode
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.35)
                    : const Color(0xFFC9D6F2),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _isDarkMode
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                      : const Color(0xFF334155).withValues(alpha: 0.08),
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
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _lang.t('home.searchSubPrompt'),
                    style: GoogleFonts.poppins(color: _textMuted, fontSize: 11),
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
                  color: _textPrimary,
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
                color: _textPrimary,
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
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLatLng ?? _kigaliCenter,
                      zoom: _mapZoom,
                    ),
                    myLocationEnabled: _hasLocationPermission,
                    myLocationButtonEnabled: _hasLocationPermission,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                    cameraTargetBounds: CameraTargetBounds(_rwandaBounds),
                    minMaxZoomPreference: const MinMaxZoomPreference(8, 20),
                    markers: _homeMapMarkers(),
                    onMapCreated: (controller) {
                      _homeMapController = controller;
                      final point = _currentLatLng;
                      if (point != null) {
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(target: point, zoom: _mapZoom),
                          ),
                        );
                      }
                    },
                    onCameraMove: (position) {
                      _mapZoom = position.zoom;
                    },
                    onTap: (_) => widget.onGoToBookRide?.call(),
                  ),
                ),

                // Your Location chip – top left
                Positioned(
                  top: 14,
                  left: 14,
                  child: GestureDetector(
                    onTap: _initCurrentLocation,
                    child: _MapChip(
                      icon:
                          _isLocating
                              ? Icons.location_searching_rounded
                              : Icons.my_location_rounded,
                      text:
                          _hasLocationPermission
                              ? _lang.t('home.yourLocation')
                              : 'Enable location',
                      bg:
                          _isDarkMode
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.94),
                      fgColor:
                          _isDarkMode
                              ? Colors.white70
                              : const Color(0xFF334155),
                    ),
                  ),
                ),

                // Live Map chip – top right
                Positioned(
                  top: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MapChip(
                        icon: Icons.gps_fixed_rounded,
                        text: 'Live Map',
                        bg:
                            _isDarkMode
                                ? const Color(
                                  0xFF6C63FF,
                                ).withValues(alpha: 0.88)
                                : Colors.white.withValues(alpha: 0.95),
                        fgColor:
                            _isDarkMode
                                ? Colors.white
                                : const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _mapZoomBtn(Icons.remove_rounded, _zoomOut),
                          const SizedBox(width: 8),
                          _mapZoomBtn(Icons.add_rounded, _zoomIn),
                        ],
                      ),
                    ],
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

  Widget _mapZoomBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color:
          _isDarkMode
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: _isDarkMode ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
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
          value: CurrencyFormatter.formatPrice(spent),
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
            color: _textPrimary,
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

  // ── 6. Ride type options (Private/Public/Motorcycle) ──────────────────────────────────
  Widget _buildRideTypeOptions() {
    // Show loading state
    if (_isLoadingRideTypes) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show error state only when fallback mode is not available.
    if (_rideTypeError != null &&
        !_rideTypeFallbackMode &&
        _carRides.isEmpty &&
        _motorcycleRides.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _rideTypeError ?? 'Failed to load ride types',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Build ride type cards - display 3 options: Private (CAR), Public (shared), Motorcycle
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Private Ride (CAR - Individual) ─────────────────────────────
            SizedBox(
              width: 120,
              child: _buildRideTypeCard(
                label: _lang.t('home.private'),
                description: _lang.t('home.privateDesc'),
                icon: Icons.person_rounded,
                color: const Color(0xFF6C63FF),
                isAvailable: _rideTypeFallbackMode || _carRides.isNotEmpty,
                onTap:
                    (_rideTypeFallbackMode || _carRides.isNotEmpty)
                        ? () => _handleRideTypeSelected('CAR', 'PRIVATE')
                        : null,
              ),
            ),
            const SizedBox(width: 12),

            // ── Public Ride (Shared rides) ──────────────────────────────────
            SizedBox(
              width: 120,
              child: _buildRideTypeCard(
                label: _lang.t('home.public'),
                description: _lang.t('home.publicDesc'),
                icon: Icons.people_rounded,
                color: const Color(0xFF3B82F6),
                isAvailable: true, // Placeholder for shared rides
                onTap: () => _handleRideTypeSelected('CAR', 'SHARED'),
              ),
            ),
            const SizedBox(width: 12),

            // ── Motorcycle (ON_DEMAND only) ─────────────────────────────────
            SizedBox(
              width: 120,
              child: _buildRideTypeCard(
                label: _lang.t('home.motorcycle'),
                description: _lang.t('home.motorcycleDesc'),
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFFEA580C),
                isAvailable:
                    _rideTypeFallbackMode || _motorcycleRides.isNotEmpty,
                onTap:
                    (_rideTypeFallbackMode || _motorcycleRides.isNotEmpty)
                        ? () =>
                            _handleRideTypeSelected('MOTORCYCLE', 'ON_DEMAND')
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideTypeCard({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required bool isAvailable,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isAvailable ? (onTap ?? () {}) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isAvailable ? _cardBorder : _cardBorder.withValues(alpha: 0.4),
          ),
          boxShadow:
              isAvailable
                  ? [
                    BoxShadow(
                      color:
                          _isDarkMode
                              ? color.withValues(alpha: 0.12)
                              : const Color(0xFF334155).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isAvailable
                        ? color.withValues(alpha: 0.18)
                        : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isAvailable ? color : _textMuted,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isAvailable ? _textPrimary : _textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: GoogleFonts.poppins(
                color:
                    isAvailable
                        ? _textMuted
                        : _textMuted.withValues(alpha: 0.6),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isAvailable) ...[
              const SizedBox(height: 8),
              Text(
                'Unavailable',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handle ride type selection and navigate to booking
  void _handleRideTypeSelected(String transportType, String rideMode) {
    // For now, navigate to book ride
    widget.onGoToBookRide?.call();
    // TODO: In the future, pass ride type info to booking screen
  }

  // ── 7. Promo banner ───────────────────────────────────────────────────────
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

  // ── Helpers (Legacy - not used after removing quick ride options) ──────────
  // int _typeColorVal(String type) {
  //   final t = type.toLowerCase();
  //   if (t.contains('premium')) return 0xFF6C63FF;
  //   if (t.contains('bike')) return 0xFF10B981;
  //   if (t.contains('shared')) return 0xFFF59E0B;
  //   return 0xFF3B82F6;
  // }

  // IconData _typeIcon(String type) {
  //   final t = type.toLowerCase();
  //   if (t.contains('premium')) return Icons.star_rounded;
  //   if (t.contains('bike')) return Icons.electric_bike_rounded;
  //   if (t.contains('shared')) return Icons.local_taxi_rounded;
  //   return Icons.directions_car_rounded;
  // }

  // IconData _iconForLabel(String label) {
  //   switch (label.toLowerCase()) {
  //     case 'premium':
  //       return Icons.star_rounded;
  //     case 'bike':
  //       return Icons.electric_bike_rounded;
  //     case 'shared':
  //       return Icons.local_taxi_rounded;
  //     default:
  //       return Icons.directions_car_rounded;
  //   }
  // }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? const Color(0xFF1A1F3A) : Colors.white.withValues(alpha: 0.92);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white38 : const Color(0xFF475569);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
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
                      color: titleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      color: subtitleColor,
                      fontSize: 10,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? const Color(0xFF1A1F3A) : Colors.white.withValues(alpha: 0.92);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? Colors.white54 : const Color(0xFF475569);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg,
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
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(color: labelColor, fontSize: 10),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFFD5E1F7),
        ),
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
