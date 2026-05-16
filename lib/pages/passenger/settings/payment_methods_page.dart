import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/passenger_language_service.dart';
import '../../../services/passenger_api.dart';
import 'settings_theme.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  String _selectedMethod = 'cash';
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountNumberController;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final resp = await PassengerApi.instance.getProfile();
      final data = resp['data'];
      final profile =
          data is Map<String, dynamic>
              ? (data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : data)
              : <String, dynamic>{};

      final paymentRaw = profile['payment'];
      final payment =
          paymentRaw is Map<String, dynamic> ? paymentRaw : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _selectedMethod =
            (payment['method'] ?? payment['type'] ?? 'cash').toString();
        _accountNameController.text =
            (payment['account_name'] ?? payment['holder_name'] ?? '')
                .toString();
        _accountNumberController.text =
            (payment['account_number'] ??
                    payment['number'] ??
                    payment['mobile_number'] ??
                    '')
                .toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PassengerApi.instance.updateProfile({
        'payment': {
          'method': _selectedMethod,
          'account_name': _accountNameController.text.trim(),
          'account_number': _accountNumberController.text.trim(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment method saved.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF5E5B),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        child:
            _loading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                )
                : Column(
                  children: [
                    _methodCard(palette, lang),
                    const SizedBox(height: 16),
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

  Widget _methodCard(SettingsPalette palette, PassengerLanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = palette.textPrimary;
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedMethod,
            dropdownColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
            iconEnabledColor: const Color(0xFF6C63FF),
            style: GoogleFonts.poppins(color: textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'mobile_money',
                child: Text('Mobile Money'),
              ),
              DropdownMenuItem(
                value: 'bank_account',
                child: Text('Bank Account'),
              ),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedMethod = v);
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _accountNameController,
            style: GoogleFonts.poppins(color: textPrimary),
            decoration: InputDecoration(
              labelText:
                  _selectedMethod == 'bank_account'
                      ? lang.t('payout.accountHolder')
                      : 'Account / Holder',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _accountNumberController,
            style: GoogleFonts.poppins(color: textPrimary),
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText:
                  _selectedMethod == 'mobile_money'
                      ? lang.t('payout.mobileNumber')
                      : lang.t('payout.bankAccountNumber'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.sync_alt_rounded),
              label:
                  _saving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        'Save',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF), width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Payment method helper removed; UI now mirrors driver payout flow.
