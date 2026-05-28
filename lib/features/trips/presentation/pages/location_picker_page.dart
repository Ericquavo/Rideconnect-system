import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result returned from location picker
class LocationPickerResult {
  const LocationPickerResult({required this.latlng, required this.address});

  final LatLng latlng;
  final String address;
}

/// Interactive map-based location picker
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLocation,
    this.title = 'Select Location',
  });

  final LatLng? initialLocation;
  final String title;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _loadingAddress = false;
  final _searchController = TextEditingController();
  List<Location> _searchLocations = [];
  Map<String, String> _locationNames = {};

  // Rwanda geographic boundaries
  static const double _rwandaNorthLat = -1.04;
  static const double _rwandaSouthLat = -2.84;
  static const double _rwandaWestLng = 28.84;
  static const double _rwandaEastLng = 30.90;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _updateAddress(_selectedLocation!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool _isWithinRwanda(LatLng location) {
    return location.latitude >= _rwandaSouthLat &&
        location.latitude <= _rwandaNorthLat &&
        location.longitude >= _rwandaWestLng &&
        location.longitude <= _rwandaEastLng;
  }

  Future<void> _updateAddress(LatLng location) async {
    setState(() {
      _loadingAddress = true;
      _selectedLocation = location;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Build address with priority: name > street > locality
        List<String> addressParts = [];

        if (p.name != null && p.name!.isNotEmpty) {
          addressParts.add(p.name!);
        }
        if (p.street != null && p.street!.isNotEmpty && p.street != p.name) {
          addressParts.add(p.street!);
        }
        if (p.locality != null && p.locality!.isNotEmpty) {
          addressParts.add(p.locality!);
        }
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
          addressParts.add(p.administrativeArea!);
        }

        final address = addressParts.join(', ');
        setState(
          () =>
              _selectedAddress =
                  address.isEmpty
                      ? '${location.latitude}, ${location.longitude}'
                      : address,
        );
      }
    } catch (e) {
      setState(
        () => _selectedAddress = '${location.latitude}, ${location.longitude}',
      );
    } finally {
      setState(() => _loadingAddress = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchLocations = [];
        _locationNames = {};
      });
      return;
    }

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        // Filter locations to only Rwanda
        final rwandaLocations =
            locations
                .where(
                  (loc) => _isWithinRwanda(LatLng(loc.latitude, loc.longitude)),
                )
                .toList();

        if (rwandaLocations.isEmpty) {
          setState(() {
            _searchLocations = [];
            _locationNames = {};
          });
          return;
        }

        // Get place names for each location
        Map<String, String> names = {};
        for (var loc in rwandaLocations) {
          try {
            final placemarks = await placemarkFromCoordinates(
              loc.latitude,
              loc.longitude,
            );
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              List<String> addressParts = [];
              if (p.name != null && p.name!.isNotEmpty) {
                addressParts.add(p.name!);
              }
              if (p.street != null &&
                  p.street!.isNotEmpty &&
                  p.street != p.name) {
                addressParts.add(p.street!);
              }
              if (p.locality != null && p.locality!.isNotEmpty) {
                addressParts.add(p.locality!);
              }
              final key = '${loc.latitude},${loc.longitude}';
              names[key] = addressParts.join(', ');
            }
          } catch (_) {
            final key = '${loc.latitude},${loc.longitude}';
            names[key] = key;
          }
        }
        setState(() {
          _searchLocations = rwandaLocations;
          _locationNames = names;
        });
      }
    } catch (e) {
      setState(() {
        _searchLocations = [];
        _locationNames = {};
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final location = LatLng(position.latitude, position.longitude);

    if (!_isWithinRwanda(location)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your location is outside Rwanda')),
      );
      return;
    }

    await _updateAddress(location);
    await _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(location, 16),
    );
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }

    Navigator.of(context).pop(
      LocationPickerResult(
        latlng: _selectedLocation!,
        address:
            _selectedAddress.isEmpty
                ? 'Lat: ${_selectedLocation!.latitude}, Lng: ${_selectedLocation!.longitude}'
                : _selectedAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), elevation: 0),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(-1.9536, 29.8739),
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng position) {
              if (!_isWithinRwanda(position)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a location within Rwanda'),
                  ),
                );
                return;
              }
              _updateAddress(position);
            },
            markers:
                _selectedLocation != null
                    ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                        infoWindow: InfoWindow(
                          title: 'Selected Location',
                          snippet: _selectedAddress,
                        ),
                      ),
                    }
                    : {},
          ),

          // Search & Controls Panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search location',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchLocations = [];
                                        _locationNames = {};
                                      });
                                    },
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: _searchLocation,
                      ),
                      if (_searchLocations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _searchLocations.length,
                            itemBuilder: (context, index) {
                              final location = _searchLocations[index];
                              final key =
                                  '${location.latitude},${location.longitude}';
                              final placeName = _locationNames[key] ?? key;

                              return ListTile(
                                dense: true,
                                title: Text(placeName),
                                onTap: () {
                                  final selectedLoc = LatLng(
                                    location.latitude,
                                    location.longitude,
                                  );
                                  _updateAddress(selectedLoc);
                                  _mapController.animateCamera(
                                    CameraUpdate.newLatLngZoom(selectedLoc, 16),
                                  );
                                  _searchController.clear();
                                  setState(() {
                                    _searchLocations = [];
                                    _locationNames = {};
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadingAddress)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 20,
                            child: LinearProgressIndicator(),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedAddress.isEmpty
                                    ? 'Tap map or search to select'
                                    : _selectedAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Current Location'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _confirmLocation,
                              icon: const Icon(Icons.check),
                              label: const Text('Confirm'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
