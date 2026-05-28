import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class TripPreferencesPage extends StatefulWidget {
  const TripPreferencesPage({super.key});

  @override
  State<TripPreferencesPage> createState() => _TripPreferencesPageState();
}

class _TripPreferencesPageState extends State<TripPreferencesPage> {
  String _tripType = 'Economy';
  String _preferredPayment = 'Mobile Money';
  int _maxWaitMinutes = 8;
  bool _notifyPromo = true;
  bool _notifyTrip = true;
  bool _quietMode = false;
  bool _allowPooling = true;
  bool _avoidTolls = false;
  String _pickupLocation = 'Current Location';

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Trip preferences',
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
                    'Preferred trip type',
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _tripType,
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
                        (v) => setState(() => _tripType = v ?? _tripType),
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
                    'Preferred payment method',
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _preferredPayment,
                    decoration: _inputDecoration(context),
                    dropdownColor:
                        palette.isDark ? const Color(0xFF1D2342) : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'Mobile Money',
                        child: Text('Mobile Money'),
                      ),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    ],
                    onChanged: (v) {
                      setState(
                        () => _preferredPayment = v ?? _preferredPayment,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Max wait time: $_maxWaitMinutes min',
                    style: GoogleFonts.poppins(
                      color: palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Slider(
                    value: _maxWaitMinutes.toDouble(),
                    min: 3,
                    max: 20,
                    divisions: 17,
                    onChanged: (value) {
                      setState(() => _maxWaitMinutes = value.round());
                    },
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
                    'Trip updates',
                    _notifyTrip,
                    (v) => setState(() => _notifyTrip = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Promotional notifications',
                    _notifyPromo,
                    (v) => setState(() => _notifyPromo = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Quiet mode',
                    _quietMode,
                    (v) => setState(() => _quietMode = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Allow pooled trips',
                    _allowPooling,
                    (v) => setState(() => _allowPooling = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Avoid toll roads',
                    _avoidTolls,
                    (v) => setState(() => _avoidTolls = v),
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
                    'Default pickup',
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
              text: 'Save trip preferences',
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
