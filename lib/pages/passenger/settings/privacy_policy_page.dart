import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/passenger_language_service.dart';
import 'settings_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final lang = PassengerLanguageService.instance;
    return SettingsPageLayout(
      title: lang.t('settings.privacy'),
      icon: Icons.privacy_tip_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SettingsCard(
          child: SingleChildScrollView(
            child: Text(
              'RideConnect Privacy Policy\n\n'
              'Effective date: May 16, 2026\n\n'
              'Introduction\n'
              'RideConnect ("we", "us", "our") provides a platform connecting passengers and drivers for ride services. We respect your privacy and are committed to protecting your personal data. This policy explains what information we collect, how we use it, who we share it with, and your rights.\n\n'
              '1. Information We Collect\n'
              '- Profile information: name, email, phone number, profile photo, and preferences.\n'
              '- Location data: real-time and historical GPS coordinates needed to match drivers, show ETAs, and navigate trips.\n'
              '- Trip information: pickup/drop-off locations, routes, timestamps, fares, driver details and ratings.\n'
              '- Payment information: payment method identifiers (e.g., masked card digits or mobile-money numbers). Full card data is processed by our payment providers and is not stored on our servers.\n'
              '- Device and usage data: device identifiers, OS version, app version, logs and analytics to improve the service.\n\n'
              '2. How We Use Your Information\n'
              'We use the data to:\n'
              '- Provide and operate ride matching, navigation, and payments.\n'
              '- Communicate about bookings, receipts, support, and safety alerts.\n'
              '- Prevent fraud and abuse, and to comply with legal obligations.\n'
              '- Improve the app, personalize your experience, and measure performance.\n\n'
              '3. Sharing and Disclosure\n'
              'We share limited information as needed:\n'
              '- With drivers: ride details (pickup/drop-off, contact method) so drivers can complete trips.\n'
              '- With service providers: payment processors, mapping providers, and analytics vendors under contracts that require data protection.\n'
              '- For legal reasons: when required by law or to respond to lawful requests.\n\n'
              '4. Location and Real-time Features\n'
              'Real-time location is essential for RideConnect. You can control location sharing using the app settings; disabling real-time sharing may limit functionality. We retain location data only as needed for service delivery and as required by law.\n\n'
              '5. Payments\n'
              'Payments are processed through third-party providers. We store only minimal payment metadata (transaction IDs, masked card/phone info) required for receipts and disputes. We do not store full card CVV numbers.\n\n'
              '6. Data Retention and Deletion\n'
              'We retain personal data for as long as necessary to provide services, comply with legal obligations, resolve disputes, and enforce agreements. You may request access, correction, or deletion of your data by contacting us (see below). Some data may be retained in anonymized or aggregated form.\n\n'
              '7. Security\n'
              'We use industry-standard security controls such as encryption in transit, access controls, and secure APIs to protect your data. However, no system is completely secure — please protect your account credentials.\n\n'
              '8. Children\n'
              'The app is not intended for children under 13. We do not knowingly collect personal data from children under applicable age thresholds.\n\n'
              '9. Your Rights\n'
              'Depending on your jurisdiction, you may have rights to access, correct, export, restrict, or delete your personal data, and to object to or restrict certain processing. To exercise these rights, contact us. We will respond in accordance with applicable law.\n\n'
              '10. Third-party Links\n'
              'The app may contain links to third-party sites. This policy does not apply to third-party websites or services; please review their privacy policies.\n\n'
              '11. Changes to this Policy\n'
              'We may update this policy. Material changes will be communicated in-app or via your registered contact details.\n\n'
              'Contact Us\n'
              'For questions or requests about your personal data, email us at privacy@rideconnect.app or send a support request through the app.\n\n'
              'By using RideConnect you agree to the collection and use of information in accordance with this policy.',
              style: GoogleFonts.poppins(
                color: palette.textSecondary,
                height: 1.6,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
