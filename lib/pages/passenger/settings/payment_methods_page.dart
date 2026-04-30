import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/passenger_language_service.dart';
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

  Future<void> _openMobileMoneyFlow() async {
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1428),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Money Payment',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    filled: true,
                    fillColor: Color(0x1FFFFFFF),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: r'$ ',
                    filled: true,
                    fillColor: Color(0x1FFFFFFF),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final phone = phoneCtrl.text.trim();
                          final amount =
                              double.tryParse(amountCtrl.text.trim()) ?? 0;
                          final validPhone = phone.length >= 10;
                          if (!validPhone || amount <= 0) {
                            Navigator.pop(context, false);
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        child: const Text('Pay now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    phoneCtrl.dispose();
    amountCtrl.dispose();

    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? 'Payment request submitted successfully.'
              : 'Payment failed. Check number and amount then try again.',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result ? const Color(0xFF10B981) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final lang = PassengerLanguageService.instance;
    return SettingsPageLayout(
      title: lang.t('settings.paymentMethods'),
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
                    child: GestureDetector(
                      onTap:
                          m.title.toLowerCase().contains('mobile money')
                              ? _openMobileMoneyFlow
                              : null,
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
                    ),
                  );
                },
              ),
            ),
            BrandButton(
              text: lang.t('payment.addMethod'),
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
