import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;

import '../../services/passenger_api.dart';
import '../../services/passenger_language_service.dart';

class PassengerBookingFlowPage extends StatefulWidget {
  final VoidCallback? onBookingCompleted;

  const PassengerBookingFlowPage({super.key, this.onBookingCompleted});

  @override
  State<PassengerBookingFlowPage> createState() =>
      _PassengerBookingFlowPageState();
}

class _PassengerBookingFlowPageState extends State<PassengerBookingFlowPage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  static const LatLng _kigaliCenter = LatLng(-1.9441, 30.0619);
  static const String _kGooglePlacesApiKey =
      'AIzaSyA_eEtOH6NASsbFkH7xKQEVp46mnyk_3mc';

  _TravelTab _selectedTab = _TravelTab.rideRequest;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _pickupRequestController =
      TextEditingController();
  final TextEditingController _dropoffRequestController =
      TextEditingController();
  final TextEditingController _fareController = TextEditingController();

  final TextEditingController _pickupBookingController =
      TextEditingController();
  final TextEditingController _dropoffBookingController =
      TextEditingController();
  final TextEditingController _specialRequestsController =
      TextEditingController();

  Map<String, dynamic>? _selectedDriver;
  List<Map<String, dynamic>> _drivers = <Map<String, dynamic>>[];
  bool _loadingDrivers = false;
  String? _driversError;

  Map<String, dynamic>? _selectedRide;
  List<Map<String, dynamic>> _rides = <Map<String, dynamic>>[];
  bool _loadingRides = false;
  String? _ridesError;

  double? _pickupRequestLat;
  double? _pickupRequestLng;
  double? _dropoffRequestLat;
  double? _dropoffRequestLng;

  double? _pickupBookingLat;
  double? _pickupBookingLng;
  double? _dropoffBookingLat;
  double? _dropoffBookingLng;

  int _seats = 1;
  int _unreadCount = 0;

  bool _submitting = false;
  bool _approvalRequired = false;

  Map<String, String> _rideFieldErrors = <String, String>{};
  Map<String, String> _bookingFieldErrors = <String, String>{};

  Map<String, dynamic>? _rideRequestState;
  Map<String, dynamic>? _bookingState;
  String _rideRequestStatus = '';
  String _bookingStatus = '';

  int? _rideRequestId;
  int? _tripId;
  int? _bookingId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fareController.text = '0';
    _primeFormValues();
    _refreshAll();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _pickupRequestController.dispose();
    _dropoffRequestController.dispose();
    _fareController.dispose();
    _pickupBookingController.dispose();
    _dropoffBookingController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _primeFormValues() async {
    setState(() {
      _pickupRequestLat = _kigaliCenter.latitude;
      _pickupRequestLng = _kigaliCenter.longitude;
      _dropoffRequestLat = _kigaliCenter.latitude;
      _dropoffRequestLng = _kigaliCenter.longitude;
      _pickupBookingLat = _kigaliCenter.latitude;
      _pickupBookingLng = _kigaliCenter.longitude;
      _dropoffBookingLat = _kigaliCenter.latitude;
      _dropoffBookingLng = _kigaliCenter.longitude;
    });
    _recomputeEstimatedFare();
  }

  Future<String> _resolveAddressFromPoint(LatLng point) async {
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isEmpty) {
        return _lang.t('common.selectedLocation');
      }
      final place = places.first;
      final name = (place.name ?? '').trim();
      final street = (place.street ?? '').trim();
      final subLocality = (place.subLocality ?? '').trim();
      final locality = (place.locality ?? '').trim();
      final administrativeArea = (place.administrativeArea ?? '').trim();
      final country = (place.country ?? '').trim();

      final genericName = RegExp(
        r'^(?:\d+[\s,]*|\d+\s+KG|.*\bSt\.?\b)',
        caseSensitive: false,
      );
      final hasLetters = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]');
      final isGoodPlaceName =
          name.isNotEmpty &&
          name != street &&
          hasLetters.hasMatch(name) &&
          !genericName.hasMatch(name);

      if (isGoodPlaceName) {
        return [
          name,
          locality,
          administrativeArea,
          country,
        ].where((part) => part.isNotEmpty).take(2).join(', ');
      }

      if (street.isNotEmpty) {
        return [
          street,
          locality,
          administrativeArea,
        ].where((part) => part.isNotEmpty).take(2).join(', ');
      }

      if (subLocality.isNotEmpty) {
        return [
          subLocality,
          locality,
          administrativeArea,
        ].where((part) => part.isNotEmpty).take(2).join(', ');
      }

      final fallbackChunks = <String>[
        if (name.isNotEmpty) name,
        if (locality.isNotEmpty) locality,
        if (administrativeArea.isNotEmpty) administrativeArea,
      ];
      if (fallbackChunks.isEmpty) {
        return _lang.t('common.selectedLocation');
      }
      return fallbackChunks.take(2).join(', ');
    } catch (_) {
      return _lang.t('common.selectedLocation');
    }
  }

  Future<_PickedLocation?> _resolveLocationFromQuery(
    String query,
    LatLng fallback,
  ) async {
    try {
      final places = await locationFromAddress(query);
      if (places.isEmpty) {
        return null;
      }

      final first = places.first;
      final point = LatLng(first.latitude, first.longitude);
      final resolvedAddress = await _resolveAddressFromPoint(point);

      if (_isGenericResolvedAddress(resolvedAddress)) {
        final geocodedPlaces = await placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        );
        final locality =
            geocodedPlaces.isNotEmpty
                ? (geocodedPlaces.first.locality ??
                        geocodedPlaces.first.subLocality ??
                        geocodedPlaces.first.administrativeArea ??
                        '')
                    .trim()
                : '';
        final fallbackLabel = _buildLabelFromQuery(query, locality);
        return _PickedLocation(
          address: fallbackLabel.isNotEmpty ? fallbackLabel : resolvedAddress,
          point: point,
        );
      }

      return _PickedLocation(address: resolvedAddress, point: point);
    } catch (_) {
      return null;
    }
  }

  bool _isGenericResolvedAddress(String address) {
    if (address.toLowerCase().contains(
      _lang.t('common.selectedLocation').toLowerCase(),
    )) {
      return true;
    }
    final firstSegment = address.split(',').first.trim();
    final genericName = RegExp(
      r'^(?:\d+[\s,]*|\d+\s+KG|.*\bSt\.?\b)$',
      caseSensitive: false,
    );
    return genericName.hasMatch(firstSegment) || firstSegment.length <= 2;
  }

  String _buildLabelFromQuery(String query, String locality) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return locality;
    }
    final queryLabel = normalized
        .split(RegExp(r'\s+'))
        .map(
          (part) =>
              part.isEmpty
                  ? ''
                  : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .where((part) => part.isNotEmpty)
        .join(' ');
    return [queryLabel, locality].where((part) => part.isNotEmpty).join(', ');
  }

  Future<_PlaceSuggestionResult> _fetchPlaceSuggestions(String input) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'key': _kGooglePlacesApiKey,
          'language': 'en',
          'components': 'country:rw',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return const _PlaceSuggestionResult(
          suggestions: [],
          error: 'Unable to reach place search service.',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'UNKNOWN_ERROR';
      if (status == 'ZERO_RESULTS') {
        return const _PlaceSuggestionResult(suggestions: [], error: null);
      }
      if (status != 'OK') {
        return _PlaceSuggestionResult(
          suggestions: [],
          error:
              'Place search unavailable: $status. Enable Google Places API for this key.',
        );
      }

      final predictions = (data['predictions'] as List<dynamic>?) ?? [];
      return _PlaceSuggestionResult(
        suggestions:
            predictions
                .map(
                  (entry) => _PlaceSuggestion(
                    description: entry['description'] as String? ?? '',
                    placeId: entry['place_id'] as String? ?? '',
                  ),
                )
                .where((suggestion) => suggestion.description.isNotEmpty)
                .toList(),
        error: null,
      );
    } catch (_) {
      return const _PlaceSuggestionResult(
        suggestions: [],
        error: 'Place search failed. Check your network or API setup.',
      );
    }
  }

  // Native Places SDK wrapper (safe no-op stub)
  // TODO: When you add a native Places SDK plugin, implement these
  // methods to return native autocomplete results/place details.
  // They are intentionally safe no-ops so the existing HTTP/geocoding
  // fallback continues to work until you wire a real SDK.
  Future<_PlaceSuggestionResult> _nativePlaceSuggestions(String input) async {
    try {
      final sdk = places_sdk.FlutterGooglePlacesSdk(_kGooglePlacesApiKey);
      final res = await sdk.findAutocompletePredictions(
        input,
        countries: const ['RW'],
        placeTypesFilter: const [places_sdk.PlaceTypeFilter.ADDRESS],
      );

      final preds = (res as dynamic).predictions as List<dynamic>? ?? [];
      final suggestions =
          preds
              .map((p) {
                final desc =
                    (p as dynamic).fullText ??
                    (p as dynamic).getFullText?.call() ??
                    '';
                final id = (p as dynamic).placeId ?? '';
                return _PlaceSuggestion(
                  description: desc,
                  placeId: id,
                  location: null,
                );
              })
              .where((s) => s.description.isNotEmpty)
              .toList();

      return _PlaceSuggestionResult(suggestions: suggestions, error: null);
    } catch (_) {
      return const _PlaceSuggestionResult(suggestions: [], error: null);
    }
  }

  Future<_PlaceSuggestion?> _nativeFetchPlaceDetails(String placeId) async {
    try {
      final sdk = places_sdk.FlutterGooglePlacesSdk(_kGooglePlacesApiKey);
      // Request commonly needed fields; plugin will return available data.
      final place = await sdk.fetchPlace(
        placeId,
        fields: const [
          places_sdk.PlaceField.Location,
          places_sdk.PlaceField.Address,
          places_sdk.PlaceField.Name,
        ],
      );
      final lat = (place as dynamic).latLng?.lat as double?;
      final lng = (place as dynamic).latLng?.lng as double?;
      final desc =
          (place as dynamic).formattedAddress ?? (place as dynamic).name ?? '';
      if (lat == null || lng == null) return null;
      return _PlaceSuggestion(
        description: desc,
        placeId: placeId,
        location: LatLng(lat, lng),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_PlaceSuggestion?> _fetchPlaceDetails(String placeId) async {
    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
            'place_id': placeId,
            'key': _kGooglePlacesApiKey,
            'fields': 'name,formatted_address,geometry',
            'language': 'en',
          });
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        return null;
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return null;
      }
      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = location?['lat'] as num?;
      final lng = location?['lng'] as num?;
      final description =
          (result['formatted_address'] as String?) ??
          (result['name'] as String?) ??
          '';
      if (lat == null || lng == null || description.isEmpty) {
        return null;
      }

      return _PlaceSuggestion(
        description: description,
        placeId: placeId,
        location: LatLng(lat.toDouble(), lng.toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  void _recomputeEstimatedFare() {
    // Only compute an estimate when both pickup and dropoff are provided by user.
    final pickupText = _pickupRequestController.text.trim();
    final dropoffText = _dropoffRequestController.text.trim();
    if (pickupText.isEmpty || dropoffText.isEmpty) {
      _fareController.text = '0';
      return;
    }

    if (!_validLat(_pickupRequestLat) ||
        !_validLng(_pickupRequestLng) ||
        !_validLat(_dropoffRequestLat) ||
        !_validLng(_dropoffRequestLng)) {
      _fareController.text = '0';
      return;
    }

    final pickup = _latLngOrDefault(_pickupRequestLat, _pickupRequestLng);
    final dropoff = _latLngOrDefault(_dropoffRequestLat, _dropoffRequestLng);
    final meters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
    final km = meters / 1000;

    // Simple in-app fare estimate from distance. Server remains source of truth.
    final estimated = (2.2 + (km * 0.95)).clamp(0, 9999).toDouble();
    _fareController.text = estimated.toStringAsFixed(2);
  }

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      _loadUnreadCount(),
      _loadDrivers(),
      _loadRides(),
    ]);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      await _pollDetails();
    });
  }

  Future<void> _pollDetails() async {
    await _loadUnreadCount();
    if (_bookingId != null) {
      try {
        final booking = await PassengerApi.instance.getBookingById(_bookingId!);
        final data = _extractDataMap(booking);
        if (!mounted) return;
        setState(() {
          _bookingState = data;
          _bookingStatus = _normalizeStatus(
            _readString(data, const <String>['status', 'booking_status']),
          );
        });
      } catch (_) {}
    }
    if (_tripId != null) {
      try {
        final trip = await PassengerApi.instance.getTripById(_tripId!);
        final data = _extractDataMap(trip);
        if (!mounted) return;
        setState(() {
          _rideRequestState = data;
          _rideRequestStatus = _normalizeStatus(
            _readString(data, const <String>['status', 'trip_status']),
          );
        });
      } catch (_) {}
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await PassengerApi.instance.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loadingDrivers = true;
      _driversError = null;
    });
    try {
      final drivers = await PassengerApi.instance.getOnlineDrivers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _loadingDrivers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDrivers = false;
        _driversError = _errorText(e);
      });
    }
  }

  Future<void> _loadRides() async {
    setState(() {
      _loadingRides = true;
      _ridesError = null;
    });
    try {
      final rides = await PassengerApi.instance.getAvailableRides();
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _loadingRides = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRides = false;
        _ridesError = _errorText(e);
      });
    }
  }

  Future<void> _selectDriver() async {
    if (_loadingDrivers) return;
    if (_drivers.isEmpty && _driversError == null) {
      await _loadDrivers();
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _SelectionSheet(
            title: 'Select driver',
            child: _buildDriversSelectionContent(),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedDriver = result;
      _rideFieldErrors.remove('driver_id');
    });
  }

  Widget _buildDriversSelectionContent() {
    if (_loadingDrivers) {
      return const Column(
        children: <Widget>[
          _ShimmerBox(height: 84),
          SizedBox(height: 10),
          _ShimmerBox(height: 84),
          SizedBox(height: 10),
          _ShimmerBox(height: 84),
        ],
      );
    }
    if (_driversError != null) {
      return _ErrorState(
        title: 'Failed to load drivers',
        message: _driversError!,
        onRetry: _loadDrivers,
      );
    }
    if (_drivers.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_search_rounded,
        title: 'No online drivers',
        message: 'Pull to refresh or try again in a moment.',
      );
    }

    return Column(
      children:
          _drivers.map((driver) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(driver),
                child: _DriverCard(driver: driver),
              ),
            );
          }).toList(),
    );
  }

  Future<void> _selectRide() async {
    if (_loadingRides) return;
    if (_rides.isEmpty && _ridesError == null) {
      await _loadRides();
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _SelectionSheet(
            title: 'Select ride',
            child: _buildRideSelectionContent(),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedRide = result;
      _bookingFieldErrors.remove('ride_id');
    });
  }

  Widget _buildRideSelectionContent() {
    if (_loadingRides) {
      return const Column(
        children: <Widget>[
          _ShimmerBox(height: 96),
          SizedBox(height: 10),
          _ShimmerBox(height: 96),
          SizedBox(height: 10),
          _ShimmerBox(height: 96),
        ],
      );
    }
    if (_ridesError != null) {
      return _ErrorState(
        title: 'Failed to load rides',
        message: _ridesError!,
        onRetry: _loadRides,
      );
    }
    if (_rides.isEmpty) {
      return const _EmptyState(
        icon: Icons.route_outlined,
        title: 'No rides available',
        message: 'Tap Find rides to refresh available trips.',
      );
    }

    return Column(
      children:
          _rides.map((ride) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(ride),
                child: _RideListCard(ride: ride),
              ),
            );
          }).toList(),
    );
  }

  Future<void> _pickRequestPickup() async {
    final picked = await _openMapPicker(
      title: 'Pick pickup on map',
      initial: _latLngOrDefault(_pickupRequestLat, _pickupRequestLng),
    );
    if (picked == null || !mounted) return;
    final resolvedAddress = await _resolveAddressFromPoint(picked.point);
    if (!mounted) return;
    setState(() {
      _pickupRequestController.text = resolvedAddress;
      _pickupRequestLat = picked.point.latitude;
      _pickupRequestLng = picked.point.longitude;
      _rideFieldErrors.remove('pickup_location');
      _rideFieldErrors.remove('pickup_lat');
      _rideFieldErrors.remove('pickup_lng');
    });
    _recomputeEstimatedFare();
  }

  Future<void> _pickRequestDropoff() async {
    final picked = await _openMapPicker(
      title: 'Pick dropoff on map',
      initial: _latLngOrDefault(_dropoffRequestLat, _dropoffRequestLng),
    );
    if (picked == null || !mounted) return;
    final resolvedAddress = await _resolveAddressFromPoint(picked.point);
    if (!mounted) return;
    setState(() {
      _dropoffRequestController.text = resolvedAddress;
      _dropoffRequestLat = picked.point.latitude;
      _dropoffRequestLng = picked.point.longitude;
      _rideFieldErrors.remove('dropoff_location');
      _rideFieldErrors.remove('dropoff_lat');
      _rideFieldErrors.remove('dropoff_lng');
    });
    _recomputeEstimatedFare();
  }

  Future<void> _pickBookingPickup() async {
    final picked = await _openMapPicker(
      title: 'Pick booking pickup',
      initial: _latLngOrDefault(_pickupBookingLat, _pickupBookingLng),
    );
    if (picked == null || !mounted) return;
    final resolvedAddress = await _resolveAddressFromPoint(picked.point);
    if (!mounted) return;
    setState(() {
      _pickupBookingController.text = resolvedAddress;
      _pickupBookingLat = picked.point.latitude;
      _pickupBookingLng = picked.point.longitude;
      _bookingFieldErrors.remove('pickup_address');
    });
  }

  Future<void> _pickBookingDropoff() async {
    final picked = await _openMapPicker(
      title: 'Pick booking dropoff',
      initial: _latLngOrDefault(_dropoffBookingLat, _dropoffBookingLng),
    );
    if (picked == null || !mounted) return;
    final resolvedAddress = await _resolveAddressFromPoint(picked.point);
    if (!mounted) return;
    setState(() {
      _dropoffBookingController.text = resolvedAddress;
      _dropoffBookingLat = picked.point.latitude;
      _dropoffBookingLng = picked.point.longitude;
      _bookingFieldErrors.remove('dropoff_address');
    });
  }

  Future<_PickedLocation?> _openMapPicker({
    required String title,
    required LatLng initial,
  }) async {
    final addressController = TextEditingController(
      text: _lang.t('common.selectedLocation'),
    );
    LatLng selected = initial;
    List<_PlaceSuggestion> autocompleteSuggestions = [];
    bool isSearchingSuggestions = false;
    String suggestionError = '';
    Timer? autocompleteDebounce;

    final result = await showModalBottomSheet<_PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF0F1428) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final labelColor =
                isDark ? Colors.white70 : const Color(0xFF64748B);
            final fieldBg =
                isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFF1F5F9);
            final borderColor =
                isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFD1D5DB);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 280,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initial,
                          zoom: 14,
                        ),
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        onTap: (point) async {
                          final currentPoint = point;
                          setSheetState(() {
                            selected = currentPoint;
                            addressController.text = 'Loading location...';
                          });
                          final resolved = await _resolveAddressFromPoint(
                            currentPoint,
                          );
                          if (!context.mounted) return;
                          setSheetState(() {
                            if (selected == currentPoint) {
                              addressController.text = resolved;
                            }
                          });
                        },
                        markers: <Marker>{
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: selected,
                          ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    onChanged: (value) {
                      autocompleteDebounce?.cancel();
                      if (value.trim().isEmpty ||
                          value == _lang.t('common.selectedLocation') ||
                          value == _lang.t('book.locatingAddress')) {
                        setSheetState(() {
                          autocompleteSuggestions.clear();
                          suggestionError = '';
                          isSearchingSuggestions = false;
                        });
                        return;
                      }

                      autocompleteDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () async {
                          if (!context.mounted) return;
                          setSheetState(() {
                            isSearchingSuggestions = true;
                            suggestionError = '';
                          });

                          // Try native Places SDK first (if implemented). If
                          // native suggestions are unavailable, fall back to
                          // the existing HTTP Places autocomplete + geocoding.
                          final nativeResult = await _nativePlaceSuggestions(
                            value,
                          );
                          if (!context.mounted) return;

                          _PlaceSuggestionResult result;
                          if (nativeResult.suggestions.isNotEmpty ||
                              (nativeResult.error != null &&
                                  nativeResult.error!.isNotEmpty)) {
                            result = nativeResult;
                          } else {
                            result = await _fetchPlaceSuggestions(value);
                          }

                          if (!context.mounted) return;

                          List<_PlaceSuggestion> suggestions =
                              result.suggestions;
                          String fallbackError = result.error ?? '';
                          if (suggestions.isEmpty) {
                            final fallback = await _resolveLocationFromQuery(
                              value,
                              selected,
                            );
                            if (fallback != null) {
                              suggestions = <_PlaceSuggestion>[
                                _PlaceSuggestion(
                                  description: fallback.address,
                                  placeId: '',
                                  location: fallback.point,
                                ),
                              ];
                              fallbackError = '';
                            } else {
                              if (fallbackError.isEmpty) {
                                fallbackError =
                                    'No matching places were found.';
                              }
                            }
                          }

                          setSheetState(() {
                            autocompleteSuggestions = suggestions;
                            isSearchingSuggestions = false;
                            suggestionError = fallbackError;
                          });
                        },
                      );
                    },
                    style: GoogleFonts.poppins(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Address',
                      labelStyle: GoogleFonts.poppins(color: labelColor),
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  if (isSearchingSuggestions ||
                      autocompleteSuggestions.isNotEmpty ||
                      suggestionError.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 0,
                      ),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      constraints: const BoxConstraints(maxHeight: 180),
                      child:
                          isSearchingSuggestions
                              ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: <Widget>[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Searching places...',
                                      style: GoogleFonts.poppins(
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : autocompleteSuggestions.isNotEmpty
                              ? ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: autocompleteSuggestions.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion =
                                      autocompleteSuggestions[index];
                                  return ListTile(
                                    title: Text(
                                      suggestion.description,
                                      style: GoogleFonts.poppins(
                                        color: textColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onTap: () async {
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        isSearchingSuggestions = true;
                                        suggestionError = '';
                                      });

                                      // If the suggestion already has a location (fallback
                                      // geocoding), use it directly. Otherwise fetch
                                      // full place details from Places API.
                                      LatLng? resolvedPoint;
                                      String resolvedDescription =
                                          suggestion.description;
                                      if (suggestion.location != null) {
                                        resolvedPoint = suggestion.location;
                                      } else if (suggestion
                                          .placeId
                                          .isNotEmpty) {
                                        final place = await _fetchPlaceDetails(
                                          suggestion.placeId,
                                        );
                                        if (place != null &&
                                            place.location != null) {
                                          resolvedPoint = place.location;
                                          resolvedDescription =
                                              place.description;
                                        }
                                      }

                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        if (resolvedPoint != null) {
                                          selected = resolvedPoint!;
                                          addressController.text =
                                              resolvedDescription;
                                        }
                                        autocompleteSuggestions.clear();
                                        isSearchingSuggestions = false;
                                      });
                                    },
                                  );
                                },
                              )
                              : Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  suggestionError,
                                  style: GoogleFonts.poppins(color: labelColor),
                                ),
                              ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final inputText = addressController.text.trim();
                        if (inputText.isNotEmpty &&
                            inputText != 'Selected location' &&
                            inputText != 'Loading location...') {
                          final resolved = await _resolveLocationFromQuery(
                            inputText,
                            selected,
                          );
                          if (resolved != null) {
                            Navigator.of(context).pop(resolved);
                            return;
                          }
                        }
                        Navigator.of(context).pop(
                          _PickedLocation(
                            address: addressController.text.trim(),
                            point: selected,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        'Use this location',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    addressController.dispose();
    return result;
  }

  Future<void> _submitRideRequest() async {
    if (_submitting) return;

    final errors = <String, String>{};
    final driverId = _readInt(_selectedDriver?['id']);
    final pickup = _pickupRequestController.text.trim();
    final dropoff = _dropoffRequestController.text.trim();
    final fare = double.tryParse(_fareController.text.trim()) ?? 0;

    if (driverId == null || driverId <= 0) {
      errors['driver_id'] = _lang.t('book.driverRequired');
    }
    if (pickup.isEmpty) {
      errors['pickup_location'] = _lang.t('book.enterPickup');
    }
    if (dropoff.isEmpty) {
      errors['dropoff_location'] = _lang.t('book.enterDropoff');
    }
    if (!_validLat(_pickupRequestLat) || !_validLng(_pickupRequestLng)) {
      errors['pickup_lat'] = _lang.t('validation.pickupInvalidCoordinates');
    }
    if (!_validLat(_dropoffRequestLat) || !_validLng(_dropoffRequestLng)) {
      errors['dropoff_lat'] = _lang.t('validation.dropoffInvalidCoordinates');
    }
    if (fare < 0) {
      errors['fare'] = _lang.t('validation.fareNonNegative');
    }

    if (errors.isNotEmpty) {
      setState(() => _rideFieldErrors = errors);
      _showMessage('Please fix highlighted fields.');
      return;
    }

    setState(() {
      _submitting = true;
      _approvalRequired = false;
      _rideFieldErrors = <String, String>{};
    });

    try {
      final payload = <String, dynamic>{
        'driver_id': driverId,
        'pickup_location': pickup,
        'pickup_lat': _pickupRequestLat,
        'pickup_lng': _pickupRequestLng,
        'dropoff_location': dropoff,
        'dropoff_lat': _dropoffRequestLat,
        'dropoff_lng': _dropoffRequestLng,
        'fare': fare,
      };
      final response = await PassengerApi.instance.createRideRequest(payload);
      final data = _extractDataMap(response);

      setState(() {
        _rideRequestState = data;
        _rideRequestStatus = _normalizeStatus(
          _readString(data, const <String>['status', 'trip_status']) ??
              'pending',
        );
        _rideRequestId =
            _readInt(data['id']) ??
            _readInt(data['ride_request_id']) ??
            _readInt(data['request_id']);
        _tripId = _readInt(data['trip_id']) ?? _readInt(data['id']);
      });

      widget.onBookingCompleted?.call();
      _showMessage('Ride request sent successfully.');
    } catch (e) {
      if (e is PassengerApiException) {
        setState(() {
          _approvalRequired = e.isForbidden;
          if (e.isValidationError) {
            _rideFieldErrors = _mapRideFieldErrors(e.fieldErrors);
          }
        });
      }
      _showMessage(_errorText(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitBooking() async {
    if (_submitting) return;

    final errors = <String, String>{};
    final rideId = _readInt(_selectedRide?['id']);
    final pickup = _pickupBookingController.text.trim();
    final dropoff = _dropoffBookingController.text.trim();

    if (rideId == null || rideId <= 0) {
      errors['ride_id'] = 'Ride is required.';
    }
    if (_seats < 1 || _seats > 8) {
      errors['seats_booked'] = 'Seats must be between 1 and 8.';
    }
    if (pickup.isEmpty) {
      errors['pickup_address'] = 'Pickup address is required.';
    }
    if (dropoff.isEmpty) {
      errors['dropoff_address'] = 'Dropoff address is required.';
    }
    if (!_validLat(_pickupBookingLat) || !_validLng(_pickupBookingLng)) {
      errors['pickup_coords'] = 'Pickup coordinates are invalid.';
    }
    if (!_validLat(_dropoffBookingLat) || !_validLng(_dropoffBookingLng)) {
      errors['dropoff_coords'] = 'Dropoff coordinates are invalid.';
    }

    if (errors.isNotEmpty) {
      setState(() => _bookingFieldErrors = errors);
      _showMessage('Please fix highlighted fields.');
      return;
    }

    setState(() {
      _submitting = true;
      _approvalRequired = false;
      _bookingFieldErrors = <String, String>{};
    });

    try {
      final payload = <String, dynamic>{
        'ride_id': rideId,
        'seats_booked': _seats,
        'seats': _seats,
        'pickup_address': pickup,
        'pickup_location': pickup,
        'pickup_lat': _pickupBookingLat,
        'pickup_lng': _pickupBookingLng,
        'dropoff_address': dropoff,
        'dropoff_location': dropoff,
        'dropoff_lat': _dropoffBookingLat,
        'dropoff_lng': _dropoffBookingLng,
        if (_specialRequestsController.text.trim().isNotEmpty)
          'special_requests': _specialRequestsController.text.trim(),
      };
      final response = await PassengerApi.instance.createBooking(payload);
      final data = _extractDataMap(response);

      setState(() {
        _bookingState = data;
        _bookingStatus = _normalizeStatus(
          _readString(data, const <String>['status', 'booking_status']) ??
              'pending',
        );
        _bookingId =
            _readInt(data['id']) ??
            _readInt(data['booking_id']) ??
            _readInt(data['reference_id']);
      });

      widget.onBookingCompleted?.call();
      _showMessage('Booking created successfully.');
    } catch (e) {
      if (e is PassengerApiException) {
        setState(() {
          _approvalRequired = e.isForbidden;
          if (e.isValidationError) {
            _bookingFieldErrors = _mapBookingFieldErrors(e.fieldErrors);
          }
        });
      }
      _showMessage(_errorText(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _editBooking() async {
    if (_bookingId == null || _submitting) {
      _showMessage('No pending booking found to edit.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'seats_booked': _seats,
        'pickup_address': _pickupBookingController.text.trim(),
        'dropoff_address': _dropoffBookingController.text.trim(),
        if (_specialRequestsController.text.trim().isNotEmpty)
          'special_requests': _specialRequestsController.text.trim(),
      };
      final response = await PassengerApi.instance.updateBooking(
        _bookingId!,
        payload,
      );
      final data = _extractDataMap(response);
      setState(() {
        _bookingState = data;
        _bookingStatus = _normalizeStatus(
          _readString(data, const <String>['status', 'booking_status']) ??
              _bookingStatus,
        );
      });
      _showMessage('Booking updated.');
    } catch (e) {
      _showMessage(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelBooking() async {
    if (_bookingId == null || _submitting) return;
    final reason = await _askForReason(
      title: 'Cancel booking',
      hint: 'Add a short reason (optional)',
    );
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      await PassengerApi.instance.cancelBooking(_bookingId!);
      setState(() {
        _bookingStatus = 'cancelled';
        if (_bookingState != null) {
          _bookingState = <String, dynamic>{
            ..._bookingState!,
            'status': 'cancelled',
            if (reason.trim().isNotEmpty) 'cancel_reason': reason.trim(),
          };
        }
      });
      _showMessage('Booking cancelled.');
    } catch (e) {
      _showMessage(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelRideRequest() async {
    if (_submitting) return;
    if (_rideRequestId == null && _tripId == null) {
      _showMessage('No active trip/request found to cancel.');
      return;
    }

    final reason = await _askForReason(
      title: 'Cancel trip',
      hint: 'Tell us why you are cancelling',
    );
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      if (_rideRequestId != null) {
        await PassengerApi.instance.cancelRideRequest(_rideRequestId!);
      } else if (_tripId != null) {
        await PassengerApi.instance.cancelTrip(_tripId!);
      }
      setState(() {
        _rideRequestStatus = 'cancelled';
        if (_rideRequestState != null) {
          _rideRequestState = <String, dynamic>{
            ..._rideRequestState!,
            'status': 'cancelled',
            if (reason.trim().isNotEmpty) 'cancel_reason': reason.trim(),
          };
        }
      });
      _showMessage('Trip cancelled.');
    } catch (e) {
      _showMessage(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _askForReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F1428),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(controller.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _clearRideRequestForm() {
    setState(() {
      _selectedDriver = null;
      _pickupRequestController.clear();
      _dropoffRequestController.clear();
      _fareController.text = '0';
      _rideFieldErrors = <String, String>{};
      _rideRequestState = null;
      _rideRequestStatus = '';
      _rideRequestId = null;
      _tripId = null;
    });
  }

  void _clearBookingForm() {
    setState(() {
      _selectedRide = null;
      _pickupBookingController.clear();
      _dropoffBookingController.clear();
      _specialRequestsController.clear();
      _seats = 1;
      _bookingFieldErrors = <String, String>{};
      _bookingState = null;
      _bookingStatus = '';
      _bookingId = null;
    });
  }

  Map<String, String> _mapRideFieldErrors(Map<String, String> source) {
    final out = <String, String>{};
    source.forEach((key, value) {
      final k = key.toLowerCase();
      if (k.contains('driver')) out['driver_id'] = value;
      if (k.contains('pickup') && (k.contains('lat') || k.contains('lng'))) {
        out['pickup_lat'] = value;
      }
      if (k.contains('dropoff') && (k.contains('lat') || k.contains('lng'))) {
        out['dropoff_lat'] = value;
      }
      if (k.contains('pickup') && k.contains('location')) {
        out['pickup_location'] = value;
      }
      if (k.contains('dropoff') && k.contains('location')) {
        out['dropoff_location'] = value;
      }
      if (k.contains('fare')) out['fare'] = value;
    });
    return out;
  }

  Map<String, String> _mapBookingFieldErrors(Map<String, String> source) {
    final out = <String, String>{};
    source.forEach((key, value) {
      final k = key.toLowerCase();
      if (k.contains('ride')) out['ride_id'] = value;
      if (k.contains('seat')) out['seats_booked'] = value;
      if (k.contains('pickup')) out['pickup_address'] = value;
      if (k.contains('dropoff')) out['dropoff_address'] = value;
    });
    return out;
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error
                ? const Color(0xFF991B1B)
                : (isDark ? const Color(0xFF111827) : Colors.white),
        content: Text(
          text,
          style: GoogleFonts.poppins(
            color:
                error ? Colors.white : (isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  String _errorText(Object error) {
    if (error is PassengerApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  _ActionConfig _currentAction() {
    if (_selectedTab == _TravelTab.rideRequest) {
      final status = _rideRequestStatus;
      if (status.isEmpty) {
        return _ActionConfig(
          label: _lang.t('book.requestRide'),
          onTap: _submitRideRequest,
        );
      }
      if (status == 'pending') {
        return _ActionConfig(label: 'Cancel Trip', onTap: _cancelRideRequest);
      }
      if (status == 'accepted') {
        return _ActionConfig(
          label: _lang.t('book.viewDriverTrack'),
          onTap: () => _showMessage('Driver details loaded.'),
        );
      }
      if (status == 'started') {
        return _ActionConfig(
          label: _lang.t('book.liveTripView'),
          onTap: () => _showMessage('Opening live trip view...'),
        );
      }
      if (status == 'completed') {
        return _ActionConfig(
          label: _lang.t('book.rateTrip'),
          onTap: () => _showMessage('Rate trip flow coming next.'),
        );
      }
      return _ActionConfig(
        label: _lang.t('book.requestAgain'),
        onTap: _clearRideRequestForm,
      );
    }

    final status = _bookingStatus;
    if (status.isEmpty) {
      return _ActionConfig(
        label: _lang.t('book.bookNow'),
        onTap: _submitBooking,
      );
    }
    if (status == 'pending') {
      return _ActionConfig(
        label: _lang.t('book.editBooking'),
        onTap: _editBooking,
      );
    }
    if (status == 'confirmed') {
      return _ActionConfig(
        label: _lang.t('book.viewTicket'),
        onTap: () => _showMessage('Ticket details opened.'),
      );
    }
    if (status == 'completed') {
      return _ActionConfig(
        label: _lang.t('book.receipt'),
        onTap: () => _showMessage('Showing trip receipt.'),
      );
    }
    return _ActionConfig(
      label: _lang.t('book.rebook'),
      onTap: _clearBookingForm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = _currentAction();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFEFF4FF),
      appBar: AppBar(
        title: Text(
          _lang.t('nav.book'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
          children: <Widget>[
            if (_approvalRequired)
              const _StatusBanner(
                color: Color(0xFFF59E0B),
                title: 'Approval required',
                message:
                    'Your account is not approved yet. Please contact support to continue.',
              ),
            SegmentedButton<_TravelTab>(
              segments: <ButtonSegment<_TravelTab>>[
                ButtonSegment<_TravelTab>(
                  value: _TravelTab.rideRequest,
                  icon: Icon(Icons.local_taxi_rounded),
                  label: Text(_lang.t('book.requestRide')),
                ),
                ButtonSegment<_TravelTab>(
                  value: _TravelTab.booking,
                  icon: Icon(Icons.confirmation_number_rounded),
                  label: Text(_lang.t('book.title')),
                ),
              ],
              selected: <_TravelTab>{_selectedTab},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedTab = selection.first;
                });
              },
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child:
                  _selectedTab == _TravelTab.rideRequest
                      ? _buildRideRequestForm()
                      : _buildBookingForm(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0E162B) : Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : action.onTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _submitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            action.label,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideRequestForm() {
    return Column(
      key: const ValueKey<String>('ride_request_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _selectedDriver == null
                          ? _lang.t('book.noDriverSelected')
                          : _lang.t('book.driverSelected'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectDriver,
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: Text(_lang.t('book.selectDriver')),
                  ),
                ],
              ),
              if (_rideFieldErrors['driver_id'] != null)
                Text(
                  _rideFieldErrors['driver_id']!,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFEF4444),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 8),
              _selectedDriver == null
                  ? _EmptyState(
                    icon: Icons.person_outline_rounded,
                    title: _lang.t('book.noDriverSelected'),
                    message: _lang.t('book.tapSelectDriver'),
                  )
                  : _DriverCard(driver: _selectedDriver!),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LocationInputCard(
          title: _lang.t('book.pickupHint'),
          controller: _pickupRequestController,
          onPickMap: _pickRequestPickup,
          lat: _pickupRequestLat,
          lng: _pickupRequestLng,
          error:
              _rideFieldErrors['pickup_location'] ??
              _rideFieldErrors['pickup_lat'],
        ),
        const SizedBox(height: 10),
        _LocationInputCard(
          title: _lang.t('book.dropoffHint'),
          controller: _dropoffRequestController,
          onPickMap: _pickRequestDropoff,
          lat: _dropoffRequestLat,
          lng: _dropoffRequestLng,
          error:
              _rideFieldErrors['dropoff_location'] ??
              _rideFieldErrors['dropoff_lat'],
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _lang.t('book.estimatedFare'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFF6C63FF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final usd =
                              double.tryParse(_fareController.text) ?? 0.0;
                          const rate = 1465.70; // 1 USD = 1465.70 RWF
                          final rwf = (usd * rate).round();
                          final rwfStr = rwf.toString().replaceAllMapped(
                            RegExp(r"\B(?=(\d{3})+(?!\d))"),
                            (m) => ',',
                          );
                          return Text(
                            '${_lang.t('book.systemEstimate')}: RWF $rwfStr',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_rideFieldErrors['fare'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _rideFieldErrors['fare']!,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DirectionPreviewCard(
          title: 'Direction preview (in-app)',
          from: _latLngOrDefault(_pickupRequestLat, _pickupRequestLng),
          to: _latLngOrDefault(_dropoffRequestLat, _dropoffRequestLng),
        ),
        const SizedBox(height: 10),
        if (_rideRequestState != null)
          _StatusBanner(
            color: _statusColor(_rideRequestStatus),
            title: 'Ride request status: ${_rideRequestStatus.toUpperCase()}',
            message:
                _readString(_rideRequestState!, const <String>[
                  'message',
                  'note',
                  'details',
                ]) ??
                'Your trip request has been recorded.',
          ),
        if (_rideRequestState != null) const SizedBox(height: 10),
        if (_rideRequestState != null)
          _TripTimeline(
            status: _rideRequestStatus.isEmpty ? 'pending' : _rideRequestStatus,
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearRideRequestForm,
            child: const Text('Clear form'),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingForm() {
    final pricePerSeat =
        _readDouble(_selectedRide?['price_per_seat']) ??
        _readDouble(_selectedRide?['price']) ??
        0;
    final total = pricePerSeat * _seats;

    return Column(
      key: const ValueKey<String>('booking_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Ride selector',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loadRides,
                    child: const Text('Find rides'),
                  ),
                  TextButton(
                    onPressed: _selectRide,
                    child: const Text('Select ride'),
                  ),
                ],
              ),
              if (_bookingFieldErrors['ride_id'] != null)
                Text(
                  _bookingFieldErrors['ride_id']!,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFEF4444),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 8),
              _selectedRide == null
                  ? const _EmptyState(
                    icon: Icons.route_rounded,
                    title: 'No ride selected',
                    message:
                        'Use Select ride to choose from available options.',
                  )
                  : _RideListCard(ride: _selectedRide!),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Seats',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SeatCounterStepper(
                value: _seats,
                min: 1,
                max: 8,
                onChanged: (value) => setState(() => _seats = value),
              ),
              if (_bookingFieldErrors['seats_booked'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _bookingFieldErrors['seats_booked']!,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LocationInputCard(
          title: 'Pickup address',
          controller: _pickupBookingController,
          onPickMap: _pickBookingPickup,
          lat: _pickupBookingLat,
          lng: _pickupBookingLng,
          error: _bookingFieldErrors['pickup_address'],
        ),
        const SizedBox(height: 10),
        _LocationInputCard(
          title: 'Dropoff address',
          controller: _dropoffBookingController,
          onPickMap: _pickBookingDropoff,
          lat: _dropoffBookingLat,
          lng: _dropoffBookingLng,
          error: _bookingFieldErrors['dropoff_address'],
        ),
        const SizedBox(height: 10),
        _DirectionPreviewCard(
          title: 'Direction preview (in-app)',
          from: _latLngOrDefault(_pickupBookingLat, _pickupBookingLng),
          to: _latLngOrDefault(_dropoffBookingLat, _dropoffBookingLng),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Special requests',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _specialRequestsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Optional notes for your driver',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Price Summary',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _summaryRow('Seats', '$_seats'),
              _summaryRow(
                'Price per seat',
                '\$${pricePerSeat.toStringAsFixed(2)}',
              ),
              _summaryRow(
                'Total',
                '\$${total.toStringAsFixed(2)}',
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_bookingState != null)
          BookingStatusChip(
            status: _bookingStatus.isEmpty ? 'pending' : _bookingStatus,
          ),
        if (_bookingState != null) const SizedBox(height: 8),
        if (_bookingState != null)
          TicketStateBanner(
            travelType:
                _readString(_bookingState!, const <String>[
                  'travel_type',
                  'ride_type',
                  'type',
                ]) ??
                'standard',
            ticketStatus:
                _readString(_bookingState!, const <String>[
                  'ticket_status',
                  'status',
                ]) ??
                'pending',
          ),
        const SizedBox(height: 8),
        if (_bookingStatus == 'pending' || _bookingStatus == 'confirmed')
          Row(
            children: <Widget>[
              if (_bookingStatus == 'pending')
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _editBooking,
                    child: const Text('Edit Booking'),
                  ),
                ),
              if (_bookingStatus == 'pending') const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text('Cancel Booking'),
                ),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearBookingForm,
            child: const Text('Clear form'),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'started':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF6C63FF);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  LatLng _latLngOrDefault(double? lat, double? lng) {
    return LatLng(
      lat ?? _kigaliCenter.latitude,
      lng ?? _kigaliCenter.longitude,
    );
  }

  bool _validLat(double? value) => value != null && value >= -90 && value <= 90;

  bool _validLng(double? value) =>
      value != null && value >= -180 && value <= 180;

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  String _normalizeStatus(String? value) {
    final status = (value ?? '').trim().toLowerCase();
    if (status.isEmpty) return '';
    if (status.contains('confirm')) return 'confirmed';
    if (status.contains('accept')) return 'accepted';
    if (status.contains('start')) return 'started';
    if (status.contains('complete')) return 'completed';
    if (status.contains('cancel')) return 'cancelled';
    if (status.contains('reject')) return 'rejected';
    if (status.contains('pend')) return 'pending';
    return status;
  }

  String? _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }
}

enum _TravelTab { rideRequest, booking }

class _ActionConfig {
  const _ActionConfig({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _PickedLocation {
  const _PickedLocation({required this.address, required this.point});

  final String address;
  final LatLng point;
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.description,
    required this.placeId,
    this.location,
  });

  final String description;
  final String placeId;
  final LatLng? location;
}

class _PlaceSuggestionResult {
  const _PlaceSuggestionResult({required this.suggestions, this.error});

  final List<_PlaceSuggestion> suggestions;
  final String? error;
}

class _SelectionSheet extends StatelessWidget {
  const _SelectionSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1428) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFCBD5E1),
        ),
      ),
      child: child,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.title,
    required this.message,
  });

  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: GoogleFonts.poppins(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF64748B)),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: GoogleFonts.poppins(fontSize: 12)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({required this.height});

  final double height;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: const <Color>[
                Color(0xFF1F2937),
                Color(0xFF374151),
                Color(0xFF1F2937),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Map<String, dynamic> driver;

  @override
  Widget build(BuildContext context) {
    final name = (driver['name'] ?? driver['full_name'] ?? 'Driver').toString();
    final rating =
        (driver['rating'] ?? driver['avg_rating'] ?? 'N/A').toString();
    final online = (driver['status'] ?? 'online').toString().toLowerCase();
    final isOnline = online.contains('online');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            child: Text(name.isEmpty ? 'D' : name[0].toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Rating: $rating',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B))
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isOnline ? 'Online' : 'Offline',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color:
                    isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationInputCard extends StatelessWidget {
  const _LocationInputCard({
    required this.title,
    required this.controller,
    required this.onPickMap,
    required this.lat,
    required this.lng,
    this.error,
  });

  final String title;
  final TextEditingController controller;
  final VoidCallback onPickMap;
  final double? lat;
  final double? lng;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final lang = PassengerLanguageService.instance;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onPickMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(lang.t('book.tapToSetOnMap')),
              ),
            ],
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: lang.t('common.enterAddress'),
              errorText: error,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.map_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lat == null || lng == null
                        ? lang.t('common.noMapPinSelected')
                        : lang.t('common.locationPinnedOnMap'),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionPreviewCard extends StatefulWidget {
  const _DirectionPreviewCard({
    required this.title,
    required this.from,
    required this.to,
  });

  final String title;
  final LatLng from;
  final LatLng to;

  @override
  State<_DirectionPreviewCard> createState() => _DirectionPreviewCardState();
}

class _DirectionPreviewCardState extends State<_DirectionPreviewCard> {
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String? _durationText;
  String? _distanceText;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _updateRoute();
  }

  @override
  void didUpdateWidget(covariant _DirectionPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) {
      _updateRoute();
    }
  }

  Future<void> _updateRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _durationText = null;
      _distanceText = null;
      _polylines = {};
      _markers = {};
    });

    try {
      final params = {
        'origin': '${widget.from.latitude},${widget.from.longitude}',
        'destination': '${widget.to.latitude},${widget.to.longitude}',
        'mode': 'driving',
        'language': 'en',
        'key': _PassengerBookingFlowPageState._kGooglePlacesApiKey,
      };
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        params,
      );
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'UNKNOWN';
        if (status == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List).first as Map<String, dynamic>;
          final overview = route['overview_polyline'] as Map<String, dynamic>?;
          final pointsEncoded =
              overview != null ? (overview['points'] as String?) : null;

          final legs = (route['legs'] as List<dynamic>?) ?? <dynamic>[];
          if (legs.isNotEmpty) {
            final leg = legs.first as Map<String, dynamic>;
            _durationText = (leg['duration']?['text'] as String?) ?? null;
            _distanceText = (leg['distance']?['text'] as String?) ?? null;
          }

          List<LatLng> decoded;
          if (pointsEncoded != null && pointsEncoded.isNotEmpty) {
            decoded = _decodePolyline(pointsEncoded);
          } else {
            decoded = [widget.from, widget.to];
          }

          _polylines = {
            Polyline(
              polylineId: const PolylineId('route_preview'),
              points: decoded,
              color: const Color(0xFF3B82F6),
              width: 5,
            ),
          };
          _markers = {
            Marker(
              markerId: const MarkerId('from_marker'),
              position: widget.from,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
            Marker(markerId: const MarkerId('to_marker'), position: widget.to),
          };
        } else {
          _error = 'Directions unavailable: $status';
          // fallback: straight line + local distance & ETA estimate
          final meters = Geolocator.distanceBetween(
            widget.from.latitude,
            widget.from.longitude,
            widget.to.latitude,
            widget.to.longitude,
          );
          final km = (meters / 1000);
          _distanceText = '${km.toStringAsFixed(2)} km';
          // Estimate travel time using an average urban speed (30 km/h)
          final avgKmh = 30.0;
          final minutes = (km / avgKmh) * 60;
          _durationText = '${minutes.round()} mins';

          _polylines = {
            Polyline(
              polylineId: const PolylineId('route_preview'),
              points: [widget.from, widget.to],
              color: const Color(0xFF3B82F6),
              width: 3,
            ),
          };
          _markers = {
            Marker(
              markerId: const MarkerId('from_marker'),
              position: widget.from,
            ),
            Marker(markerId: const MarkerId('to_marker'), position: widget.to),
          };
        }
      } else {
        _error = 'Failed to fetch directions (${resp.statusCode})';
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route_preview'),
            points: [widget.from, widget.to],
            color: const Color(0xFF3B82F6),
            width: 3,
          ),
        };
        _markers = {
          Marker(
            markerId: const MarkerId('from_marker'),
            position: widget.from,
          ),
          Marker(markerId: const MarkerId('to_marker'), position: widget.to),
        };
      }
    } catch (e) {
      _error = e.toString();
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_preview'),
          points: [widget.from, widget.to],
          color: const Color(0xFF3B82F6),
          width: 3,
        ),
      };
      _markers = {
        Marker(markerId: const MarkerId('from_marker'), position: widget.from),
        Marker(markerId: const MarkerId('to_marker'), position: widget.to),
      };
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = <LatLng>[];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      while (true) {
        final int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      final int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      while (true) {
        final int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      final int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (widget.from.latitude + widget.to.latitude) / 2,
      (widget.from.longitude + widget.to.longitude) / 2,
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_loading) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(minHeight: 4),
          ],
          if (_durationText != null || _distanceText != null || _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
              child: Row(
                children: [
                  if (_durationText != null)
                    Text(
                      '$_durationText',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  if (_durationText != null && _distanceText != null)
                    const SizedBox(width: 8),
                  if (_distanceText != null)
                    Text(
                      '• $_distanceText',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: center, zoom: 13),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                markers:
                    _markers.isEmpty
                        ? {
                          Marker(
                            markerId: const MarkerId('from_marker'),
                            position: widget.from,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                          ),
                          Marker(
                            markerId: const MarkerId('to_marker'),
                            position: widget.to,
                          ),
                        }
                        : _markers,
                polylines:
                    _polylines.isEmpty
                        ? {
                          Polyline(
                            polylineId: const PolylineId('route_preview'),
                            points: [widget.from, widget.to],
                            color: const Color(0xFF3B82F6),
                            width: 3,
                          ),
                        }
                        : _polylines,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeatCounterStepper extends StatelessWidget {
  const SeatCounterStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          ),
          child: Text(
            '$value',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _TripTimeline extends StatelessWidget {
  const _TripTimeline({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const steps = <String>['Pending', 'Accepted', 'Started', 'Completed'];
    final normalized = status.toLowerCase();
    int activeIndex = 0;
    if (normalized == 'accepted') activeIndex = 1;
    if (normalized == 'started') activeIndex = 2;
    if (normalized == 'completed') activeIndex = 3;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Trip Timeline',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(steps.length, (index) {
            final active = index <= activeIndex;
            return Row(
              children: <Widget>[
                Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color:
                      active
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  steps[index],
                  style: GoogleFonts.poppins(
                    color: active ? const Color(0xFF10B981) : null,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _RideListCard extends StatelessWidget {
  const _RideListCard({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final origin =
        (ride['origin'] ?? ride['pickup_location'] ?? ride['from'] ?? 'Origin')
            .toString();
    final destination =
        (ride['destination'] ??
                ride['dropoff_location'] ??
                ride['to'] ??
                'Destination')
            .toString();
    final departure =
        (ride['departure_time'] ?? ride['departure'] ?? '--').toString();
    final seats = (ride['available_seats'] ?? ride['seats'] ?? '--').toString();
    final price = (ride['price_per_seat'] ?? ride['price'] ?? '--').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.route_rounded,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$origin -> $destination',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Departure: $departure',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text(
            'Available seats: $seats',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          Text('Price/seat: $price', style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }
}

class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFFF59E0B);
    if (status == 'confirmed') color = const Color(0xFF10B981);
    if (status == 'completed') color = const Color(0xFF6C63FF);
    if (status == 'cancelled') color = const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Booking status: ${status.toUpperCase()}',
        style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TicketStateBanner extends StatelessWidget {
  const TicketStateBanner({
    super.key,
    required this.travelType,
    required this.ticketStatus,
  });

  final String travelType;
  final String ticketStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.confirmation_number_rounded,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Travel type: $travelType | Ticket: $ticketStatus',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
