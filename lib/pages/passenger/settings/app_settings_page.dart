import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/auth_api.dart';
import '../../../auth/auth_session.dart';
import '../../../services/app_theme_service.dart';
import '../../../services/passenger_language_service.dart';
import '../../../services/passenger_preferences_service.dart';
import 'settings_theme.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _darkMode = AppThemeService.isDarkMode;
  bool _pushNotifications = PassengerPreferencesService.pushNotifications;
  bool _locationSharing = PassengerPreferencesService.locationSharing;
  bool _compactMapControls = false;
  bool _autoRefreshDashboard = true;
  bool _highAccuracyLocation = true;
  bool _updatingPassword = false;
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final PassengerLanguageService _lang = PassengerLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _loadLocalSettings();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _compactMapControls = prefs.getBool('app.compact_map_controls') ?? false;
      _autoRefreshDashboard =
          prefs.getBool('app.auto_refresh_dashboard') ?? true;
      _highAccuracyLocation =
          prefs.getBool('app.high_accuracy_location') ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
                    (v) async {
                      setState(() => _pushNotifications = v);
                      await PassengerPreferencesService.setPushNotifications(v);
                    },
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    _lang.t('profile.locationSharing'),
                    _locationSharing,
                    Icons.location_on_rounded,
                    (v) async {
                      if (v) {
                        final serviceEnabled =
                            await Geolocator.isLocationServiceEnabled();
                        if (!serviceEnabled) {
                          _showPasswordSnack(
                            'Enable device location service first.',
                          );
                          return;
                        }
                        var permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                        }
                      }
                      setState(() => _locationSharing = v);
                      await PassengerPreferencesService.setLocationSharing(v);
                    },
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Compact map controls',
                    _compactMapControls,
                    Icons.map_rounded,
                    (v) async {
                      setState(() => _compactMapControls = v);
                      await _saveBool('app.compact_map_controls', v);
                    },
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'Auto refresh dashboard',
                    _autoRefreshDashboard,
                    Icons.refresh_rounded,
                    (v) async {
                      setState(() => _autoRefreshDashboard = v);
                      await _saveBool('app.auto_refresh_dashboard', v);
                    },
                  ),
                  Divider(color: palette.border),
                  _switchTile(
                    context,
                    'High-accuracy location mode',
                    _highAccuracyLocation,
                    Icons.gps_fixed_rounded,
                    (v) async {
                      setState(() => _highAccuracyLocation = v);
                      await _saveBool('app.high_accuracy_location', v);
                    },
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
                      dropdownColor: palette.surface,
                      style: GoogleFonts.poppins(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      iconEnabledColor: palette.textSecondary,
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
            const SizedBox(height: 12),
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lang.t('settings.changePassword'),
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _passwordField(
                    controller: _currentPasswordCtrl,
                    hint: _lang.t('settings.currentPassword'),
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                  _passwordField(
                    controller: _newPasswordCtrl,
                    hint: _lang.t('settings.newPassword'),
                    icon: Icons.lock_reset_rounded,
                  ),
                  const SizedBox(height: 10),
                  _passwordField(
                    controller: _confirmPasswordCtrl,
                    hint: _lang.t('settings.confirmPassword'),
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _updatingPassword ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                      ),
                      icon:
                          _updatingPassword
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _updatingPassword
                            ? _lang.t('settings.updatingPassword')
                            : _lang.t('settings.updatePassword'),
                      ),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    final palette = SettingsPalette.of(context);
    return TextField(
      controller: controller,
      obscureText: true,
      style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: palette.textMuted),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }

  Future<void> _updatePassword() async {
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (current.trim().isEmpty ||
        next.trim().isEmpty ||
        confirm.trim().isEmpty) {
      _showPasswordSnack(_lang.t('settings.passwordRequired'));
      return;
    }
    if (next.length < 6) {
      _showPasswordSnack(_lang.t('settings.passwordLength'));
      return;
    }
    if (next != confirm) {
      _showPasswordSnack(_lang.t('settings.passwordMismatch'));
      return;
    }

    final session = await AuthSession.load();
    final token = session?.token;
    if (token == null || token.trim().isEmpty) {
      _showPasswordSnack(_lang.t('settings.passwordRelogin'));
      return;
    }

    setState(() => _updatingPassword = true);
    try {
      await AuthApi.updateUserPassword(
        token: token,
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _showPasswordSnack(_lang.t('settings.passwordUpdated'), success: true);
    } catch (e) {
      _showPasswordSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _updatingPassword = false);
      }
    }
  }

  void _showPasswordSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF10B981) : null,
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
