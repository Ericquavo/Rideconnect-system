import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class RateAppPage extends StatefulWidget {
  const RateAppPage({super.key});

  @override
  State<RateAppPage> createState() => _RateAppPageState();
}

class _RateAppPageState extends State<RateAppPage> {
  int _rating = 0;
  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Rate RideConnect',
      icon: Icons.star_outline_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            SettingsCard(
              child: Column(
                children: [
                  Text(
                    'How was your experience?',
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final filled = index < _rating;
                      return IconButton(
                        onPressed: () => setState(() => _rating = index + 1),
                        icon: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color:
                              filled
                                  ? const Color(0xFFFBBF24)
                                  : palette.textMuted,
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _feedbackCtrl,
                    maxLines: 4,
                    style: GoogleFonts.poppins(
                      color: palette.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tell us what we can improve...',
                      hintStyle: GoogleFonts.poppins(color: palette.textMuted),
                      filled: true,
                      fillColor: palette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: Color(0xFF6C63FF),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BrandButton(
              text: 'Submit Review',
              icon: Icons.send_rounded,
              onPressed: () {
                setState(() => _submitted = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      'Thank you for helping improve RideConnect.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              },
            ),
            if (_submitted) ...[
              const SizedBox(height: 10),
              Text(
                'Thank you for helping improve RideConnect.',
                style: GoogleFonts.poppins(
                  color: palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
