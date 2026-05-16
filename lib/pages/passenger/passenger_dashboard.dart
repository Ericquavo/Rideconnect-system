import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:typed_data';
import 'home_page.dart';
import 'passenger_booking_flow_page.dart';
import 'trips_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import '../../services/passenger_language_service.dart';
import '../../services/passenger_preferences_service.dart';
import '../../features/mobile/data/mobile_flow_api_service.dart';

/// Main Passenger Dashboard — hosts the bottom navigation and all sub-pages.
class PassengerDashboard extends StatefulWidget {
  final String passengerName;
  final String passengerEmail;

  const PassengerDashboard({
    super.key,
    required this.passengerName,
    required this.passengerEmail,
  });

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  int _currentIndex = 0;
  late String _passengerName;
  late String _passengerEmail;
  int _tripsRefreshToken = 0;
  int _bookingSuccessNonce = 0;
  bool _showNotificationsPage = false;

  // Unread notification badge count
  int _notifCount = 0;
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _passengerName = widget.passengerName;
    _passengerEmail = widget.passengerEmail;
    PassengerPreferencesService.pushNotificationsNotifier.addListener(
      _onNotificationPreferencesChanged,
    );
    PassengerPreferencesService.rideRequestAlertsNotifier.addListener(
      _onNotificationPreferencesChanged,
    );
    PassengerPreferencesService.autoRefreshDashboardNotifier.addListener(
      _onNotificationPreferencesChanged,
    );
    _refreshUnreadCount();
    _syncNotificationTimer();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    PassengerPreferencesService.pushNotificationsNotifier.removeListener(
      _onNotificationPreferencesChanged,
    );
    PassengerPreferencesService.rideRequestAlertsNotifier.removeListener(
      _onNotificationPreferencesChanged,
    );
    PassengerPreferencesService.autoRefreshDashboardNotifier.removeListener(
      _onNotificationPreferencesChanged,
    );
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onNotificationPreferencesChanged() {
    if (!mounted) return;
    _syncNotificationTimer();
    setState(() {});
  }

  bool get _canAutoRefreshBadge =>
      PassengerPreferencesService.pushNotifications &&
      PassengerPreferencesService.rideRequestAlerts &&
      PassengerPreferencesService.autoRefreshDashboard;

  void _syncNotificationTimer() {
    if (_canAutoRefreshBadge) {
      _notificationTimer ??= Timer.periodic(
        const Duration(seconds: 20),
        (_) => _refreshUnreadCount(),
      );
      return;
    }

    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  List<Widget> _buildPages() {
    return [
      HomePage(
        passengerName: _passengerName,
        onProfileUpdated: _updatePassengerProfile,
        onGoToBookRide: () => setState(() => _currentIndex = 1),
        notifCount: _notifCount,
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfileFromHome,
      ),
      PassengerBookingFlowPage(onBookingCompleted: _onBookingCompleted),
      TripsPage(
        key: ValueKey(_tripsRefreshToken),
        bookingSuccessNonce: _bookingSuccessNonce,
      ),
      ProfilePage(name: _passengerName, email: _passengerEmail),
    ];
  }

  void _updatePassengerProfile({
    required String name,
    required String email,
    Uint8List? avatarBytes,
  }) {
    if (!mounted) return;
    setState(() {
      _passengerName = name.trim().isEmpty ? _passengerName : name.trim();
      _passengerEmail = email.trim().isEmpty ? _passengerEmail : email.trim();
    });
    if (avatarBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PassengerPreferencesService.setProfilePhotoBytes(
          avatarBytes,
        ).catchError((_) {});
      });
    }
  }

  void _onBookingCompleted() {
    setState(() {
      _currentIndex = 2;
      _tripsRefreshToken++;
      _bookingSuccessNonce++;
    });
  }

  Future<void> _openNotifications() async {
    setState(() => _showNotificationsPage = true);
    await _refreshUnreadCount();
  }

  void _openProfileFromHome() {
    setState(() {
      _showNotificationsPage = false;
      _currentIndex = 3;
    });
  }

  Future<void> _refreshUnreadCount() async {
    if (!_canAutoRefreshBadge) return;
    try {
      final count = await mobileFlowApi.getUnreadCount();
      if (!mounted) return;
      setState(() => _notifCount = count);
    } catch (_) {
      // Ignore short network errors for badge polling.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _buildPages();
    final content =
        _showNotificationsPage
            ? NotificationsPage(
              onBack: () => setState(() => _showNotificationsPage = false),
              onRead: () => setState(() => _notifCount = 0),
              onUnreadChanged: (count) => setState(() => _notifCount = count),
            )
            : IndexedStack(index: _currentIndex, children: pages);

    final scaffoldColor =
        isDark ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);

    return PopScope(
      canPop: !_showNotificationsPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showNotificationsPage) {
          setState(() => _showNotificationsPage = false);
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldColor,
        body: content,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF6C63FF);
    final inactiveColor =
        isDark ? const Color(0xFF4A5080) : const Color(0xFF64748B);
    final bgColor = isDark ? const Color(0xFF131729) : const Color(0xFFFFFFFF);
    final shadowColor =
        isDark
            ? Colors.black.withValues(alpha: 0.4)
            : const Color(0xFF334155).withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
                onTap:
                    (i) => setState(() {
                      _showNotificationsPage = false;
                      _currentIndex = i;
                    }),
              ),
              _NavItem(
                index: 1,
                currentIndex: _currentIndex,
                icon: Icons.directions_car_rounded,
                label: _lang.t('nav.book'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap:
                    (i) => setState(() {
                      _showNotificationsPage = false;
                      _currentIndex = i;
                    }),
              ),
              _NavItem(
                index: 2,
                currentIndex: _currentIndex,
                icon: Icons.receipt_long_rounded,
                label: _lang.t('nav.trips'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap:
                    (i) => setState(() {
                      _showNotificationsPage = false;
                      _currentIndex = i;
                    }),
              ),
              _NavItem(
                index: 3,
                currentIndex: _currentIndex,
                icon: Icons.person_rounded,
                label: _lang.t('nav.profile'),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap:
                    (i) => setState(() {
                      _showNotificationsPage = false;
                      _currentIndex = i;
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Item ──────────────────────────────────────────────────────────

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

// ─── Bottom Nav Item with Badge ───────────────────────────────────────────────
