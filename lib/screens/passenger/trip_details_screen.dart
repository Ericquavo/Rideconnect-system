// lib/screens/passenger/trip_details_screen.dart
// Detailed view of a single trip – GET /api/v1/passenger/trips/:id

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class TripDetailsScreen extends StatefulWidget {
  final int tripId;
  const TripDetailsScreen({super.key, required this.tripId});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
  Color get _card => _isDark ? const Color(0xFF141829) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? Colors.white70 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Try motor-vehicle endpoint first, then generic trips
      Map<String, dynamic> data;
      try {
        data = await PassengerApi.instance.getMotorVehicleTrip(widget.tripId);
      } catch (_) {
        data = await PassengerApi.instance.getTripById(widget.tripId);
      }
      if (!mounted) return;
      setState(() { _trip = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Trip Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: _textPrimary),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _textPrimary),
            onPressed: _loadTrip,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 56),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadTrip,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final t = _trip!;
    final status = (t['status'] ?? 'UNKNOWN').toString().toUpperCase();
    final driver = t['driver'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status card ───────────────────────────────────────────────────
          _buildStatusCard(status, t),
          const SizedBox(height: 16),

          // ── Route card ────────────────────────────────────────────────────
          _buildSectionCard(
            title: 'Route',
            icon: Icons.route_rounded,
            child: _buildRouteSection(t),
          ),
          const SizedBox(height: 12),

          // ── Driver card ───────────────────────────────────────────────────
          if (driver != null) ...[
            _buildSectionCard(
              title: 'Driver',
              icon: Icons.person_rounded,
              child: _buildDriverSection(driver),
            ),
            const SizedBox(height: 12),
          ],

          // ── Fare card ─────────────────────────────────────────────────────
          _buildSectionCard(
            title: 'Fare & Payment',
            icon: Icons.payments_rounded,
            child: _buildFareSection(t),
          ),
          const SizedBox(height: 12),

          // ── Timeline card ─────────────────────────────────────────────────
          _buildSectionCard(
            title: 'Timeline',
            icon: Icons.timeline_rounded,
            child: _buildTimelineSection(t),
          ),
          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────────────
          if (status == 'COMPLETED') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/trip/rate/${widget.tripId}',
                  arguments: {'tripId': widget.tripId},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.star_rounded, color: Colors.white),
              label: Text(
                'Rate this trip',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, Map<String, dynamic> t) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusLabel(status),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Trip #${t['id'] ?? t['trip_id'] ?? widget.tripId}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection(Map<String, dynamic> t) {
    final pickup = t['pickup_location']?.toString() ?? t['pickup_address']?.toString() ?? 'Unknown';
    final dropoff = t['dropoff_location']?.toString() ?? t['dropoff_address']?.toString() ?? 'Unknown';

    return Column(
      children: [
        _DetailRow(
          icon: Icons.circle,
          iconColor: const Color(0xFF10B981),
          label: 'Pickup',
          value: pickup,
          isDark: _isDark,
          textSecondary: _textSecondary,
          textPrimary: _textPrimary,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
          child: Container(height: 20, width: 2,
              color: _isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
        ),
        _DetailRow(
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFFEF4444),
          label: 'Dropoff',
          value: dropoff,
          isDark: _isDark,
          textSecondary: _textSecondary,
          textPrimary: _textPrimary,
        ),
        if (t['distance_km'] != null || t['distance'] != null) ...[
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.straighten_rounded,
            iconColor: const Color(0xFF6C63FF),
            label: 'Distance',
            value: '${t['distance_km'] ?? t['distance']} km',
            isDark: _isDark,
            textSecondary: _textSecondary,
            textPrimary: _textPrimary,
          ),
        ],
      ],
    );
  }

  Widget _buildDriverSection(Map<String, dynamic> d) {
    final name = d['name']?.toString() ?? d['full_name']?.toString() ?? 'Unknown';
    final rating = d['rating'] ?? d['avg_rating'];
    final plate = d['vehicle_plate']?.toString() ?? d['plate']?.toString();
    final model = d['vehicle_model']?.toString() ?? d['car_model']?.toString();

    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              if (rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 3),
                  Text('$rating',
                      style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12)),
                ]),
              if (plate != null)
                Text('$plate  ${model ?? ''}',
                    style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareSection(Map<String, dynamic> t) {
    final fare = t['fare'] ?? t['estimated_fare'] ?? t['total_fare'];
    final payment = t['payment_method']?.toString() ?? t['payment_type']?.toString() ?? 'Cash';

    return Column(
      children: [
        if (fare != null)
          _DetailRow(
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Total Fare',
            value: 'RWF ${_parseFare(fare).toStringAsFixed(0)}',
            isDark: _isDark,
            textSecondary: _textSecondary,
            textPrimary: _textPrimary,
          ),
        const SizedBox(height: 8),
        _DetailRow(
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFF3B82F6),
          label: 'Payment',
          value: payment,
          isDark: _isDark,
          textSecondary: _textSecondary,
          textPrimary: _textPrimary,
        ),
      ],
    );
  }

  Widget _buildTimelineSection(Map<String, dynamic> t) {
    final events = <Map<String, String>>[];

    void addEvent(String label, String? ts) {
      if (ts != null && ts.isNotEmpty) {
        events.add({'label': label, 'time': _formatDate(ts)});
      }
    }

    addEvent('Requested', t['created_at']?.toString());
    addEvent('Accepted', t['accepted_at']?.toString());
    addEvent('Driver Arrived', t['arrived_at']?.toString());
    addEvent('Started', t['started_at']?.toString());
    addEvent('Completed', t['completed_at']?.toString());
    addEvent('Cancelled', t['cancelled_at']?.toString());

    if (events.isEmpty) {
      return Text('No timeline data',
          style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12));
    }

    return Column(
      children: events.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.radio_button_checked_rounded,
                  color: Color(0xFF6C63FF), size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e['label']!,
                        style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13)),
                    Text(e['time']!,
                        style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFFEF4444);
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      default: return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'COMPLETED': return Icons.check_circle_rounded;
      case 'CANCELLED': return Icons.cancel_rounded;
      case 'IN_PROGRESS': return Icons.directions_car_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'COMPLETED': return 'Trip Completed';
      case 'CANCELLED': return 'Trip Cancelled';
      case 'IN_PROGRESS': return 'In Progress';
      case 'DRIVER_ARRIVED': return 'Driver Arrived';
      case 'MATCHING': return 'Matching';
      default: return s;
    }
  }

  double _parseFare(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2,'0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month-1]} ${dt.year}, $h:$m $ampm';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared detail row
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.textSecondary,
    required this.textPrimary,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color textSecondary;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(color: textSecondary, fontSize: 10)),
              Text(value,
                  style: GoogleFonts.poppins(
                    color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
