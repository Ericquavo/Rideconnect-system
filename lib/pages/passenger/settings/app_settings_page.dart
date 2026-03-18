import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/app_theme_service.dart';
import '../../../services/passenger_language_service.dart';
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
  final PassengerLanguageService _lang = PassengerLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: _lang.t('settings.title'),
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
                    _lang.t('profile.darkMode'),
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
                    _lang.t('profile.pushNotifications'),
                    _pushNotifications,
                    Icons.notifications_rounded,
                    (v) => setState(() => _pushNotifications = v),
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    _lang.t('profile.locationSharing'),
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
                    child: DropdownButton<PassengerLanguage>(
                      value: _lang.current,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF131729),
                      style: GoogleFonts.poppins(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      underline: const SizedBox.shrink(),
                      items:
                          PassengerLanguage.values
                              .map(
                                (language) =>
                                    DropdownMenuItem<PassengerLanguage>(
                                      value: language,
                                      child: Text(
                                        _lang.languageLabel(language),
                                      ),
                                    ),
                              )
                              .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        await _lang.setLanguage(v);
                      },
                    ),
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
