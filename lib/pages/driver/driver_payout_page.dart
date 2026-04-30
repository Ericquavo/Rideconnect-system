import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

class PayoutPage extends StatefulWidget {
  const PayoutPage({super.key});

  @override
  State<PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends State<PayoutPage> {
  final DriverLanguageService _lang = DriverLanguageService.instance;
  String _selectedMethod = 'Mobile Money';
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountNumberController;
  bool _loading = true;
  bool _savingPayout = false;
  double _availableBalance = 0;
  double _weekEarnings = 0;
  double _pendingPayout = 0;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFEFF4FF);
  Color get _cardBg =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFC9D6F2);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _accountNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final api = DriverApi.instance;
      final earningsResponse = await api.getEarnings();
      final profileResponse = await api.getProfile();

      final earnings = api.extractDataMap(earningsResponse);
      final profile = api.extractDataMap(profileResponse);

      final payoutRaw = profile['payout'];
      final payout =
          payoutRaw is Map<String, dynamic> ? payoutRaw : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _availableBalance = api.readDouble(earnings, const [
          'available_balance',
          'available',
          'balance',
        ]);
        _weekEarnings = api.readDouble(earnings, const [
          'week',
          'weekly',
          'this_week',
        ]);
        _pendingPayout = api.readDouble(earnings, const [
          'pending_payout',
          'pending',
        ]);

        _selectedMethod = api.readString(payout, const [
          'method',
          'type',
        ], fallback: _selectedMethod);
        _accountNameController.text = api.readString(payout, const [
          'account_name',
          'holder_name',
          'name',
        ], fallback: api.readString(profile, const ['name']));
        _accountNumberController.text = api.readString(payout, const [
          'account_number',
          'number',
          'mobile_number',
        ]);

        if (!const ['Mobile Money', 'Bank Account'].contains(_selectedMethod)) {
          _selectedMethod = 'Mobile Money';
        }

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _savePayoutMethod() async {
    setState(() => _savingPayout = true);
    try {
      await DriverApi.instance.updateProfile({
        'payout': {
          'method': _selectedMethod,
          'account_name': _accountNameController.text.trim(),
          'account_number': _accountNumberController.text.trim(),
        },
      });
      DriverSyncService.instance.bumpDataVersion();
      if (!mounted) return;
      _showSuccess(_lang.t('payout.updated'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF5E5B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingPayout = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgTop,
        title: Text(
          _lang.t('payout.title'),
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child:
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        _summaryCard(),
                        const SizedBox(height: 14),
                        _methodCard(),
                        const SizedBox(height: 14),
                        _withdrawCard(),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return _card(
      title: _lang.t('payout.earningsAccount'),
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _valueRow(
            _lang.t('payout.availableBalance'),
            '\$${_availableBalance.toStringAsFixed(2)}',
          ),
          _valueRow(
            _lang.t('payout.thisWeek'),
            '\$${_weekEarnings.toStringAsFixed(2)}',
          ),
          _valueRow(
            _lang.t('payout.pendingPayout'),
            '\$${_pendingPayout.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _methodCard() {
    return _card(
      title: _lang.t('payout.methodTitle'),
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedMethod,
            dropdownColor: _isDarkMode ? const Color(0xFF1A1F3A) : Colors.white,
            iconEnabledColor: const Color(0xFF6C63FF),
            style: GoogleFonts.poppins(color: _textPrimary),
            decoration: _inputDecoration(_lang.t('payout.paymentMethod')),
            items: [
              DropdownMenuItem(
                value: 'Mobile Money',
                child: Text(_lang.t('payout.mobileMoney')),
              ),
              DropdownMenuItem(
                value: 'Bank Account',
                child: Text(_lang.t('payout.bankAccount')),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedMethod = value);
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _accountNameController,
            style: GoogleFonts.poppins(color: _textPrimary),
            decoration: _inputDecoration(_lang.t('payout.accountHolder')),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _accountNumberController,
            style: GoogleFonts.poppins(color: _textPrimary),
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              _selectedMethod == 'Mobile Money'
                  ? _lang.t('payout.mobileNumber')
                  : _lang.t('payout.bankAccountNumber'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingPayout ? null : _savePayoutMethod,
              icon: const Icon(Icons.sync_alt_rounded),
              label:
                  _savingPayout
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        _lang.t('payout.addOrUpdate'),
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

  Widget _withdrawCard() {
    return _card(
      title: _lang.t('payout.withdrawalTitle'),
      icon: Icons.outbox_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lang.t('payout.withdrawalHint'),
            style: GoogleFonts.poppins(
              color: _isDarkMode ? Colors.white60 : const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  () => _showSuccess(_lang.t('payout.withdrawalSubmitted')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _lang.t('payout.requestWithdrawal'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
      filled: true,
      fillColor:
          _isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.2),
      ),
    );
  }
}
