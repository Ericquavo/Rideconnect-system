import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../features/trips/presentation/pages/location_picker_page.dart';

class PrivateCarRequestScreen extends StatefulWidget {
  const PrivateCarRequestScreen({super.key});

  @override
  State<PrivateCarRequestScreen> createState() => _PrivateCarRequestScreenState();
}

class _PrivateCarRequestScreenState extends State<PrivateCarRequestScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  int _seatCount = 1;
  DateTime? _scheduleTime;
  bool _isScheduled = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(bool isPickup) async {
    final initial = isPickup ? _pickupLatLng : _destinationLatLng;
    final title = isPickup ? 'Select Pickup Location' : 'Select Destination';
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialLocation: initial, title: title),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          _pickupLatLng = result.latlng;
          _pickupController.text = result.address;
        } else {
          _destinationLatLng = result.latlng;
          _destinationController.text = result.address;
        }
      });
    }
  }

  Future<void> _pickScheduleTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _scheduleTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _isScheduled = true;
    });
  }

  void _proceedToDrivers() {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and destination locations')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/car/drivers',
      arguments: {
        'pickup_name': _pickupController.text,
        'pickup_lat': _pickupLatLng!.latitude,
        'pickup_lng': _pickupLatLng!.longitude,
        'dropoff_name': _destinationController.text,
        'dropoff_lat': _destinationLatLng!.latitude,
        'dropoff_lng': _destinationLatLng!.longitude,
        'seats': _seatCount,
        'schedule_time': _scheduleTime,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF131729) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Private Car',
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Where are you heading?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Pickup Field
              GestureDetector(
                onTap: () => _pickLocation(true),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _pickupController,
                    decoration: InputDecoration(
                      labelText: 'Pickup Location',
                      prefixIcon: const Icon(Icons.my_location_rounded, color: Color(0xFF6C63FF)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Destination Field
              GestureDetector(
                onTap: () => _pickLocation(false),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: 'Destination Location',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Seats Dropdown
              Text(
                'Required Seats',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _seatCount,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: List.generate(4, (i) => i + 1).map((val) {
                  return DropdownMenuItem<int>(
                    value: val,
                    child: Text('$val seat${val > 1 ? "s" : ""}', style: GoogleFonts.poppins(color: textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _seatCount = val ?? 1;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Schedule Switch
              SwitchListTile(
                value: _isScheduled,
                onChanged: (val) {
                  if (val) {
                    _pickScheduleTime();
                  } else {
                    setState(() {
                      _isScheduled = false;
                      _scheduleTime = null;
                    });
                  }
                },
                title: Text('Schedule Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textPrimary)),
                subtitle: Text(
                  _scheduleTime != null
                      ? 'Departure: ${_scheduleTime!.toLocal().toString().substring(0, 16)}'
                      : 'Request immediate ride',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _proceedToDrivers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                label: Text(
                  'Find Available Drivers',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
