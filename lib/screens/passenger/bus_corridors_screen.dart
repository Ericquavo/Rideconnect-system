import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class BusCorridorsScreen extends StatefulWidget {
  const BusCorridorsScreen({super.key});

  @override
  State<BusCorridorsScreen> createState() => _BusCorridorsScreenState();
}

class _BusCorridorsScreenState extends State<BusCorridorsScreen> {
  List<Map<String, dynamic>> _corridors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCorridors();
  }

  Future<void> _fetchCorridors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final corridors = await PassengerApi.instance.getPublicBusCorridors();
      if (mounted) {
        setState(() {
          _corridors = corridors;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bus Corridors',
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
                          ElevatedButton(onPressed: _fetchCorridors, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _corridors.isEmpty
                      ? Center(
                          child: Text('No corridors found', style: GoogleFonts.poppins(color: textPrimary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _corridors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = _corridors[index];
                            final id = item['id'] ?? item['corridor_id'] ?? 0;
                            final name = item['name'] ?? 'Unnamed Corridor';
                            final origin = item['origin'] ?? '';
                            final destination = item['destination'] ?? '';
                            final fare = item['fare'] ?? 0;

                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/bus/corridors/$id/stops',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.bus_alert_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$origin → $destination',
                                            style: GoogleFonts.poppins(
                                              color: textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Fare: $fare RWF',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF10B981),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: textSecondary.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
