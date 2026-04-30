import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/auth_api.dart';
import '../../auth/auth_session.dart';
import '../../services/passenger_api.dart';
import '../../services/app_theme_service.dart';
import '../../services/passenger_preferences_service.dart';
import '../../services/passenger_language_service.dart';
import '../login_page.dart';
import 'settings/settings_theme.dart';
import 'settings/edit_profile_page.dart';
import 'settings/payment_methods_page.dart';
import 'settings/ride_preferences_page.dart';
import 'settings/app_settings_page.dart';
import 'settings/help_support_page.dart';
import 'settings/privacy_policy_page.dart';
import 'settings/rate_app_page.dart';

/// Profile & Settings page for the passenger.
class ProfilePage extends StatefulWidget {
  final String name;
  final String email;

  const ProfilePage({super.key, required this.name, required this.email});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _idEditProfile = 'editProfile';
  static const String _idPaymentMethods = 'paymentMethods';
  static const String _idRidePreferences = 'ridePreferences';
  static const String _idAppSettings = 'appSettings';
  static const String _idHelpSupport = 'helpSupport';
  static const String _idPrivacyPolicy = 'privacyPolicy';
  static const String _idRateApp = 'rateApp';

  bool _darkMode = AppThemeService.isDarkMode;
  bool _notifications = PassengerPreferencesService.pushNotifications;
  bool _locationSharing = PassengerPreferencesService.locationSharing;
  bool _isLoggingOut = false;
  String _profileName = '';
  String _profileEmail = '';
  bool _isSummaryLoading = true;
  int _totalRides = 0;
  double _totalSpent = 0;
  double _avgRating = 0;
  final PassengerLanguageService _lang = PassengerLanguageService.instance;

  static const _settingsItems = [
    {
      'id': _idEditProfile,
      'icon': Icons.edit_rounded,
      'labelKey': 'settings.editProfile',
      'color': 0xFF6C63FF,
    },
    {
      'id': _idPaymentMethods,
      'icon': Icons.payment_rounded,
      'labelKey': 'settings.paymentMethods',
      'color': 0xFF3B82F6,
    },
    {
      'id': _idRidePreferences,
      'icon': Icons.tune_rounded,
      'labelKey': 'settings.ridePreferences',
      'color': 0xFF10B981,
    },
    {
      'id': _idAppSettings,
      'icon': Icons.settings_rounded,
      'labelKey': 'settings.title',
      'color': 0xFF6C63FF,
    },
    {
      'id': _idHelpSupport,
      'icon': Icons.help_outline_rounded,
      'labelKey': 'settings.help',
      'color': 0xFF3B82F6,
    },
    {
      'id': _idPrivacyPolicy,
      'icon': Icons.privacy_tip_outlined,
      'labelKey': 'settings.privacy',
      'color': 0xFF10B981,
    },
    {
      'id': _idRateApp,
      'icon': Icons.star_outline_rounded,
      'labelKey': 'settings.rate',
      'color': 0xFFFBBF24,
    },
  ];

  @override
  void initState() {
    super.initState();
    _profileName = widget.name;
    _profileEmail = widget.email;
    _loadProfile();
    _loadSummary();
    AppThemeService.themeModeNotifier.addListener(_syncDarkModeFromAppTheme);
    PassengerPreferencesService.locationSharingNotifier.addListener(
      _syncLocationSharing,
    );
    PassengerPreferencesService.pushNotificationsNotifier.addListener(
      _syncPushNotifications,
    );
    PassengerPreferencesService.profilePhotoNotifier.addListener(
      _refreshAvatar,
    );
    _lang.languageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    AppThemeService.themeModeNotifier.removeListener(_syncDarkModeFromAppTheme);
    PassengerPreferencesService.locationSharingNotifier.removeListener(
      _syncLocationSharing,
    );
    PassengerPreferencesService.pushNotificationsNotifier.removeListener(
      _syncPushNotifications,
    );
    PassengerPreferencesService.profilePhotoNotifier.removeListener(
      _refreshAvatar,
    );
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _syncLocationSharing() {
    if (!mounted) return;
    setState(
      () => _locationSharing = PassengerPreferencesService.locationSharing,
    );
  }

  void _syncPushNotifications() {
    if (!mounted) return;
    setState(
      () => _notifications = PassengerPreferencesService.pushNotifications,
    );
  }

  void _refreshAvatar() {
    if (!mounted) return;
    setState(() {});
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncDarkModeFromAppTheme() {
    final appDark = AppThemeService.isDarkMode;
    if (_darkMode == appDark || !mounted) return;
    setState(() => _darkMode = appDark);
  }

  Future<void> _loadProfile() async {
    try {
      final response = await PassengerApi.instance.getProfile();
      final data = response['data'];
      final profile =
          data is Map<String, dynamic>
              ? (data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : data)
              : <String, dynamic>{};

      final name = (profile['name'] ?? _profileName).toString();
      final email = (profile['email'] ?? _profileEmail).toString();

      if (!mounted) return;
      setState(() {
        _profileName = name;
        _profileEmail = email;
      });
    } catch (_) {
      // Keep local values if profile endpoint fails.
    }
  }

  Future<void> _loadSummary() async {
    try {
      final bookings = await PassengerApi.instance.getBookings();
      final payments = await PassengerApi.instance.getPaymentHistory();

      double totalSpent = 0;
      for (final payment in payments) {
        final value =
            payment['amount'] ?? payment['price'] ?? payment['fare'] ?? 0;
        totalSpent += double.tryParse(value.toString()) ?? 0;
      }

      double ratingSum = 0;
      int ratingCount = 0;
      for (final booking in bookings) {
        final ratingRaw = booking['rating'];
        if (ratingRaw != null) {
          final rating = double.tryParse(ratingRaw.toString()) ?? 0;
          if (rating > 0) {
            ratingSum += rating;
            ratingCount++;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _totalRides = bookings.length;
        _totalSpent = totalSpent;
        _avgRating = ratingCount == 0 ? 0 : ratingSum / ratingCount;
        _isSummaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSummaryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient =
        isDark
            ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
            : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProfileCard(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildToggleSection(),
              const SizedBox(height: 24),
              _buildSettingsList(context),
              const SizedBox(height: 24),
              _buildLogoutButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF6C63FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _lang.t('profile.title'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBytes = PassengerPreferencesService.profilePhoto;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? const [Color(0xFF1B1F3A), Color(0xFF0D1430)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF5F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFD9E2F7),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child:
                      avatarBytes != null && avatarBytes.isNotEmpty
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : Center(
                            child: Text(
                              _profileName.isNotEmpty
                                  ? _profileName[0].toUpperCase()
                                  : 'P',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                ),
              ),
              // Online indicator
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF131729),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF10B981),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _lang.t('profile.verified'),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final ridesValue = _isSummaryLoading ? '...' : '$_totalRides';
    final spentValue =
        _isSummaryLoading ? '...' : '\$${_totalSpent.toStringAsFixed(2)}';
    final ratingValue =
        _isSummaryLoading
            ? '...'
            : (_avgRating == 0 ? 'N/A' : '${_avgRating.toStringAsFixed(1)} ⭐');

    return Row(
      children: [
        _MiniStat(
          label: _lang.t('profile.totalRides'),
          value: ridesValue,
          icon: Icons.directions_car_rounded,
        ),
        const SizedBox(width: 12),
        _MiniStat(
          label: _lang.t('profile.totalSpent'),
          value: spentValue,
          icon: Icons.wallet_rounded,
        ),
        const SizedBox(width: 12),
        _MiniStat(
          label: _lang.t('profile.avgRating'),
          value: ratingValue,
          icon: Icons.star_rounded,
        ),
      ],
    );
  }

  Widget _buildToggleSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD9E2F7),
        ),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.dark_mode_rounded,
            label: _lang.t('profile.darkMode'),
            color: const Color(0xFF6C63FF),
            value: _darkMode,
            onChanged: (v) async {
              setState(() => _darkMode = v);
              await AppThemeService.setDarkMode(v);
            },
          ),
          Divider(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE2E8F0),
            height: 20,
          ),
          _ToggleRow(
            icon: Icons.notifications_rounded,
            label: _lang.t('profile.pushNotifications'),
            color: const Color(0xFF3B82F6),
            value: _notifications,
            onChanged: (v) async {
              setState(() => _notifications = v);
              await PassengerPreferencesService.setPushNotifications(v);
            },
          ),
          Divider(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE2E8F0),
            height: 20,
          ),
          _ToggleRow(
            icon: Icons.location_on_rounded,
            label: _lang.t('profile.locationSharing'),
            color: const Color(0xFF10B981),
            value: _locationSharing,
            onChanged: (v) async {
              setState(() => _locationSharing = v);
              await PassengerPreferencesService.setLocationSharing(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD9E2F7),
        ),
      ),
      child: Column(
        children: List.generate(_settingsItems.length, (i) {
          final item = _settingsItems[i];
          final color = Color(item['color'] as int);
          final isLast = i == _settingsItems.length - 1;
          return Column(
            children: [
              ListTile(
                onTap: () => _openSettingPage(item['id'] as String),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 18),
                ),
                title: Text(
                  _lang.t(item['labelKey'] as String),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontSize: 14,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              if (!isLast)
                Divider(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFE2E8F0),
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _openSettingPage(String id) async {
    // Keep profile menu navigation centralized for easier maintenance.
    if (id == _idEditProfile) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        settingsRoute(
          EditProfilePage(
            initialName: _profileName,
            initialEmail: _profileEmail,
          ),
        ),
      );

      if (!mounted || result == null) return;
      setState(() {
        _profileName = (result['name'] ?? _profileName).toString();
        _profileEmail = (result['email'] ?? _profileEmail).toString();
      });
      return;
    }

    if (id == _idPaymentMethods) {
      await Navigator.push(context, settingsRoute(const PaymentMethodsPage()));
      return;
    }

    if (id == _idRidePreferences) {
      await Navigator.push(context, settingsRoute(const RidePreferencesPage()));
      return;
    }

    if (id == _idAppSettings) {
      await Navigator.push(context, settingsRoute(const AppSettingsPage()));
      return;
    }

    if (id == _idHelpSupport) {
      await Navigator.push(context, settingsRoute(const HelpSupportPage()));
      return;
    }

    if (id == _idPrivacyPolicy) {
      await Navigator.push(context, settingsRoute(const PrivacyPolicyPage()));
      return;
    }

    if (id == _idRateApp) {
      await Navigator.push(context, settingsRoute(const RateAppPage()));
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF5E5B), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFFF5E5B),
          size: 20,
        ),
        label: Text(
          _lang.t('profile.logout'),
          style: GoogleFonts.poppins(
            color: const Color(0xFFFF5E5B),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (BuildContext dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF131729) : Colors.white;
        final cardBorder =
            isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFC9D6F2);
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? Colors.white54 : const Color(0xFF334155);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF5E5B).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFFF5E5B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF5E5B),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _lang.t('profile.logoutTitle'),
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lang.t('profile.logoutBody'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(0xFFC9D6F2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _lang.t('common.cancel'),
                          style: GoogleFonts.poppins(
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isLoggingOut
                                ? null
                                : () async {
                                  Navigator.pop(dialogContext);
                                  await _logout();
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5E5B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child:
                            _isLoggingOut
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  _lang.t('profile.logout'),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    final session = await AuthSession.load();
    await AuthApi.logout(token: session?.token);
    await AuthApi.clearSession(token: session?.token);
    await AuthSession.clear();

    if (!mounted) return;
    setState(() => _isLoggingOut = false);

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }
}

// ─── Mini Stat Card ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          activeTrackColor: color.withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white12,
        ),
      ],
    );
  }
}
