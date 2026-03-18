import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/trips/data/passenger_trips_api_service.dart';
import '../../services/passenger_language_service.dart';

/// Book Ride screen — passenger selects pickup, destination and ride type.
class BookRidePage extends StatefulWidget {
  final String? initialPickup;
  final String? initialDropoff;
  final int? initialSeats;
  final String? initialRideType;
  final VoidCallback? onBookingCompleted;
  final bool popAfterBooking;

  const BookRidePage({
    super.key,
    this.initialPickup,
    this.initialDropoff,
    this.initialSeats,
    this.initialRideType,
    this.onBookingCompleted,
    this.popAfterBooking = false,
  });

  @override
  State<BookRidePage> createState() => _BookRidePageState();
}

class _BookRidePageState extends State<BookRidePage> {
  static const LatLng _kigaliCenter = LatLng(-1.9441, 30.0619);

  late final TextEditingController _pickupController;
  late final TextEditingController _destinationController;
  late final TextEditingController _seatsController;
  GoogleMapController? _mapController;
  double _mapZoom = 13.8;
  String _selectedRide = 'Economy';
  bool _selectingPickup = false;
  LatLng _pickupLatLng = _kigaliCenter;
  LatLng? _destinationLatLng;
  bool _isRequesting = false;
  bool _isLoadingOptions = true;
  List<Map<String, dynamic>> _availableOptions = <Map<String, dynamic>>[];
  PassengerLanguageService get _lang => PassengerLanguageService.instance;

  static const List<Map<String, dynamic>> _rideTypes = [
    {
      'label': 'Economy',
      'icon': Icons.directions_car_rounded,
      'price': '\$3.50',
      'eta': '4 min',
      'color': 0xFF3B82F6,
    },
    {
      'label': 'Premium',
      'icon': Icons.star_rounded,
      'price': '\$8.00',
      'eta': '6 min',
      'color': 0xFF6C63FF,
    },
    {
      'label': 'Bike',
      'icon': Icons.electric_bike_rounded,
      'price': '\$1.20',
      'eta': '2 min',
      'color': 0xFF10B981,
    },
  ];

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);

    final seedPickup = widget.initialPickup?.trim();
    final seedDropoff = widget.initialDropoff?.trim();
    final seedSeats = widget.initialSeats;
    final normalizedSeats =
        (seedSeats != null && seedSeats >= 1 && seedSeats <= 8) ? seedSeats : 1;

    _pickupController = TextEditingController(
      text:
          (seedPickup == null || seedPickup.isEmpty)
              ? 'Current Location'
              : seedPickup,
    );
    _destinationController = TextEditingController(text: seedDropoff ?? '');
    _seatsController = TextEditingController(text: '$normalizedSeats');

    final seedRideType = widget.initialRideType?.trim();
    if (seedRideType != null && seedRideType.isNotEmpty) {
      _selectedRide = seedRideType;
    }

    _loadAvailableRides();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _mapController?.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  String _coordsLabel(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  Future<String?> _reverseGeocodePoint(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final rawParts = <String?>[
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.country,
      ];

      final parts = <String>[];
      for (final part in rawParts) {
        final value = (part ?? '').trim();
        if (value.isEmpty || parts.contains(value)) continue;
        parts.add(value);
      }
      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  void _onMapTapped(LatLng point) async {
    final isPickupSelection = _selectingPickup;
    setState(() {
      if (isPickupSelection) {
        _pickupLatLng = point;
        _pickupController.text = 'Locating address...';
      } else {
        _destinationLatLng = point;
        _destinationController.text = 'Locating address...';
      }
    });

    final address = await _reverseGeocodePoint(point);
    if (!mounted) return;

    setState(() {
      final resolvedValue = address ?? _coordsLabel(point);
      if (isPickupSelection) {
        _pickupController.text = resolvedValue;
      } else {
        _destinationController.text = resolvedValue;
      }
    });
  }

  Future<void> _zoomIn() async {
    _mapZoom = (_mapZoom + 1).clamp(3, 20).toDouble();
    await _mapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
  }

  Future<void> _zoomOut() async {
    _mapZoom = (_mapZoom - 1).clamp(3, 20).toDouble();
    await _mapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAvailableRides() async {
    try {
      final rides = await passengerTripsApi.fetchAvailableRides();
      final options =
          rides.map((RideSummary r) {
            final type = r.rideType.isNotEmpty ? r.rideType : 'Economy';
            String eta = '--';
            if (r.departureTime != null) {
              final h = r.departureTime!.hour.toString().padLeft(2, '0');
              final m = r.departureTime!.minute.toString().padLeft(2, '0');
              eta = '$h:$m';
            }
            final price =
                r.pricePerSeat > 0 ? r.pricePerSeat.toStringAsFixed(2) : '--';
            return <String, dynamic>{
              'ride_id': r.id,
              'label': type,
              'icon': _iconForType(type),
              'price': '\$$price',
              'eta': eta,
              'color': _colorForType(type),
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _availableOptions = options;
        if (options.isNotEmpty) {
          final selectedExists = options.any(
            (item) =>
                (item['label']?.toString().toLowerCase() ?? '') ==
                _selectedRide.toLowerCase(),
          );
          _selectedRide =
              selectedExists ? _selectedRide : options.first['label'] as String;
        }
        _isLoadingOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOptions = false);
    }
  }

  void _requestRide() async {
    final pickup = _pickupController.text.trim();
    final dropoff = _destinationController.text.trim();
    final seats = int.tryParse(_seatsController.text.trim());

    if (pickup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            _lang.t('book.enterPickup'),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    if (dropoff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            _lang.t('book.enterDropoff'),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    if (seats == null || seats < 1 || seats > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            _lang.t('book.seatRangeError'),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    final options = _effectiveRideTypes();
    final selected = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.isNotEmpty ? options.first : <String, dynamic>{},
    );
    final rideId = selected['ride_id'] as int?;
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            _lang.t('book.noRideIdError'),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    setState(() => _isRequesting = true);
    try {
      await passengerTripsApi.createBooking(
        CreateBookingRequest(
          rideId: rideId,
          seats: seats,
          pickupAddress: pickup,
          dropoffAddress: dropoff,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequesting = false);
      final msg =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(msg, style: GoogleFonts.poppins(color: Colors.white70)),
        ),
      );
      return;
    }
    setState(() => _isRequesting = false);
    if (!mounted) return;
    _showRideConfirmationDialog();
  }

  void _showRideConfirmationDialog() {
    final options = _effectiveRideTypes();
    final ride = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.first,
    );
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF131729),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(ride['color'] as int).withValues(alpha: 0.2),
                      border: Border.all(
                        color: Color(
                          ride['color'] as int,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      ride['icon'] as IconData,
                      color: Color(ride['color'] as int),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lang.t('book.rideRequestedTitle'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lang.t(
                      'book.rideRequestedBody',
                      args: <String, String>{
                        'ride': _selectedRide,
                        'eta': ride['eta'].toString(),
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    label: _lang.t('book.estimatedFare'),
                    value: ride['price'] as String,
                  ),
                  _InfoRow(
                    label: _lang.t('book.eta'),
                    value: ride['eta'] as String,
                  ),
                  _InfoRow(
                    label: _lang.t('book.seats'),
                    value: _seatsController.text.trim(),
                  ),
                  _InfoRow(
                    label: _lang.t('book.destination'),
                    value: _destinationController.text.trim(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _GradientButton(
                      label: _lang.t('book.trackDriver'),
                      onTap: () {
                        Navigator.pop(context);
                        _handleBookingCompleted();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _handleBookingCompleted() {
    widget.onBookingCompleted?.call();
    if (widget.popAfterBooking && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1F3A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageTitle(
                _lang.t('book.title'),
                Icons.directions_car_rounded,
              ),
              if (_isLoadingOptions) const SizedBox(height: 10),
              if (_isLoadingOptions)
                const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 24),
              _buildMapContainer(),
              const SizedBox(height: 22),
              _buildLocationCard(),
              const SizedBox(height: 22),
              _buildRideTypeSection(),
              const SizedBox(height: 22),
              _buildFareCard(),
              const SizedBox(height: 28),
              _buildRequestButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMapContainer() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      if (_destinationLatLng != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _kigaliCenter,
                zoom: _mapZoom,
              ),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              compassEnabled: true,
              markers: markers,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: (position) {
                _mapZoom = position.zoom;
              },
              onTap: _onMapTapped,
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _selectingPickup,
                        onSelected:
                            (_) => setState(() => _selectingPickup = true),
                        label: Text(
                          _lang.t('book.pickupHint'),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: !_selectingPickup,
                        onSelected:
                            (_) => setState(() => _selectingPickup = false),
                        label: Text(
                          _lang.t('book.dropoffHint'),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mapZoomBtn(Icons.remove_rounded, _zoomOut),
                      const SizedBox(width: 8),
                      _mapZoomBtn(Icons.add_rounded, _zoomIn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _selectingPickup
                          ? '${_lang.t('book.tapToSetOnMap')} (${_lang.t('book.pickupHint')})'
                          : '${_lang.t('book.tapToSetOnMap')} (${_lang.t('book.dropoffHint')})',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapZoomBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _LocationField(
            controller: _pickupController,
            hint: _lang.t('book.pickupHint'),
            icon: Icons.radio_button_checked_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.15),
                  margin: const EdgeInsets.only(left: 11),
                ),
              ],
            ),
          ),
          _LocationField(
            controller: _destinationController,
            hint: _lang.t('book.dropoffHint'),
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF6C63FF),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.15),
                  margin: const EdgeInsets.only(left: 11),
                ),
              ],
            ),
          ),
          _LocationField(
            controller: _seatsController,
            hint: _lang.t('book.seatsHint'),
            icon: Icons.event_seat_rounded,
            iconColor: const Color(0xFFFBBF24),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildRideTypeSection() {
    final rideTypes = _effectiveRideTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _lang.t('book.chooseRideType'),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children:
              rideTypes.map((r) {
                final isSelected = _selectedRide == r['label'];
                final color = Color(r['color'] as int);
                return Expanded(
                  child: GestureDetector(
                    onTap:
                        () => setState(
                          () => _selectedRide = r['label'] as String,
                        ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? color.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isSelected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            r['icon'] as IconData,
                            color: isSelected ? color : Colors.white38,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r['label'] as String,
                            style: GoogleFonts.poppins(
                              color: isSelected ? color : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            r['price'] as String,
                            style: GoogleFonts.poppins(
                              color: isSelected ? color : Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildFareCard() {
    final options = _effectiveRideTypes();
    final ride = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.first,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: _lang.t('book.estimatedFare'),
            value: ride['price'] as String,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: _lang.t('book.estimatedArrival'),
            value: ride['eta'] as String,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: _lang.t('book.seats'),
            value: _seatsController.text.trim(),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: _lang.t('book.rideType'), value: _selectedRide),
        ],
      ),
    );
  }

  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isRequesting ? null : _requestRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon:
              _isRequesting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                  : const Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          label: Text(
            _isRequesting
                ? _lang.t('book.findingDriver')
                : _lang.t('book.requestRide'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _effectiveRideTypes() {
    return _availableOptions.isNotEmpty
        ? _availableOptions
        : List<Map<String, dynamic>>.from(_rideTypes);
  }

  int _colorForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('premium')) return 0xFF6C63FF;
    if (lower.contains('bike')) return 0xFF10B981;
    return 0xFF3B82F6;
  }

  IconData _iconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('premium')) return Icons.star_rounded;
    if (lower.contains('bike')) return Icons.electric_bike_rounded;
    return Icons.directions_car_rounded;
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;

  const _LocationField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 14,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
