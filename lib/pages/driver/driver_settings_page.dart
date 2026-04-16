import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/auth_api.dart';
import '../../auth/auth_session.dart';
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
  bool _updatingPassword = false;

  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

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
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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
                  _divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.t('settings.changePassword'),
                          style: GoogleFonts.poppins(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _passwordField(
                          controller: _currentPasswordCtrl,
                          hint: _lang.t('settings.currentPassword'),
                          isDark: isDark,
                          bodyColor: bodyColor,
                          borderColor: cardBorder,
                        ),
                        const SizedBox(height: 10),
                        _passwordField(
                          controller: _newPasswordCtrl,
                          hint: _lang.t('settings.newPassword'),
                          isDark: isDark,
                          bodyColor: bodyColor,
                          borderColor: cardBorder,
                        ),
                        const SizedBox(height: 10),
                        _passwordField(
                          controller: _confirmPasswordCtrl,
                          hint: _lang.t('settings.confirmPassword'),
                          isDark: isDark,
                          bodyColor: bodyColor,
                          borderColor: cardBorder,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _updatingPassword ? null : _updatePassword,
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
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color bodyColor,
    required Color borderColor,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: GoogleFonts.poppins(color: bodyColor, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: isDark ? Colors.white38 : const Color(0xFF64748B),
          fontSize: 12,
        ),
        filled: true,
        fillColor:
            isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.95),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
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
}
