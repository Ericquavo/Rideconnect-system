import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_language_service.dart';

class DriverHelpPage extends StatefulWidget {
  const DriverHelpPage({super.key});

  @override
  State<DriverHelpPage> createState() => _DriverHelpPageState();
}

class _DriverHelpPageState extends State<DriverHelpPage> {
  final DriverLanguageService _lang = DriverLanguageService.instance;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
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
  Color get _textMuted =>
      _isDarkMode ? Colors.white70 : const Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgTop,
        title: Text(
          _lang.t('help.title'),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _sectionCard(
                title: _lang.t('help.faq'),
                icon: Icons.quiz_rounded,
                child: Column(
                  children: [
                    _FaqItem(
                      isDarkMode: _isDarkMode,
                      question: _lang.t('help.q1'),
                      answer: _lang.t('help.a1'),
                    ),
                    _FaqItem(
                      isDarkMode: _isDarkMode,
                      question: _lang.t('help.q2'),
                      answer: _lang.t('help.a2'),
                    ),
                    _FaqItem(
                      isDarkMode: _isDarkMode,
                      question: _lang.t('help.q3'),
                      answer: _lang.t('help.a3'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                title: _lang.t('help.contact'),
                icon: Icons.support_agent_rounded,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.call_rounded,
                        color: Color(0xFF6C63FF),
                      ),
                      title: Text(
                        _lang.t('help.callSupport'),
                        style: GoogleFonts.poppins(
                          color: _textMuted,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '+250 700 000 000',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap:
                          () => _showAction(
                            context,
                            _lang.t('help.connectingCall'),
                          ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.email_rounded,
                        color: Color(0xFF6C63FF),
                      ),
                      title: Text(
                        _lang.t('help.emailSupport'),
                        style: GoogleFonts.poppins(
                          color: _textMuted,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'support@rideconnect.com',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap:
                          () => _showAction(
                            context,
                            _lang.t('help.openingEmail'),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      () =>
                          _showAction(context, _lang.t('help.issueSubmitted')),
                  icon: const Icon(Icons.bug_report_rounded),
                  label: Text(
                    _lang.t('help.reportProblem'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
}

class _FaqItem extends StatelessWidget {
  final bool isDarkMode;
  final String question;
  final String answer;

  const _FaqItem({
    required this.isDarkMode,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: const Color(0xFF6C63FF),
        collapsedIconColor: const Color(0xFF6C63FF),
        title: Text(
          question,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : const Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
            child: Text(
              answer,
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white54 : const Color(0xFF475569),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
