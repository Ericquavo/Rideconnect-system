import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class BusTicketScreen extends StatefulWidget {
  final String ticketId;

  const BusTicketScreen({super.key, required this.ticketId});

  @override
  State<BusTicketScreen> createState() => _BusTicketScreenState();
}

class _BusTicketScreenState extends State<BusTicketScreen> {
  Map<String, dynamic>? _ticketData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTicket();
  }

  Future<void> _fetchTicket() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await PassengerApi.instance.getPublicBusTicket(widget.ticketId.toString());
      if (mounted) {
        setState(() {
          _ticketData = data['data'] ?? data;
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

    final ticketCode = _ticketData?['ticket_code'] ?? 'BUS-2026-${widget.ticketId}';
    final seats = _ticketData?['seats_booked'] ?? _ticketData?['seats'] ?? 1;
    final status = _ticketData?['status'] ?? 'Confirmed';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bus Ticket',
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
                          ElevatedButton(onPressed: _fetchTicket, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ticket Code',
                                style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                              ),
                              Text(
                                ticketCode,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // QR Code Placeholder
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                ),
                                child: const Center(
                                  child: Icon(Icons.qr_code_2_rounded, size: 120, color: Color(0xFF4C57D6)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildTicketField('Seats Booked', '$seats', textPrimary, textSecondary),
                              const SizedBox(height: 12),
                              _buildTicketField('Boarding Time', 'June 16, 2026 - 08:00 AM', textPrimary, textSecondary),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.popUntil(context, (route) => route.isFirst);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4C57D6),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.home_rounded, color: Colors.white),
                                label: Text(
                                  'Back to Home',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildTicketField(String label, String value, Color fg, Color sg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: sg, fontSize: 13)),
        Text(value, style: GoogleFonts.poppins(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
