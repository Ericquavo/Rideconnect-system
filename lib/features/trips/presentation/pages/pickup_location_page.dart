import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'destination_location_page.dart';

/// Pickup Location Selection Page
class PickupLocationPage extends StatefulWidget {
  final String transportType;

  const PickupLocationPage({super.key, required this.transportType});

  @override
  State<PickupLocationPage> createState() => _PickupLocationPageState();
}

class _PickupLocationPageState extends State<PickupLocationPage> {
  late TextEditingController _searchController;
  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;
  bool _isLoadingLocation = false;
  bool _isSearching = false;

  final List<String> _recentLocations = [
    'Home - Ikoyi, Lagos',
    'Office - VI, Lagos',
    'Shopping Mall - Surulere',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address =
            '${place.street}, ${place.locality}, ${place.administrativeArea}';

        setState(() {
          _selectedAddress = address;
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _searchController.text = address;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Failed to get current location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _handleLocationSelected(String address) {
    setState(() {
      _selectedAddress = address;
      _searchController.text = address;
    });
  }

  void _proceedToDestination() {
    if (_selectedAddress == null ||
        _selectedLat == null ||
        _selectedLng == null) {
      _showErrorSnackbar('Please select a location');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DestinationLocationPage(
              transportType: widget.transportType,
              pickupAddress: _selectedAddress!,
              pickupLat: _selectedLat!,
              pickupLng: _selectedLng!,
            ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pickup Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4C57D6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: const Color(0xFF4C57D6),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _isSearching = value.isNotEmpty);
              },
              decoration: InputDecoration(
                hintText: 'Search pickup location...',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon:
                    _isLoadingLocation
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFF4C57D6),
                              ),
                            ),
                          ),
                        )
                        : IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                        ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Results
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isSearching) ...[
                  Text(
                    'Recent Locations',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recentLocations.map(
                    (location) => _LocationTile(
                      address: location,
                      icon: Icons.history,
                      onTap: () => _handleLocationSelected(location),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Saved Places',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LocationTile(
                    address: 'Home',
                    icon: Icons.home,
                    onTap: () => _handleLocationSelected('Home - Ikoyi, Lagos'),
                  ),
                  const SizedBox(height: 8),
                  _LocationTile(
                    address: 'Work',
                    icon: Icons.work,
                    onTap: () => _handleLocationSelected('Office - VI, Lagos'),
                  ),
                ] else ...[
                  // Search results would go here
                  _LocationTile(
                    address: _searchController.text,
                    icon: Icons.location_on,
                    onTap:
                        () => _handleLocationSelected(_searchController.text),
                  ),
                ],
              ],
            ),
          ),
          // Next Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _proceedToDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C57D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Next',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _LocationTile extends StatelessWidget {
  final String address;
  final IconData icon;
  final VoidCallback onTap;

  const _LocationTile({
    required this.address,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4C57D6)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(address, style: GoogleFonts.poppins(fontSize: 14)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
