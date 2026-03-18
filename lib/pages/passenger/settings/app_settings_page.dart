import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/app_theme_service.dart';
import 'settings_theme.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _darkMode = AppThemeService.isDarkMode;
  bool _pushNotifications = true;
  bool _locationSharing = true;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'App Settings',
      icon: Icons.settings_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            SettingsCard(
              child: Column(
                children: [
                  _switchTile(
                    context,
                    'Dark Mode',
                    _darkMode,
                    Icons.dark_mode_rounded,
                    (v) async {
                      setState(() => _darkMode = v);
                      await AppThemeService.setDarkMode(v);
                    },
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Push Notifications',
                    _pushNotifications,
                    Icons.notifications_rounded,
                    (v) => setState(() => _pushNotifications = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Location Sharing',
                    _locationSharing,
                    Icons.location_on_rounded,
                    (v) => setState(() => _locationSharing = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF6C63FF),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Language',
                      style: GoogleFonts.poppins(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox.shrink(),
                    dropdownColor:
                        palette.isDark ? const Color(0xFF1D2342) : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(value: 'French', child: Text('French')),
                      DropdownMenuItem(
                        value: 'Kinyarwanda',
                        child: Text('Kinyarwanda'),
                      ),
                    ],
                    onChanged:
                        (v) => setState(() => _language = v ?? _language),
                  ),
                ],
              ),
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
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    final palette = SettingsPalette.of(context);
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 10),
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
}
