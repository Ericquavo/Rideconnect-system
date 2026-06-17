import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class BusStopsScreen extends StatefulWidget {
  final int corridorId;

  const BusStopsScreen({super.key, required this.corridorId});

  @override
  State<BusStopsScreen> createState() => _BusStopsScreenState();
}

class _BusStopsScreenState extends State<BusStopsScreen> {
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedBoardingId;
  int? _selectedDestinationId;

  @override
  void initState() {
    super.initState();
    _fetchStops();
  }

  Future<void> _fetchStops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stops = await PassengerApi.instance.getPublicBusStops(widget.corridorId);
      if (mounted) {
        setState(() {
          _stops = stops;
          _isLoading = false;
          if (stops.isNotEmpty) {
            _selectedBoardingId = stops.first['id'] ?? stops.first['stop_id'];
          }
          if (stops.length > 1) {
            _selectedDestinationId = stops[1]['id'] ?? stops[1]['stop_id'];
          }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Stops',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFEF4444)),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchStops,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Choose Boarding & Destination',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Specify your travel range along the corridor stops.',
                            style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),

                          // Boarding Stop Dropdown
                          Text(
                            'Boarding Stop',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedBoardingId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _stops.map((stop) {
                              final id = stop['id'] ?? stop['stop_id'] as int;
                              final name = stop['name'] ?? stop['stop_name'] ?? 'Unnamed Stop';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(name, style: GoogleFonts.poppins(color: textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedBoardingId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Destination Stop Dropdown
                          Text(
                            'Destination Stop',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedDestinationId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _stops.map((stop) {
                              final id = stop['id'] ?? stop['stop_id'] as int;
                              final name = stop['name'] ?? stop['stop_name'] ?? 'Unnamed Stop';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(name, style: GoogleFonts.poppins(color: textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDestinationId = val;
                              });
                            },
                          ),
                          const Spacer(),

                          ElevatedButton.icon(
                            onPressed: (_selectedBoardingId != null &&
                                    _selectedDestinationId != null &&
                                    _selectedBoardingId != _selectedDestinationId)
                                ? () {
                                    Navigator.pushNamed(
                                      context,
                                      '/bus/corridors/${widget.corridorId}/buses',
                                      arguments: {
                                        'boarding_stop_id': _selectedBoardingId,
                                        'destination_stop_id': _selectedDestinationId,
                                      },
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('View Active Buses'),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
