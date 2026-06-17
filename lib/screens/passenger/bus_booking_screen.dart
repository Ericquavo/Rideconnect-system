import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class BusBookingScreen extends StatefulWidget {
  final int? corridorId;
  final int? boardingStopId;
  final int? destinationStopId;
  final int? busAssignmentId;

  const BusBookingScreen({
    super.key,
    this.corridorId,
    this.boardingStopId,
    this.destinationStopId,
    this.busAssignmentId,
  });

  @override
  State<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends State<BusBookingScreen> {
  int _seats = 1;
  bool _isBooking = false;
  String? _error;

  Future<void> _bookSeat() async {
    final seats = _seats;
    final corridorId = widget.corridorId;
    final boardingId = widget.boardingStopId;
    final destinationId = widget.destinationStopId;

    if (corridorId == null || boardingId == null || destinationId == null) {
      setState(() {
        _error = 'Missing corridor or stop selections.';
      });
      return;
    }

    setState(() {
      _isBooking = true;
      _error = null;
    });

    try {
      final result = await PassengerApi.instance.bookPublicBusSeat(
        corridorId: corridorId,
        boardingStopId: boardingId,
        destinationStopId: destinationId,
        seatsReserved: seats,
        busRouteAssignmentId: widget.busAssignmentId,
      );

      if (mounted) {
        final bookingData = result['data'] ?? result;
        final ticket = bookingData['ticket'];
        final ticketId = ticket?['id'] ?? ticket?['ticket_code'] ?? '1';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seat booked successfully!')),
        );

        Navigator.pushReplacementNamed(
          context,
          '/bus/ticket/$ticketId',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isBooking = false;
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
          'Confirm Booking',
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Details',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildDetailRow('Corridor ID', '${widget.corridorId ?? "N/A"}', textPrimary, textSecondary),
                      const SizedBox(height: 10),
                      _buildDetailRow('Boarding Stop ID', '${widget.boardingStopId ?? "N/A"}', textPrimary, textSecondary),
                      const SizedBox(height: 10),
                      _buildDetailRow('Alighting Stop ID', '${widget.destinationStopId ?? "N/A"}', textPrimary, textSecondary),
                      if (widget.busAssignmentId != null) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow('Bus Assignment ID', '${widget.busAssignmentId}', textPrimary, textSecondary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Number of Seats',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _seats > 1
                            ? () => setState(() => _seats--)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                        color: textPrimary,
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      Text(
                        '$_seats',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: _seats < 10
                            ? () => setState(() => _seats++)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        color: textPrimary,
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  onPressed: _isBooking ? null : _bookSeat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isBooking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Confirm & Book',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color fg, Color sg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: sg, fontSize: 13)),
        Text(value, style: GoogleFonts.poppins(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
