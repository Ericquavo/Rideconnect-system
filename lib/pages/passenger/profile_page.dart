import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/auth_api.dart';
import '../../auth/auth_session.dart';
import '../../services/passenger_api.dart';
import '../../services/app_theme_service.dart';
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
  bool _darkMode = AppThemeService.isDarkMode;
  bool _notifications = true;
  bool _locationSharing = true;
  bool _isLoggingOut = false;
  String _profileName = '';
  String _profileEmail = '';
  bool _isSummaryLoading = true;
  int _totalRides = 0;
  double _totalSpent = 0;
  double _avgRating = 0;

  static const _settingsItems = [
    {'icon': Icons.edit_rounded, 'label': 'Edit Profile', 'color': 0xFF6C63FF},
    {
      'icon': Icons.payment_rounded,
      'label': 'Payment Methods',
      'color': 0xFF3B82F6,
    },
    {
      'icon': Icons.tune_rounded,
      'label': 'Ride Preferences',
      'color': 0xFF10B981,
    },
    {
      'icon': Icons.settings_rounded,
      'label': 'App Settings',
      'color': 0xFF6C63FF,
    },
    {
      'icon': Icons.help_outline_rounded,
      'label': 'Help & Support',
      'color': 0xFF3B82F6,
    },
    {
      'icon': Icons.privacy_tip_outlined,
      'label': 'Privacy Policy',
      'color': 0xFF10B981,
    },
    {
      'icon': Icons.star_outline_rounded,
      'label': 'Rate RideConnect',
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
  }

  @override
  void dispose() {
    AppThemeService.themeModeNotifier.removeListener(_syncDarkModeFromAppTheme);
    super.dispose();
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1F3A)],
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
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1F3A), Color(0xFF0D1430)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                child: Center(
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white54,
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
                        'Verified Passenger',
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
          label: 'Total Rides',
          value: ridesValue,
          icon: Icons.directions_car_rounded,
        ),
        const SizedBox(width: 12),
        _MiniStat(
          label: 'Total Spent',
          value: spentValue,
          icon: Icons.wallet_rounded,
        ),
        const SizedBox(width: 12),
        _MiniStat(
          label: 'Avg Rating',
          value: ratingValue,
          icon: Icons.star_rounded,
        ),
      ],
    );
  }

  Widget _buildToggleSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.dark_mode_rounded,
            label: 'Dark Mode',
            color: const Color(0xFF6C63FF),
            value: _darkMode,
            onChanged: (v) async {
              setState(() => _darkMode = v);
              await AppThemeService.setDarkMode(v);
            },
          ),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 20),
          _ToggleRow(
            icon: Icons.notifications_rounded,
            label: 'Push Notifications',
            color: const Color(0xFF3B82F6),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 20),
          _ToggleRow(
            icon: Icons.location_on_rounded,
            label: 'Location Sharing',
            color: const Color(0xFF10B981),
            value: _locationSharing,
            onChanged: (v) => setState(() => _locationSharing = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: List.generate(_settingsItems.length, (i) {
          final item = _settingsItems[i];
          final color = Color(item['color'] as int);
          final isLast = i == _settingsItems.length - 1;
          return Column(
            children: [
              ListTile(
                onTap: () => _openSettingPage(item['label'] as String),
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
                  item['label'] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ),
              if (!isLast)
                Divider(
                  color: Colors.white.withValues(alpha: 0.06),
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

  Future<void> _openSettingPage(String label) async {
    // Keep profile menu navigation centralized for easier maintenance.
    if (label == 'Edit Profile') {
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

    if (label == 'Payment Methods') {
      await Navigator.push(context, settingsRoute(const PaymentMethodsPage()));
      return;
    }

    if (label == 'Ride Preferences') {
      await Navigator.push(context, settingsRoute(const RidePreferencesPage()));
      return;
    }

    if (label == 'App Settings') {
      await Navigator.push(context, settingsRoute(const AppSettingsPage()));
      return;
    }

    if (label == 'Help & Support') {
      await Navigator.push(context, settingsRoute(const HelpSupportPage()));
      return;
    }

    if (label == 'Privacy Policy') {
      await Navigator.push(context, settingsRoute(const PrivacyPolicyPage()));
      return;
    }

    if (label == 'Rate RideConnect') {
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
          'Log Out',
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
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF131729),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                    'Log Out?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to log out of RideConnect?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
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
                                    Navigator.pop(context);
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
                                    'Log Out',
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
          ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    final session = await AuthSession.load();
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
