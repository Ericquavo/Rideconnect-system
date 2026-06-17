import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/passenger_api.dart';
import '../../pages/passenger/public_bus_models.dart';

class ActiveBusesScreen extends StatefulWidget {
  final int corridorId;
  final int? boardingStopId;
  final int? destinationStopId;

  const ActiveBusesScreen({
    super.key,
    required this.corridorId,
    this.boardingStopId,
    this.destinationStopId,
  });

  @override
  State<ActiveBusesScreen> createState() => _ActiveBusesScreenState();
}

class _ActiveBusesScreenState extends State<ActiveBusesScreen> {
  GoogleMapController? _mapController;
  List<PublicBusAssignment> _activeBuses = [];
  bool _isLoading = true;
  String? _error;
  PublicBusAssignment? _selectedBus;

  @override
  void initState() {
    super.initState();
    _fetchBuses();
  }

  Future<void> _fetchBuses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final buses = await PassengerApi.instance.getPublicBusActiveBuses(
        widget.corridorId,
        boardingStopId: widget.boardingStopId,
        destinationStopId: widget.destinationStopId,
      );
      if (mounted) {
        setState(() {
          _activeBuses = buses.map(PublicBusAssignment.fromJson).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF131729) : Colors.white;

    final markers = _activeBuses
        .where((bus) => bus.mapPoint != null)
        .map(
          (bus) => Marker(
            markerId: MarkerId('bus-${bus.assignmentId}'),
            position: bus.mapPoint!,
            infoWindow: InfoWindow(
              title: bus.title,
              snippet: bus.driverSummary,
            ),
            icon: bus.assignmentId == _selectedBus?.assignmentId
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              setState(() {
                _selectedBus = bus;
              });
            },
          ),
        )
        .toSet();

    final target = _selectedBus?.mapPoint ??
        (_activeBuses.isNotEmpty && _activeBuses.first.mapPoint != null
            ? _activeBuses.first.mapPoint!
            : const LatLng(-1.9441, 30.0619));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Active Buses',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: GoogleFonts.poppins(color: textPrimary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchBuses, child: const Text('Retry')),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: target, zoom: 13.5),
                      markers: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      onMapCreated: (c) => _mapController = c,
                    ),
                    if (_selectedBus != null)
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _selectedBus!.title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedBus!.driverSummary,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/bus/book',
                                    arguments: {
                                      'corridor_id': widget.corridorId,
                                      'boarding_stop_id': widget.boardingStopId,
                                      'destination_stop_id': widget.destinationStopId,
                                      'bus_assignment_id': _selectedBus!.assignmentId,
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Book Seat on This Bus',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_activeBuses.isEmpty)
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'No active buses found along this corridor right now.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
