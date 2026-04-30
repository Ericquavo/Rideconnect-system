import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';
import '../../services/app_theme_service.dart';

/// Driver profile/settings tab with account and vehicle details.
class DriverProfilePage extends StatefulWidget {
  final String driverName;
  final String driverEmail;
  final int unreadNotificationCount;
  final bool isOnline;
  final ValueChanged<bool> onStatusChanged;
  final VoidCallback onEditProfileTap;
  final VoidCallback onVehicleInfoTap;
  final VoidCallback onPayoutTap;
  final VoidCallback onBookingQueueTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onHelpTap;
  final VoidCallback onLogout;

  const DriverProfilePage({
    super.key,
    required this.driverName,
    required this.driverEmail,
    this.unreadNotificationCount = 0,
    required this.isOnline,
    required this.onStatusChanged,
    required this.onEditProfileTap,
    required this.onVehicleInfoTap,
    required this.onPayoutTap,
    required this.onBookingQueueTap,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onHelpTap,
    required this.onLogout,
  });

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  late Future<_DriverProfileData> _profileFuture;
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverSyncService _sync = DriverSyncService.instance;
  bool _darkMode = AppThemeService.isDarkMode;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFEFF4FF);
  Color get _cardBg =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.98);
  Color get _cardBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFD1D5E0);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF334155);
  Color get _textMuted =>
      _isDarkMode ? Colors.white70 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _profileFuture = _loadData();
    _sync.dataVersionNotifier.addListener(_onSyncDataChanged);
    AppThemeService.themeModeNotifier.addListener(_syncDarkModeFromAppTheme);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _sync.dataVersionNotifier.removeListener(_onSyncDataChanged);
    AppThemeService.themeModeNotifier.removeListener(_syncDarkModeFromAppTheme);
    super.dispose();
  }

  void _syncDarkModeFromAppTheme() {
    if (!mounted) return;
    setState(() => _darkMode = AppThemeService.isDarkMode);
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSyncDataChanged() {
    if (!mounted) return;
    setState(() => _profileFuture = _loadData());
  }

  Future<void> _refresh() async {
    setState(() => _profileFuture = _loadData());
    await _profileFuture;
  }

  Future<_DriverProfileData> _loadData() async {
    final api = DriverApi.instance;
    final profileResponse = await api.getProfile();
    final statsResponse = await api.getStats();

    final profile = api.extractDataMap(profileResponse);
    final stats = api.extractDataMap(statsResponse);

    final vehicleRaw = profile['vehicle'];
    final vehicle =
        vehicleRaw is Map<String, dynamic> ? vehicleRaw : <String, dynamic>{};

    return _DriverProfileData(
      name: api.readString(profile, const [
        'name',
        'full_name',
      ], fallback: widget.driverName),
      email: api.readString(profile, const [
        'email',
      ], fallback: widget.driverEmail),
      phone: api.readString(profile, const [
        'phone',
        'phone_number',
      ], fallback: '--'),
      rating: api.readDouble(stats, const [
        'rating',
        'driver_rating',
        'avg_rating',
      ]),
      vehicleName: api.readString(
        vehicle,
        const ['name', 'model', 'vehicle_name'],
        fallback: api.readString(profile, const [
          'vehicle_name',
          'vehicle_model',
        ], fallback: '--'),
      ),
      vehiclePlate: api.readString(
        vehicle,
        const ['plate_number', 'plate', 'license_plate'],
        fallback: api.readString(profile, const [
          'plate_number',
          'plate',
        ], fallback: '--'),
      ),
      vehicleColor: api.readString(
        vehicle,
        const ['color', 'vehicle_color'],
        fallback: api.readString(profile, const [
          'vehicle_color',
        ], fallback: '--'),
      ),
      vehicleCategory: api.readString(
        vehicle,
        const ['category', 'type', 'vehicle_category'],
        fallback: api.readString(profile, const [
          'vehicle_category',
        ], fallback: '--'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<_DriverProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final hasError = snapshot.hasError;
            final data = snapshot.data;

            return RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      )
                    else if (hasError)
                      _errorCard(
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      )
                    else ...[
                      _buildProfileCard(data!),
                      const SizedBox(height: 16),
                      _buildVehicleCard(data),
                    ],
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildSettingsCard(),
                    const SizedBox(height: 18),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            );
          },
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
          _lang.t('profile.title'),
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(_DriverProfileData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
              ),
            ),
            child: Center(
              child: Text(
                data.name.isNotEmpty ? data.name[0].toUpperCase() : 'D',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  data.email,
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.phone,
                  style: GoogleFonts.poppins(
                    color:
                        _isDarkMode ? Colors.white38 : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.rating <= 0
                        ? _lang.t('profile.driverRatingMissing')
                        : _lang.t(
                          'profile.driverRating',
                          args: {
                            'value': '${data.rating.toStringAsFixed(1)} ★',
                          },
                        ),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(_DriverProfileData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lang.t('profile.vehicle'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          _vehicleRow(_lang.t('profile.vehicleLabel'), data.vehicleName),
          _vehicleRow(_lang.t('profile.plateNumber'), data.vehiclePlate),
          _vehicleRow(_lang.t('profile.color'), data.vehicleColor),
          _vehicleRow(_lang.t('profile.category'), data.vehicleCategory),
        ],
      ),
    );
  }

  Widget _vehicleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor =
        widget.isOnline ? const Color(0xFF10B981) : const Color(0xFF8B93A7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: statusColor, size: 12),
          const SizedBox(width: 8),
          Text(
            widget.isOnline
                ? _lang.t('profile.online')
                : _lang.t('profile.offline'),
            style: GoogleFonts.poppins(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Switch(
            value: widget.isOnline,
            onChanged: widget.onStatusChanged,
            activeColor: statusColor,
            activeTrackColor: statusColor.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    final items = [
      (Icons.edit_rounded, _lang.t('profile.edit'), widget.onEditProfileTap, 0),
      (
        Icons.directions_car_rounded,
        _lang.t('profile.vehicleMenu'),
        widget.onVehicleInfoTap,
        0,
      ),
      (
        Icons.payments_rounded,
        _lang.t('profile.payout'),
        widget.onPayoutTap,
        0,
      ),
      (
        Icons.assignment_rounded,
        _lang.t('profile.bookings'),
        widget.onBookingQueueTap,
        0,
      ),
      (
        Icons.notifications_rounded,
        _lang.t('profile.notifications'),
        widget.onNotificationsTap,
        widget.unreadNotificationCount,
      ),
      (
        Icons.settings_rounded,
        _lang.t('profile.settings'),
        widget.onSettingsTap,
        0,
      ),
      (
        Icons.help_outline_rounded,
        _lang.t('profile.help'),
        widget.onHelpTap,
        0,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: const Color(0xFF6C63FF),
              size: 20,
            ),
            title: Text(
              _lang.t('profile.darkMode'),
              style: GoogleFonts.poppins(color: _textMuted, fontSize: 13),
            ),
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) async {
                await AppThemeService.setDarkMode(value);
              },
              activeColor: const Color(0xFF6C63FF),
              activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
            ),
          ),
          Divider(color: _cardBorder, height: 1, indent: 16, endIndent: 16),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final last = i == items.length - 1;
            return Column(
              children: [
                ListTile(
                  onTap: item.$3,
                  leading: Icon(
                    item.$1,
                    color: const Color(0xFF6C63FF),
                    size: 20,
                  ),
                  title: Text(
                    item.$2,
                    style: GoogleFonts.poppins(color: _textMuted, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.$4 > 0)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5E5B),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Text(
                              item.$4 > 99 ? '99+' : '${item.$4}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      if (item.$4 > 0) const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
                if (!last)
                  Divider(
                    color: _cardBorder,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF5E5B), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFFF5E5B),
          size: 18,
        ),
        label: Text(
          _lang.t('profile.logout'),
          style: GoogleFonts.poppins(
            color: const Color(0xFFFF5E5B),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              _isDarkMode ? const Color(0xFF171C33) : const Color(0xFFF8FAFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            _lang.t('logout.confirmTitle'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            _lang.t('logout.confirmBody'),
            style: GoogleFonts.poppins(color: _textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                _lang.t('common.cancel'),
                style: GoogleFonts.poppins(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E5B),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _lang.t('common.yes'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  Widget _errorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5E5B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5E5B).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFB3B1),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DriverProfileData {
  final String name;
  final String email;
  final String phone;
  final double rating;
  final String vehicleName;
  final String vehiclePlate;
  final String vehicleColor;
  final String vehicleCategory;

  const _DriverProfileData({
    required this.name,
    required this.email,
    required this.phone,
    required this.rating,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.vehicleColor,
    required this.vehicleCategory,
  });
}
