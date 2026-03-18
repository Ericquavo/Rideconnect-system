import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/auth_api.dart';
import '../../auth/auth_session.dart';
import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../login_page.dart';
import 'driver_home_page.dart';
import 'driver_requests_page.dart';
import 'driver_trips_page.dart';
import 'driver_earnings_page.dart';
import 'driver_profile_page.dart';
import 'driver_edit_profile_page.dart';
import 'driver_help_page.dart';
import 'driver_payout_page.dart';
import 'driver_settings_page.dart';
import 'driver_vehicle_info_page.dart';

class DriverDashboard extends StatefulWidget {
  final String driverName;
  final String driverEmail;

  const DriverDashboard({
    super.key,
    required this.driverName,
    required this.driverEmail,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;
  bool _isOnline = true;
  final DriverLanguageService _lang = DriverLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
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

  void _handleStatusChanged(bool value) {
    setState(() => _isOnline = value);
    DriverApi.instance.updateStatus(isOnline: value).catchError((_) {
      // Keep local toggle responsive even if network update fails.
      return <String, dynamic>{};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? _lang.t('status.online') : _lang.t('status.offline'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => DriverEditProfilePage(
              initialName: widget.driverName,
              initialEmail: widget.driverEmail,
            ),
      ),
    );
  }

  Future<void> _openVehicleInfo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VehicleInfoPage()));
  }

  Future<void> _openPayout() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PayoutPage()));
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DriverSettingsPage()));
  }

  Future<void> _openHelp() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DriverHelpPage()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackground =
        isDark ? const Color(0xFF131729) : const Color(0xFFFFFFFF);
    final navShadow =
        isDark
            ? Colors.black.withValues(alpha: 0.4)
            : const Color(0xFF334155).withValues(alpha: 0.12);
    final inactiveColor =
        isDark ? const Color(0xFF4A5080) : const Color(0xFF64748B);

    final pages = [
      DriverHomePage(
        driverName: widget.driverName,
        isOnline: _isOnline,
        onStatusChanged: _handleStatusChanged,
      ),
      DriverRequestsPage(isOnline: _isOnline),
      const DriverEarningsPage(),
      const DriverTripsPage(),
      DriverProfilePage(
        driverName: widget.driverName,
        driverEmail: widget.driverEmail,
        isOnline: _isOnline,
        onStatusChanged: _handleStatusChanged,
        onEditProfileTap: _openEditProfile,
        onVehicleInfoTap: _openVehicleInfo,
        onPayoutTap: _openPayout,
        onSettingsTap: _openSettings,
        onHelpTap: _openHelp,
        onLogout: () => _logout(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(
        navBackground: navBackground,
        navShadow: navShadow,
        inactiveColor: inactiveColor,
      ),
    );
  }

  Widget _buildBottomNav({
    required Color navBackground,
    required Color navShadow,
    required Color inactiveColor,
  }) {
    const activeColor = Color(0xFF6C63FF);

    return Container(
      decoration: BoxDecoration(
        color: navBackground,
        boxShadow: [
          BoxShadow(
            color: navShadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: 0,
                currentIndex: _currentIndex,
                icon: Icons.home_rounded,
                label: _lang.t('nav.home'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                index: 1,
                currentIndex: _currentIndex,
                icon: Icons.local_taxi_rounded,
                label: _lang.t('nav.requests'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                index: 2,
                currentIndex: _currentIndex,
                icon: Icons.account_balance_wallet_rounded,
                label: _lang.t('nav.earnings'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                index: 3,
                currentIndex: _currentIndex,
                icon: Icons.receipt_long_rounded,
                label: _lang.t('nav.history'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                index: 4,
                currentIndex: _currentIndex,
                icon: Icons.person_rounded,
                label: _lang.t('nav.profile'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final session = await AuthSession.load();
    await AuthApi.clearSession(token: session?.token);
    await AuthSession.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
