import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SettingsCard(
          child: SingleChildScrollView(
            child: Text(
              'RideConnect Privacy Policy\n\n'
              'We value your privacy and protect your personal information, location data, and trip history.\n\n'
              '1. Data We Collect\n'
              'We collect profile information, contact details, device metadata, and trip records to provide ride services and support.\n\n'
              '2. Location Data\n'
              'Real-time location is used to match passengers with nearby drivers, calculate fares, and improve route quality.\n\n'
              '3. Payment Information\n'
              'Payment transactions are processed securely through trusted providers. RideConnect does not store full card details on device.\n\n'
              '4. How We Use Data\n'
              'Your data helps deliver rides, prevent fraud, optimize matching, improve safety, and send important service notifications.\n\n'
              '5. Data Sharing\n'
              'We only share necessary ride details between passenger and driver and with compliant service providers where required.\n\n'
              '6. Security\n'
              'We apply encryption, authentication controls, and secure APIs to protect user accounts and trip information.\n\n'
              '7. Your Rights\n'
              'You may request profile updates, account deletion, and data access according to applicable laws and regulations.\n\n'
              '8. Updates\n'
              'This policy may be updated periodically. Material changes are communicated through in-app notices.\n\n'
              'Contact: privacy@rideconnect.app',
              style: GoogleFonts.poppins(
                color: palette.textSecondary,
                height: 1.65,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
