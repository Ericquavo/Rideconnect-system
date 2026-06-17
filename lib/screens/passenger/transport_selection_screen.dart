import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TransportSelectionScreen extends StatelessWidget {
  const TransportSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF131729) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Transport',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'How would you like to travel today?',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a transport service below to begin your journey.',
                style: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // 1. Public Bus Card
              _buildServiceCard(
                context,
                title: 'Public Bus',
                desc: 'Book routes along fixed corridors. Reliable & low-cost.',
                icon: Icons.directions_bus_rounded,
                color: const Color(0xFF3B82F6),
                route: '/bus/corridors',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16),

              // 2. Private Car Card
              _buildServiceCard(
                context,
                title: 'Private Car',
                desc: 'On-demand or scheduled comfort. Direct to destination.',
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF6C63FF),
                route: '/car/request',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16),

              // 3. Motorcycle Card
              _buildServiceCard(
                context,
                title: 'Motorcycle',
                desc: 'Quickest on-demand matching. Avoid traffic easily.',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFFEA580C),
                route: '/moto/request',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required String route,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
