import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/passenger_language_service.dart';

class NotificationsPage extends StatelessWidget {
  final VoidCallback onRead;
  final ValueChanged<int>? onUnreadChanged;

  const NotificationsPage({
    super.key,
    required this.onRead,
    this.onUnreadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lang = PassengerLanguageService.instance;
    onUnreadChanged?.call(0);
    onRead();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1F3A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.t('notifications.emptyTitle'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Notifications are disabled in strict API mode.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
