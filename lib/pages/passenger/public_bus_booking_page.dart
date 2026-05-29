import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/passenger_api.dart';
import '../../services/passenger_language_service.dart';
import 'public_bus_models.dart';
import 'widgets/public_bus_card.dart';

class PublicBusBookingPage extends StatefulWidget {
  const PublicBusBookingPage({super.key});

  @override
  State<PublicBusBookingPage> createState() => _PublicBusBookingPageState();
}

class _PublicBusBookingPageState extends State<PublicBusBookingPage> {
  static const LatLng _fallbackCenter = LatLng(-1.9441, 30.0619);

  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  final TextEditingController _seatsController = TextEditingController(
    text: '1',
  );

  GoogleMapController? _mapController;

  List<Map<String, dynamic>> _corridors = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _boardingStops = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _destinationStops = <Map<String, dynamic>>[];
  List<PublicBusAssignment> _activeBuses = <PublicBusAssignment>[];

  bool _loading = true;
  bool _loadingBuses = false;
  bool _booking = false;
  bool _locationDenied = false;
  String? _error;

  int? _selectedCorridorId;
  int? _selectedBoardingStopId;
  int? _selectedDestinationStopId;
  LatLng? _deviceLocation;
  PublicBusAssignment? _selectedBus;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    unawaited(_initializePage());
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _mapController?.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  int? _readId(Map<String, dynamic> item) {
    final value =
        item['id'] ??
        item['corridor_id'] ??
        item['public_bus_corridor_id'] ??
        item['route_corridor_id'] ??
        item['stop_id'] ??
        item['bus_stop_id'] ??
        item['public_bus_stop_id'] ??
        item['value'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _readLabel(Map<String, dynamic> item) {
    final raw =
        item['name'] ??
        item['label'] ??
        item['title'] ??
        item['stop_name'] ??
        item['stopName'] ??
        item['corridor_name'] ??
        item['corridorName'] ??
        item['display_name'] ??
        item['code'];
    final text = raw?.toString().trim() ?? '';
    return text.isNotEmpty ? text : 'Unnamed';
  }

  List<Map<String, dynamic>> _dropdownItems(List<Map<String, dynamic>> items) {
    final seenIds = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = _readId(item);
      if (id == null || seenIds.contains(id)) continue;
      seenIds.add(id);
      result.add(item);
    }
    return result;
  }

  int? _dropdownValue(int? value, List<Map<String, dynamic>> items) {
    if (value == null) return null;
    for (final item in items) {
      if (_readId(item) == value) return value;
    }
    return null;
  }

  int? _firstOtherStop(int stopId) {
    for (final stop in _boardingStops) {
      final id = _readId(stop);
      if (id != null && id != stopId) return id;
    }
    return null;
  }

  int _stopIndexInCorridor(int stopId) {
    for (var i = 0; i < _boardingStops.length; i++) {
      if (_readId(_boardingStops[i]) == stopId) return i;
    }
    return -1;
  }

  ({int boarding, int destination}) _normalizeStopOrder(
    int boardingStopId,
    int destinationStopId,
  ) {
    final boardingIndex = _stopIndexInCorridor(boardingStopId);
    final destinationIndex = _stopIndexInCorridor(destinationStopId);
    if (boardingIndex > destinationIndex) {
      return (boarding: destinationStopId, destination: boardingStopId);
    }
    return (boarding: boardingStopId, destination: destinationStopId);
  }

  bool _isValidBoardingDestinationPair() {
    final boardingStopId = _selectedBoardingStopId;
    final destinationStopId = _selectedDestinationStopId;
    if (boardingStopId == null || destinationStopId == null) return false;
    return boardingStopId != destinationStopId;
  }

  Future<void> _initializePage() async {
    await Future.wait([_loadLocation(), _loadCorridors()]);
  }

  Future<void> _loadLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationDenied = true;
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
          _locationDenied = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      if (!mounted) return;
      setState(() {
        _deviceLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationDenied = true;
      });
    }
  }

  Future<void> _loadCorridors() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final corridors = await PassengerApi.instance.getPublicBusCorridors();
      if (!mounted) return;
      setState(() {
        _corridors = corridors;
        _selectedCorridorId =
            corridors.isNotEmpty ? _readId(corridors.first) : null;
      });

      if (_selectedCorridorId != null) {
        await _loadStopsAndBuses(_selectedCorridorId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadStopsAndBuses(int corridorId) async {
    setState(() {
      _loadingBuses = true;
      _error = null;
      _boardingStops = <Map<String, dynamic>>[];
      _destinationStops = <Map<String, dynamic>>[];
      _activeBuses = <PublicBusAssignment>[];
      _selectedBus = null;
    });

    try {
      final stops = await PassengerApi.instance.getPublicBusStops(corridorId);
      if (!mounted) return;

      setState(() {
        _boardingStops = stops;
        _destinationStops = stops;
        _selectedBoardingStopId =
            stops.isNotEmpty ? _readId(stops.first) : null;
        _selectedDestinationStopId =
            stops.length > 1 ? _readId(stops[1]) : _selectedBoardingStopId;
      });
      await _reloadActiveBuses();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loadingBuses = false);
      }
    }
  }

  Future<void> _reloadActiveBuses() async {
    final corridorId = _selectedCorridorId;
    if (corridorId == null) return;

    setState(() => _loadingBuses = true);
    try {
      final buses = await PassengerApi.instance.getPublicBusActiveBuses(
        corridorId,
        boardingStopId: _selectedBoardingStopId,
        destinationStopId: _selectedDestinationStopId,
      );
      final assignments = buses.map(PublicBusAssignment.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _activeBuses = assignments;
        if (_selectedBus != null) {
          _selectedBus = _findBusById(assignments, _selectedBus!.assignmentId);
        }
      });

      _moveCameraToSelectedOrFallback();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loadingBuses = false);
      }
    }
  }

  PublicBusAssignment? _findBusById(
    List<PublicBusAssignment> buses,
    int assignmentId,
  ) {
    for (final bus in buses) {
      if (bus.assignmentId == assignmentId) return bus;
    }
    return null;
  }

  Future<void> _bookSeat({bool allowWithoutSelectedBus = false}) async {
    final corridorId = _selectedCorridorId;
    final boardingStopId = _selectedBoardingStopId;
    final destinationStopId = _selectedDestinationStopId;
    final seats = int.tryParse(_seatsController.text.trim()) ?? 1;

    if (corridorId == null ||
        boardingStopId == null ||
        destinationStopId == null) {
      _showSnack(_lang.t('bus.selectRequired'));
      return;
    }
    if (!_isValidBoardingDestinationPair()) {
      _showSnack('Please select a different boarding and destination stop.');
      return;
    }
    if (seats < 1) {
      _showSnack(_lang.t('bus.minSeats'));
      return;
    }

    setState(() => _booking = true);
    try {
      final normalizedStops = _normalizeStopOrder(
        boardingStopId,
        destinationStopId,
      );
      final result = await PassengerApi.instance.bookPublicBusSeat(
        corridorId: corridorId,
        boardingStopId: normalizedStops.boarding,
        destinationStopId: normalizedStops.destination,
        seatsReserved: seats,
        busRouteAssignmentId:
            allowWithoutSelectedBus ? null : _selectedBus?.assignmentId,
      );

      if (!mounted) return;
      final message =
          (result['message'] ?? 'Bus seat booked successfully.').toString();
      _showSnack(message);
      Navigator.of(context).pop(result);
    } on PassengerApiException catch (e) {
      if (!mounted) return;
      if (e.isValidationError &&
          (e.errorCode == 'BUS_SELECTION_INVALID' ||
              e.errorCode == 'INSUFFICIENT_BUS_CAPACITY' ||
              e.errorCode == 'NO_BOOKABLE_BUS')) {
        unawaited(_reloadActiveBuses());
        await _showBusBookingErrorDialog(e.errorCode);
      } else if (e.isForbidden &&
          (e.errorCode == 'PASSENGER_NOT_APPROVED' ||
              e.errorCode == 'PASSENGER_ONLY' ||
              e.errorCode == 'BUS_BOOKING_FORBIDDEN')) {
        await _showBusBookingErrorDialog(e.errorCode);
      } else {
        _showSnack(_friendlyError(e));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _showBusBookingErrorDialog(String? errorCode) async {
    final title = publicBusErrorTitle(errorCode);
    final message = publicBusErrorMessage(errorCode);
    final needsSupport = errorCode == 'PASSENGER_NOT_APPROVED';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (needsSupport)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_contactSupport());
                },
                child: const Text('Contact Support'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_reloadActiveBuses());
              },
              child: const Text('Retry'),
            ),
            if (errorCode == 'BUS_SELECTION_INVALID' ||
                errorCode == 'INSUFFICIENT_BUS_CAPACITY')
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  setState(() => _selectedBus = null);
                },
                child: Text(_lang.t('bus.chooseAnother')),
              ),
          ],
        );
      },
    );
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@rideconnect.app',
      queryParameters: const <String, String>{
        'subject': 'Passenger approval help',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnack('Contact support at support@rideconnect.app');
    }
  }

  void _selectBus(PublicBusAssignment assignment) {
    setState(() => _selectedBus = assignment);
    _moveCameraToAssignment(assignment);
  }

  void _moveCameraToAssignment(PublicBusAssignment assignment) {
    final point = assignment.mapPoint;
    if (point == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 14.4)),
    );
  }

  void _moveCameraToSelectedOrFallback() {
    final target =
        _selectedBus?.mapPoint ??
        _deviceLocation ??
        _firstBusPoint() ??
        _fallbackCenter;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 13.8),
      ),
    );
  }

  LatLng? _firstBusPoint() {
    for (final bus in _activeBuses) {
      final point = bus.mapPoint;
      if (point != null) return point;
    }
    return null;
  }

  Set<Marker> _buildMarkers() {
    return _activeBuses
        .where((bus) => bus.mapPoint != null)
        .map(
          (bus) => Marker(
            markerId: MarkerId('bus-${bus.assignmentId}'),
            position: bus.mapPoint!,
            infoWindow: InfoWindow(
              title: bus.title,
              snippet: bus.driverSummary,
            ),
            icon:
                bus.assignmentId == _selectedBus?.assignmentId
                    ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    )
                    : BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
            onTap: () => _openBusDetails(bus),
          ),
        )
        .toSet();
  }

  Future<void> _openBusDetails(PublicBusAssignment assignment) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicBusCard(
                  assignment: assignment,
                  selected:
                      assignment.assignmentId == _selectedBus?.assignmentId,
                  selectLabel: _lang.t('bus.selectBus'),
                  selectedLabel: _lang.t('bus.selectedBus'),
                  onSelect: () {
                    Navigator.of(sheetContext).pop();
                    _selectBus(assignment);
                  },
                  onDetails: () {},
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _selectBus(assignment);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_lang.t('bus.selectBus')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _friendlyError(Object error) {
    if (error is PassengerApiException) {
      if (error.errorCode != null && error.errorCode!.isNotEmpty) {
        return publicBusErrorMessage(error.errorCode);
      }
      if (error.isForbidden) {
        return 'You are not allowed to book a bus seat.';
      }
      if (error.isValidationError) {
        return 'We could not book this bus seat. Please check your selection and try again.';
      }
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  LatLng _mapTarget() {
    return _selectedBus?.mapPoint ??
        _deviceLocation ??
        _firstBusPoint() ??
        _fallbackCenter;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF11162A) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: Text(_lang.t('bus.activeBuses'))),
      body: Container(
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
        child: RefreshIndicator(
          onRefresh: _loadCorridors,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _lang.t('bus.activeBuses'),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _lang.t('home.publicDesc'),
                style: GoogleFonts.poppins(color: textSecondary),
              ),
              if (_locationDenied) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _lang.t('bus.locationDisabled'),
                    style: GoogleFonts.poppins(
                      color:
                          isDark
                              ? Colors.amber.shade200
                              : const Color(0xFF92400E),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.poppins(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              _buildDropdown(
                label: _lang.t('bus.corridor'),
                value: _selectedCorridorId,
                items: _corridors,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCorridorId = value);
                  unawaited(_loadStopsAndBuses(value));
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: _lang.t('bus.boardingStop'),
                      value: _selectedBoardingStopId,
                      items: _boardingStops,
                      onChanged: (value) {
                        setState(() {
                          _selectedBoardingStopId = value;
                          if (value != null &&
                              value == _selectedDestinationStopId) {
                            _selectedDestinationStopId =
                                _firstOtherStop(value) ??
                                _selectedDestinationStopId;
                          }
                        });
                        unawaited(_reloadActiveBuses());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: _lang.t('bus.destinationStop'),
                      value: _selectedDestinationStopId,
                      items: _destinationStops,
                      onChanged: (value) {
                        setState(() {
                          _selectedDestinationStopId = value;
                          if (value != null &&
                              value == _selectedBoardingStopId) {
                            _selectedBoardingStopId =
                                _firstOtherStop(value) ??
                                _selectedBoardingStopId;
                          }
                        });
                        unawaited(_reloadActiveBuses());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child:
                      _activeBuses.isEmpty && !_loadingBuses
                          ? Container(
                            color: cardBg,
                            child: Center(
                              child: Text(
                                _lang.t('bus.noActiveBuses'),
                                style: GoogleFonts.poppins(
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          )
                          : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _mapTarget(),
                              zoom: 13.8,
                            ),
                            myLocationEnabled: _deviceLocation != null,
                            myLocationButtonEnabled: _deviceLocation != null,
                            zoomControlsEnabled: true,
                            compassEnabled: true,
                            mapToolbarEnabled: false,
                            markers: _buildMarkers(),
                            onMapCreated: (controller) {
                              _mapController = controller;
                              controller.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: _mapTarget(),
                                    zoom: 13.8,
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedBus != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lang.t('bus.bookingSummary'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PublicBusCard(
                        assignment: _selectedBus!,
                        selected: true,
                        selectLabel: _lang.t('bus.selectBus'),
                        selectedLabel: _lang.t('bus.selectedBus'),
                        onSelect: () {},
                        onDetails: () => _openBusDetails(_selectedBus!),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _lang.t('bus.seatsReserved'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cardBg,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _booking ? null : _bookSeat,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon:
                    _booking
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.event_seat_rounded),
                label: Text(_lang.t('bus.bookNow')),
              ),
              const SizedBox(height: 14),
              Text(
                _lang.t('bus.activeBuses'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingBuses)
                const Center(child: CircularProgressIndicator())
              else if (_activeBuses.isEmpty)
                Text(
                  _lang.t('bus.noActiveBuses'),
                  style: GoogleFonts.poppins(color: textSecondary),
                )
              else
                ..._activeBuses.map(
                  (bus) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PublicBusCard(
                      assignment: bus,
                      selected: bus.assignmentId == _selectedBus?.assignmentId,
                      selectLabel: _lang.t('bus.selectBus'),
                      selectedLabel: _lang.t('bus.selectedBus'),
                      onSelect: () => _selectBus(bus),
                      onDetails: () => _openBusDetails(bus),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    final dropdownItems = _dropdownItems(items);
    final effectiveValue = _dropdownValue(value, dropdownItems);

    return DropdownButtonFormField<int>(
      value: effectiveValue,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        fillColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF11162A)
                : Colors.white,
      ),
      items:
          dropdownItems
              .map(
                (item) => DropdownMenuItem<int>(
                  value: _readId(item)!,
                  child: Text(
                    _readLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      selectedItemBuilder:
          (context) =>
              dropdownItems
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _readLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
      onChanged: dropdownItems.isEmpty ? null : onChanged,
    );
  }
}
