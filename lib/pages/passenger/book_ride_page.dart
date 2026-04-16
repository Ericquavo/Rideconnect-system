import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/mobile/data/mobile_flow_api_service.dart';
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
  bool _isPaying = false;
  bool _isLoadingOptions = true;
  String _selectedPaymentMethod = 'cash';
  List<Map<String, dynamic>> _availableOptions = <Map<String, dynamic>>[];
  CreateBookingResponse? _latestBooking;
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
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);

    final seedPickup = widget.initialPickup?.trim();
    final seedDropoff = widget.initialDropoff?.trim();
    final seedSeats = widget.initialSeats;
    final normalizedSeats =
        (seedSeats != null && seedSeats >= 1 && seedSeats <= 8) ? seedSeats : 1;

    _pickupController = TextEditingController(
      text:
          (seedPickup == null || seedPickup.isEmpty)
              ? _lang.t('book.currentLocation')
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

  void _showSnack(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isDark ? const Color(0xFF131729) : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
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
        _pickupController.text = _lang.t('book.locatingAddress');
      } else {
        _destinationLatLng = point;
        _destinationController.text = _lang.t('book.locatingAddress');
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
              'price_per_seat': r.pricePerSeat,
              'eta': eta,
              'color': _colorForType(type),
              'available_seats': r.availableSeats,
              'departure_time': r.departureTime?.toIso8601String(),
              'is_scheduled': _isScheduledDeparture(r.departureTime),
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
          _syncSeatsToAvailability();
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
    final seats = int.tryParse(_seatsController.text.trim()) ?? 1;

    if (pickup.isEmpty) {
      _showSnack(_lang.t('book.enterPickup'));
      return;
    }

    if (dropoff.isEmpty) {
      _showSnack(_lang.t('book.enterDropoff'));
      return;
    }

    if (seats < 1 || seats > 8) {
      _showSnack(_lang.t('book.seatRangeError'));
      return;
    }

    final maxSeats = _availableSeatsForSelectedRide();
    if (seats > maxSeats) {
      _showSnack(
        _lang.t('book.availableSeatsOnly', args: {'count': '$maxSeats'}),
      );
      _syncSeatsToAvailability();
      return;
    }

    final options = _effectiveRideTypes();
    final selected = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.isNotEmpty ? options.first : <String, dynamic>{},
    );
    final rideId = _readRideId(selected);
    final selectedDeparture = DateTime.tryParse(
      (selected['departure_time'] ?? '').toString(),
    );
    final isScheduled = _isScheduledDeparture(selectedDeparture);

    setState(() => _isRequesting = true);
    try {
      if (rideId != null && rideId > 0) {
        final booking = await passengerTripsApi.createBooking(
          CreateBookingRequest(
            rideId: rideId,
            seats: seats,
            pickupAddress: pickup,
            dropoffAddress: dropoff,
            rideType: _selectedRide,
            scheduledAt: isScheduled ? selectedDeparture : null,
          ),
        );
        _latestBooking = booking;
      } else {
        final fallbackScheduledAt =
            isScheduled
                ? (selectedDeparture ??
                    DateTime.now().add(const Duration(hours: 6)))
                : null;
        final selectedFare = _readDoubleValue(selected['price_per_seat']);
        await _createCustomRideRequest(
          pickup: pickup,
          dropoff: dropoff,
          seats: seats,
          selectedRide: selected,
          fare: selectedFare,
          scheduledAt: fallbackScheduledAt,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequesting = false);
      final msg =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      _showSnack(msg);
      return;
    }
    setState(() => _isRequesting = false);
    if (!mounted) return;
    _showRideConfirmationDialog();
  }

  Future<void> _createCustomRideRequest({
    required String pickup,
    required String dropoff,
    required int seats,
    required Map<String, dynamic> selectedRide,
    required double fare,
    DateTime? scheduledAt,
  }) async {
    final drivers = await mobileFlowApi.getOnlineDrivers();
    if (drivers.isEmpty) {
      throw Exception('No available driver found for this request.');
    }

    final firstDriver = drivers.first;
    final driverId = firstDriver.id;
    if (driverId <= 0) {
      throw Exception(
        'No backend ride_id found. Refresh available rides and try again.',
      );
    }

    await mobileFlowApi.createRideRequest(
      RideRequestPayload(
        driverId: driverId,
        pickupLocation: pickup,
        pickupLat: _pickupLatLng.latitude,
        pickupLng: _pickupLatLng.longitude,
        dropoffLocation: dropoff,
        dropoffLat: _destinationLatLng?.latitude ?? _pickupLatLng.latitude,
        dropoffLng: _destinationLatLng?.longitude ?? _pickupLatLng.longitude,
        fare: fare,
        seats: seats,
        rideType: _selectedRide,
        scheduledAt: scheduledAt,
      ),
    );
  }

  int? _readRideId(Map<String, dynamic> source) {
    final value = source['ride_id'] ?? source['id'];
    final parsed = _readNumeric(value);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  int? _readNumeric(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _readDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  bool _isScheduledDeparture(DateTime? departure) {
    if (departure == null) return false;
    return departure.difference(DateTime.now()).inHours >= 6;
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
                        'ride': _rideTypeLabel(_selectedRide),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _buildPaymentMethodSelector(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isPaying ? null : _payForLatestBooking,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon:
                          _isPaying
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.payments_rounded),
                      label: Text(
                        _isPaying
                            ? _lang.t(
                              'book.processingPayment',
                              args: {
                                'method': _paymentLabel(_selectedPaymentMethod),
                              },
                            )
                            : _lang.t(
                              'book.payNowWithMethod',
                              args: {
                                'method': _paymentLabel(_selectedPaymentMethod),
                              },
                            ),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
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

  Future<void> _payForLatestBooking() async {
    final booking = _latestBooking;
    if (booking == null || booking.id <= 0) {
      _showSnack(_lang.t('book.noBookingToPay'));
      return;
    }

    final double amount = booking.totalPrice > 0 ? booking.totalPrice : 0.0;
    if (amount <= 0) {
      _showSnack(_lang.t('book.invalidBookingAmount'));
      return;
    }

    setState(() => _isPaying = true);
    try {
      final payment = await passengerTripsApi.createPayment(
        CreatePaymentRequest(
          bookingId: booking.id,
          amount: amount,
          paymentMethod: _selectedPaymentMethod,
          reference: 'booking-${booking.id}',
        ),
      );
      if (!mounted) return;
      _showSnack(
        _lang.t(
          'book.paymentStatus',
          args: {
            'status': payment.status.isEmpty ? 'processed' : payment.status,
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      _showSnack(msg);
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Widget _buildPaymentMethodSelector() {
    const methods = <String>['cash', 'mobile_money', 'card'];
    return Row(
      children:
          methods
              .map(
                (method) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: _selectedPaymentMethod == method,
                      label: Text(
                        _paymentLabel(method),
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedPaymentMethod = method);
                      },
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  void _handleBookingCompleted() {
    widget.onBookingCompleted?.call();
    if (widget.popAfterBooking && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return _lang.t('payment.cash');
      case 'mobile_money':
        return _lang.t('payment.mobileMoney');
      case 'card':
        return _lang.t('payment.card');
      default:
        return method.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                  : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFCBD5E1),
        ),
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
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFFCBD5E1),
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
        ],
      ),
    );
  }

  Widget _buildRideTypeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideTypes = _effectiveRideTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _lang.t('book.chooseRideType'),
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                        () => setState(() {
                          _selectedRide = r['label'] as String;
                          _syncSeatsToAvailability();
                        }),
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
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.92)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isSelected
                                  ? color
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFCBD5E1)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            r['icon'] as IconData,
                            color:
                                isSelected
                                    ? color
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFF64748B)),
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _rideTypeLabel(r['label'] as String),
                            style: GoogleFonts.poppins(
                              color:
                                  isSelected
                                      ? color
                                      : (isDark
                                          ? Colors.white54
                                          : const Color(0xFF475569)),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            r['price'] as String,
                            style: GoogleFonts.poppins(
                              color:
                                  isSelected
                                      ? color
                                      : (isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _effectiveRideTypes();
    final ride = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.first,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFCBD5E1),
        ),
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
          _buildSeatSelector(),
          const SizedBox(height: 10),
          _InfoRow(
            label: _lang.t('book.rideType'),
            value: _rideTypeLabel(_selectedRide),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSeats = _availableSeatsForSelectedRide();
    final choices = List<int>.generate(maxSeats, (index) => index + 1);
    final selected = int.tryParse(_seatsController.text.trim()) ?? 1;
    final safeSelected = selected.clamp(1, maxSeats);
    if ('$safeSelected' != _seatsController.text.trim()) {
      _seatsController.text = '$safeSelected';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '${_lang.t('book.seats')} (Available: $maxSeats)',
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFCBD5E1),
            ),
          ),
          child: DropdownButton<int>(
            value: safeSelected,
            dropdownColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
            underline: const SizedBox.shrink(),
            iconEnabledColor: isDark ? Colors.white70 : const Color(0xFF475569),
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            items:
                choices
                    .map(
                      (seat) => DropdownMenuItem<int>(
                        value: seat,
                        child: Text('$seat'),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _seatsController.text = '$value');
            },
          ),
        ),
      ],
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

  int _availableSeatsForSelectedRide() {
    final options = _effectiveRideTypes();
    final selected = options.firstWhere(
      (r) => r['label'] == _selectedRide,
      orElse: () => options.isNotEmpty ? options.first : <String, dynamic>{},
    );
    final value = _readNumeric(selected['available_seats']) ?? 8;
    if (value <= 0) return 1;
    if (value > 8) return 8;
    return value;
  }

  void _syncSeatsToAvailability() {
    final current = int.tryParse(_seatsController.text.trim()) ?? 1;
    final maxSeats = _availableSeatsForSelectedRide();
    final safe = current.clamp(1, maxSeats);
    _seatsController.text = '$safe';
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

  String _rideTypeLabel(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('premium')) return _lang.t('rideType.premium');
    if (lower.contains('bike')) return _lang.t('rideType.bike');
    return _lang.t('rideType.economy');
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;

  const _LocationField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
