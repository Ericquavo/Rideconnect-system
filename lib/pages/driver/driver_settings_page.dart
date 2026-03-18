import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_theme_service.dart';
import '../../services/driver_language_service.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool _notificationsEnabled = true;
  bool _locationServicesEnabled = true;
  final DriverLanguageService _lang = DriverLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedLanguage = _lang.languageNotifier.value;
    final background =
        isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
    final backgroundGradientTop =
        isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F6FF);
    final backgroundGradientBottom =
        isDark ? const Color(0xFF1A1F3A) : const Color(0xFFDDE7FF);
    final cardBg =
        isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.94);
    final cardBorder =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFC9D6F2);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final subtitleColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final dropdownBg = isDark ? const Color(0xFF1A1F3A) : Colors.white;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
        title: Text(
          _lang.t('settings.title'),
          style: GoogleFonts.poppins(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundGradientTop, backgroundGradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  _switchTile(
                    isDark: isDark,
                    bodyColor: bodyColor,
                    icon: Icons.dark_mode_rounded,
                    title: _lang.t('settings.darkMode'),
                    value: isDark,
                    onChanged: (value) async {
                      await AppThemeService.setDarkMode(value);
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                  _divider(),
                  _switchTile(
                    isDark: isDark,
                    bodyColor: bodyColor,
                    icon: Icons.notifications_active_rounded,
                    title: _lang.t('settings.notifications'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                    },
                  ),
                  _divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.language_rounded,
                      color: Color(0xFF6C63FF),
                      size: 20,
                    ),
                    title: Text(
                      _lang.t('settings.language'),
                      style: GoogleFonts.poppins(
                        color: bodyColor,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _lang.languageLabel(selectedLanguage),
                      style: GoogleFonts.poppins(
                        color: subtitleColor,
                        fontSize: 12,
                      ),
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _lang.codeOf(selectedLanguage),
                        dropdownColor: dropdownBg,
                        style: GoogleFonts.poppins(color: bodyColor),
                        iconEnabledColor: const Color(0xFF6C63FF),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              _lang.languageLabel(DriverLanguage.english),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text(
                              _lang.languageLabel(DriverLanguage.french),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'rw',
                            child: Text(
                              _lang.languageLabel(DriverLanguage.kinyarwanda),
                            ),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == 'fr') {
                            await _lang.setLanguage(DriverLanguage.french);
                          } else if (value == 'rw') {
                            await _lang.setLanguage(DriverLanguage.kinyarwanda);
                          } else {
                            await _lang.setLanguage(DriverLanguage.english);
                          }
                        },
                      ),
                    ),
                  ),
                  _divider(),
                  _switchTile(
                    isDark: isDark,
                    bodyColor: bodyColor,
                    icon: Icons.location_on_rounded,
                    title: _lang.t('settings.location'),
                    value: _locationServicesEnabled,
                    onChanged: (value) {
                      setState(() => _locationServicesEnabled = value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required bool isDark,
    required Color bodyColor,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
      title: Text(
        title,
        style: GoogleFonts.poppins(color: bodyColor, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF10B981),
        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.25),
        inactiveThumbColor: isDark ? Colors.white38 : Colors.white,
        inactiveTrackColor:
            isDark
                ? Colors.white12
                : const Color(0xFFCBD5E1).withValues(alpha: 0.75),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFC9D6F2),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}
