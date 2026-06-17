// lib/screens/passenger/payments_screen.dart
// Payment history & wallet – GET /api/v1/passenger/payments/history

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
  Color get _card => _isDark ? const Color(0xFF141829) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? Colors.white70 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await PassengerApi.instance.getPaymentHistory();
      if (!mounted) return;
      setState(() { _payments = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double get _totalSpent {
    double total = 0;
    for (final p in _payments) {
      final amt = _parseNum(p['amount'] ?? p['fare'] ?? p['total']);
      total += amt;
    }
    return total;
  }

  double _parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Payments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 56),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchPayments,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: _fetchPayments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Summary card ─────────────────────────────────────────────────
          _buildSummaryCard(),
          const SizedBox(height: 16),

          // ── Payment methods ──────────────────────────────────────────────
          _buildPaymentMethods(),
          const SizedBox(height: 20),

          // ── Transaction history header ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_payments.length} transactions',
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Transactions ────────────────────────────────────────────────
          if (_payments.isEmpty)
            _buildEmpty()
          else
            ..._payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaymentCard(
                payment: p,
                isDark: _isDark,
                card: _card,
                textPrimary: _textPrimary,
                textSecondary: _textSecondary,
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(
                'Total Spent',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'RWF ${_totalSpent.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_payments.length} trips completed',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _PaymentMethodTile(
            icon: Icons.money_rounded,
            label: 'Cash',
            subtitle: 'Pay with cash',
            active: true,
            isDark: _isDark,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
          ),
          const SizedBox(height: 8),
          _PaymentMethodTile(
            icon: Icons.phone_android_rounded,
            label: 'Mobile Money',
            subtitle: 'MTN MoMo / Airtel Money',
            active: false,
            isDark: _isDark,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mobile Money integration coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 72,
                color: _isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: GoogleFonts.poppins(
                color: _isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.active,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool active;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: GoogleFonts.poppins(color: textSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (active)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });
  final Map<String, dynamic> payment;
  final bool isDark;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final amt = _parseNum(payment['amount'] ?? payment['fare'] ?? payment['total']);
    final status = (payment['status'] ?? 'completed').toString();
    final method = payment['payment_method']?.toString()
        ?? payment['method']?.toString()
        ?? 'Cash';
    final createdAt = payment['created_at']?.toString() ?? '';
    final tripId = payment['trip_id'] ?? payment['ride_id'] ?? '';

    final isCompleted = status.toLowerCase() == 'completed'
        || status.toLowerCase() == 'paid';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? const [Color(0xFF10B981), Color(0xFF34D399)]
                    : const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tripId.toString().isNotEmpty ? 'Trip #$tripId' : 'Payment',
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      method,
                      style: GoogleFonts.poppins(color: textSecondary, fontSize: 11),
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: textSecondary, fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.poppins(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            'RWF ${amt.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              color: const Color(0xFF6C63FF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  double _parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month-1]}';
    } catch (_) { return raw; }
  }
}
