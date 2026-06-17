import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pickup_location_page.dart';

/// Transport Selection Screen - Choose trip type (motorcycle, private car, public bus)
class TransportSelectionPage extends StatefulWidget {
  const TransportSelectionPage({super.key});

  @override
  State<TransportSelectionPage> createState() => _TransportSelectionPageState();
}

class _TransportSelectionPageState extends State<TransportSelectionPage>
    with SingleTickerProviderStateMixin {
  String? _selectedTransport;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTransportSelected(String transportType) {
    setState(() {
      _selectedTransport = transportType;
    });

    // Navigate to pickup location page
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PickupLocationPage(transportType: transportType),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Transport Type',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF4C57D6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF4C57D6),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your ride type',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the transport option that best suits your needs',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Transport Options
          Expanded(
            child: FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(_animController),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TransportCard(
                    icon: Icons.two_wheeler,
                    title: 'Motorcycle',
                    subtitle: 'Fast & affordable',
                    description: 'Perfect for solo riders',
                    estimatedCost: '₦800-1,200',
                    onTap: () => _handleTransportSelected('MOTORCYCLE'),
                    isSelected: _selectedTransport == 'MOTORCYCLE',
                  ),
                  const SizedBox(height: 12),
                  _TransportCard(
                    icon: Icons.directions_car,
                    title: 'Private Car',
                    subtitle: 'Comfortable & private',
                    description: 'For you and your companions',
                    estimatedCost: '₦2,000-5,000',
                    onTap: () => _handleTransportSelected('PRIVATE_CAR'),
                    isSelected: _selectedTransport == 'PRIVATE_CAR',
                  ),
                  const SizedBox(height: 12),
                  _TransportCard(
                    icon: Icons.directions_bus,
                    title: 'Public Bus',
                    subtitle: 'Budget-friendly',
                    description: 'Shared rides with other passengers',
                    estimatedCost: '₦300-800',
                    onTap: () => _handleTransportSelected('PUBLIC_BUS'),
                    isSelected: _selectedTransport == 'PUBLIC_BUS',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String estimatedCost;
  final VoidCallback onTap;
  final bool isSelected;

  const _TransportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.estimatedCost,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF4C57D6) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected
                  ? const Color(0xFF4C57D6).withOpacity(0.05)
                  : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF4C57D6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: const Color(0xFF4C57D6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4C57D6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  estimatedCost,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4C57D6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
