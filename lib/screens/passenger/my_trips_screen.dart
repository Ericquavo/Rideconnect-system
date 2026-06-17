// lib/screens/passenger/my_trips_screen.dart
// Trip history screen – lists completed, cancelled, and active trips from
// GET /api/v1/passenger/trips and GET /api/v1/passenger/rides

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

// ── Tab values ────────────────────────────────────────────────────────────────
enum _TripTab { all, completed, cancelled }

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _trips = [];
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
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchTrips();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try rides endpoint first (covers motor-vehicle trips), then trips
      List<Map<String, dynamic>> results = [];
      try {
        results = await PassengerApi.instance.getRides();
      } catch (_) {}

      if (results.isEmpty) {
        try {
          results = await PassengerApi.instance.getTrips();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _trips = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filtered(_TripTab tab) {
    if (tab == _TripTab.all) return _trips;
    final statusMatch = tab == _TripTab.completed
        ? {'COMPLETED', 'completed'}
        : {'CANCELLED', 'cancelled', 'REJECTED', 'rejected'};
    return _trips.where((t) {
      final s = (t['status'] ?? '').toString().toUpperCase();
      return statusMatch.any((m) => m.toUpperCase() == s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF),
        elevation: 0,
        title: Text(
          'My Trips',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: _textSecondary,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TripList(
                      trips: _filtered(_TripTab.all),
                      isDark: _isDark,
                      card: _card,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                    ),
                    _TripList(
                      trips: _filtered(_TripTab.completed),
                      isDark: _isDark,
                      card: _card,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                    ),
                    _TripList(
                      trips: _filtered(_TripTab.cancelled),
                      isDark: _isDark,
                      card: _card,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                    ),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 56),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchTrips,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip list widget
// ─────────────────────────────────────────────────────────────────────────────
class _TripList extends StatelessWidget {
  const _TripList({
    required this.trips,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });

  final List<Map<String, dynamic>> trips;
  final bool isDark;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 72,
              color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No trips found',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _TripCard(
          trip: trips[i],
          isDark: isDark,
          card: card,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onTap: () {
            final id = trips[i]['id'] ?? trips[i]['trip_id'];
            if (id != null) {
              Navigator.pushNamed(ctx, '/trips/$id', arguments: {'tripId': id});
            }
          },
        ),
      ),
      onRefresh: () async {},
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single trip card
// ─────────────────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final Map<String, dynamic> trip;
  final bool isDark;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED':
      case 'REJECTED':  return const Color(0xFFEF4444);
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      case 'DRIVER_ARRIVED': return const Color(0xFF8B5CF6);
      default: return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'COMPLETED':    return 'Completed';
      case 'CANCELLED':    return 'Cancelled';
      case 'REJECTED':     return 'Rejected';
      case 'IN_PROGRESS':  return 'In Progress';
      case 'DRIVER_ARRIVED': return 'Driver Arrived';
      case 'PENDING':      return 'Pending';
      case 'MATCHING':     return 'Matching';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (trip['status'] ?? 'UNKNOWN').toString();
    final pickup = trip['pickup_location']?.toString()
        ?? trip['pickup_address']?.toString()
        ?? trip['pickup']?.toString()
        ?? 'Unknown pickup';
    final dropoff = trip['dropoff_location']?.toString()
        ?? trip['dropoff_address']?.toString()
        ?? trip['dropoff']?.toString()
        ?? 'Unknown dropoff';
    final fare = trip['fare'] ?? trip['estimated_fare'] ?? trip['total_fare'];
    final createdAt = trip['created_at']?.toString() ?? '';
    final id = trip['id'] ?? trip['trip_id'] ?? '?';
    final transport = (trip['transport_type'] ?? trip['type'] ?? 'CAR').toString();

    IconData transportIcon;
    switch (transport.toUpperCase()) {
      case 'MOTORCYCLE':
        transportIcon = Icons.two_wheeler_rounded;
        break;
      case 'PUBLIC_BUS':
      case 'BUS':
        transportIcon = Icons.directions_bus_rounded;
        break;
      default:
        transportIcon = Icons.directions_car_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(transportIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip #$id',
                        style: GoogleFonts.poppins(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.poppins(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.poppins(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Route
            _RouteItem(
              icon: Icons.circle,
              iconColor: const Color(0xFF10B981),
              label: pickup,
              isDark: isDark,
              textSecondary: textSecondary,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 12,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ),
            _RouteItem(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFEF4444),
              label: dropoff,
              isDark: isDark,
              textSecondary: textSecondary,
            ),

            if (fare != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fare',
                    style: GoogleFonts.poppins(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'RWF ${_parseFare(fare).toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6C63FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],

            // View details chevron
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View details',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6C63FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF6C63FF),
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _parseFare(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
    } catch (_) {
      return raw;
    }
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
    required this.textSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
