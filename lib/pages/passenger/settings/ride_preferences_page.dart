import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class RidePreferencesPage extends StatefulWidget {
  const RidePreferencesPage({super.key});

  @override
  State<RidePreferencesPage> createState() => _RidePreferencesPageState();
}

class _RidePreferencesPageState extends State<RidePreferencesPage> {
  String _rideType = 'Economy';
  bool _notifyPromo = true;
  bool _notifyTrip = true;
  bool _quietMode = false;
  String _pickupLocation = 'Current Location';

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Ride Preferences',
      icon: Icons.tune_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferred Ride Type',
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _rideType,
                    decoration: _inputDecoration(context),
                    dropdownColor:
                        palette.isDark ? const Color(0xFF1D2342) : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'Economy',
                        child: Text('Economy'),
                      ),
                      DropdownMenuItem(
                        value: 'Premium',
                        child: Text('Premium'),
                      ),
                      DropdownMenuItem(value: 'Bike', child: Text('Bike')),
                    ],
                    onChanged:
                        (v) => setState(() => _rideType = v ?? _rideType),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsCard(
              child: Column(
                children: [
                  _switchTile(
                    context,
                    'Trip Updates Notifications',
                    _notifyTrip,
                    (v) => setState(() => _notifyTrip = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Promotional Notifications',
                    _notifyPromo,
                    (v) => setState(() => _notifyPromo = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Quiet Mode',
                    _quietMode,
                    (v) => setState(() => _quietMode = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Default Pickup Location',
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _pickupLocation,
                    decoration: _inputDecoration(context),
                    dropdownColor:
                        palette.isDark ? const Color(0xFF1D2342) : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'Current Location',
                        child: Text('Current Location'),
                      ),
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Office', child: Text('Office')),
                    ],
                    onChanged:
                        (v) => setState(
                          () => _pickupLocation = v ?? _pickupLocation,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            BrandButton(
              text: 'Save Preferences',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final palette = SettingsPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6C63FF),
          activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return InputDecoration(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.4),
      ),
    );
  }
}
