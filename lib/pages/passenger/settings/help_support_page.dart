import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Help & Support',
      icon: Icons.help_outline_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            SettingsCard(
              child: Column(
                children: [
                  _faqTile(
                    context,
                    'How do I cancel a ride?',
                    'Open your active trip and tap Cancel before driver arrival.',
                  ),
                  Divider(color: palette.border),
                  _faqTile(
                    context,
                    'How is fare calculated?',
                    'Fare depends on distance, time, demand, and selected ride type.',
                  ),
                  Divider(color: palette.border),
                  _faqTile(
                    context,
                    'How do I report an issue?',
                    'Use Contact Support below and include trip details.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsCard(
              child: Column(
                children: [
                  _contactButton(
                    context,
                    Icons.chat_bubble_outline_rounded,
                    'Contact Support',
                    'Start in-app support chat',
                  ),
                  const SizedBox(height: 10),
                  _contactButton(
                    context,
                    Icons.email_outlined,
                    'Email Support',
                    'support@rideconnect.app',
                  ),
                  const SizedBox(height: 10),
                  _contactButton(
                    context,
                    Icons.call_outlined,
                    'Call Support',
                    '+250 700 123 456',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faqTile(BuildContext context, String title, String content) {
    final palette = SettingsPalette.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      iconColor: const Color(0xFF6C63FF),
      collapsedIconColor: const Color(0xFF6C63FF),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            content,
            style: GoogleFonts.poppins(
              color: palette.textSecondary,
              height: 1.5,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactButton(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final palette = SettingsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: palette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF6C63FF)),
        ],
      ),
    );
  }
}
