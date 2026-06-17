import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'route_summary_page.dart';

/// Destination Location Selection Page
class DestinationLocationPage extends StatefulWidget {
  final String transportType;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;

  const DestinationLocationPage({
    super.key,
    required this.transportType,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
  });

  @override
  State<DestinationLocationPage> createState() =>
      _DestinationLocationPageState();
}

class _DestinationLocationPageState extends State<DestinationLocationPage> {
  late TextEditingController _searchController;
  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;
  bool _isSearching = false;

  final List<String> _suggestedDestinations = [
    'Lekki Market, Lagos',
    'Ikoyi Club, Lagos',
    'Abule Egba, Lagos',
    'Unilag, Lagos',
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

  void _handleLocationSelected(String address) {
    setState(() {
      _selectedAddress = address;
      _searchController.text = address;
    });
  }

  void _proceedToRouteSummary() {
    if (_selectedAddress == null ||
        _selectedLat == null ||
        _selectedLng == null) {
      _showErrorSnackbar('Please select a destination');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RouteSummaryPage(
              transportType: widget.transportType,
              pickupAddress: widget.pickupAddress,
              pickupLat: widget.pickupLat,
              pickupLng: widget.pickupLng,
              destinationAddress: _selectedAddress!,
              destinationLat: _selectedLat!,
              destinationLng: _selectedLng!,
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
          'Destination',
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
                hintText: 'Search destination...',
                prefixIcon: const Icon(Icons.location_on),
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
                    'Popular Destinations',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._suggestedDestinations.map(
                    (destination) => _LocationTile(
                      address: destination,
                      icon: Icons.directions,
                      onTap: () {
                        _handleLocationSelected(destination);
                        // Simulate coordinates
                        setState(() {
                          _selectedLat =
                              6.5244 + (destination.hashCode % 100) / 10000;
                          _selectedLng =
                              3.3792 + (destination.hashCode % 100) / 10000;
                        });
                      },
                    ),
                  ),
                ] else ...[
                  _LocationTile(
                    address: _searchController.text,
                    icon: Icons.location_on,
                    onTap: () {
                      _handleLocationSelected(_searchController.text);
                      setState(() {
                        _selectedLat = 6.5244;
                        _selectedLng = 3.3792;
                      });
                    },
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
                onPressed: _proceedToRouteSummary,
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
