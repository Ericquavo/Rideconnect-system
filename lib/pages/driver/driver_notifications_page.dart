import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_language_service.dart';

class DriverNotificationsPage extends StatelessWidget {
  const DriverNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = DriverLanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                  : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
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
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFF64748B),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.t('notifications.title'),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Notifications are disabled in strict API mode.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color:
                        isDark ? Colors.white54 : const Color(0xFF475569),
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
