import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class TripTrackingScreen extends StatefulWidget {
  final int tripId;

  const TripTrackingScreen({super.key, required this.tripId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  Timer? _trackingTimer;
  Map<String, dynamic>? _trackData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _startTracking() {
    _fetchTrackingDetails();
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchTrackingDetails());
  }

  Future<void> _fetchTrackingDetails() async {
    try {
      final data = await PassengerApi.instance.trackTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trackData = data['data'] ?? data;
          _isLoading = false;
        });

        final trip = _trackData?['trip'];
        final status = (trip?['status'] ?? 'PENDING').toString().toUpperCase();

        if (status == 'COMPLETED') {
          _trackingTimer?.cancel();
          Navigator.pushReplacementNamed(
            context,
            '/trip/rate/${widget.tripId}',
          );
        } else if (status == 'CANCELLED') {
          _trackingTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip was cancelled.')),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
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

  Future<void> _cancelTrip() async {
    try {
      await PassengerApi.instance.cancelTrip(widget.tripId);
      if (mounted) {
        _trackingTimer?.cancel();
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF131729) : Colors.white;

    final trip = _trackData?['trip'];
    final driver = _trackData?['driver'];
    final eta = _trackData?['eta_minutes'] ?? 'Calculating...';
    final status = (trip?['status'] ?? 'PENDING').toString().toUpperCase();
    final fare = trip?['fare'] ?? 'Calculating...';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track Trip',
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
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Flow Chip Timeline
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Trip Status', style: GoogleFonts.poppins(color: textSecondary, fontSize: 13)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF6C63FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildTimeline(status),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Driver Details Card
                      if (driver != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Color(0xFF6C63FF),
                                    child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver['name'] ?? 'Driver Assigned',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text(
                                          driver['phone'] ?? 'No phone provided',
                                          style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildMetaRow('Vehicle', '${driver['vehicle']?['color'] ?? ""} ${driver['vehicle']?['type'] ?? ""}', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildMetaRow('Plate Number', '${driver['vehicle']?['plate'] ?? "N/A"}', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildMetaRow('ETA', '$eta mins', textPrimary, textSecondary),
                              const SizedBox(height: 8),
                              _buildMetaRow('Estimated Fare', '$fare RWF', textPrimary, textSecondary),
                            ],
                          ),
                        ),
                      const Spacer(),

                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/trip/map/${widget.tripId}',
                            arguments: _trackData,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.map_rounded, color: Colors.white),
                        label: Text(
                          'Open Live Map',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (status == 'PENDING' || status == 'MATCHED' || status == 'ACCEPTED')
                        OutlinedButton(
                          onPressed: _cancelTrip,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Cancel Trip',
                            style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, Color fg, Color sg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: sg, fontSize: 12)),
        Text(value, style: GoogleFonts.poppins(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeline(String currentStatus) {
    final stages = ['PENDING', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED'];
    final activeIndex = stages.indexOf(currentStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(stages.length, (index) {
        final isActive = index <= activeIndex;
        final color = isActive ? const Color(0xFF6C63FF) : Colors.grey.shade400;

        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Icon(
                  isActive ? Icons.check_rounded : Icons.radio_button_off_rounded,
                  size: 14,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stages[index].replaceAll('_', ' '),
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        );
      }),
    );
  }
}
