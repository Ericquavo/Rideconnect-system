import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final List<_PaymentMethod> _methods = [
    _PaymentMethod(
      'Mobile Money',
      'MTN •••• 2291',
      Icons.phone_android_rounded,
      const Color(0xFF10B981),
    ),
    _PaymentMethod(
      'Credit / Debit Card',
      'VISA •••• 4242',
      Icons.credit_card_rounded,
      const Color(0xFF3B82F6),
    ),
    _PaymentMethod(
      'Cash',
      'Pay directly to driver',
      Icons.payments_rounded,
      const Color(0xFF6C63FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Payment Methods',
      icon: Icons.payment_rounded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _methods.length,
                itemBuilder: (_, i) {
                  final m = _methods[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SettingsCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(m.icon, color: m.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.title,
                                  style: GoogleFonts.poppins(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  m.subtitle,
                                  style: GoogleFonts.poppins(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                () => setState(() => _methods.removeAt(i)),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF5E5B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            BrandButton(
              text: 'Add New Payment Method',
              icon: Icons.add_card_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'New payment method flow can be connected to backend.',
                      style: GoogleFonts.poppins(),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PaymentMethod(this.title, this.subtitle, this.icon, this.color);
}
