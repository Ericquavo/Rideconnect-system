// lib/screens/passenger/rate_driver_screen.dart
// Driver rating screen – POST /api/v1/passenger/motor-vehicle/trip-requests/:id/rate

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class RateDriverScreen extends StatefulWidget {
  final int tripId;
  final bool isMotorVehicle;

  const RateDriverScreen({
    super.key,
    required this.tripId,
    this.isMotorVehicle = true,
  });

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _submitted = false;

  late AnimationController _starAnim;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
  Color get _card => _isDark ? const Color(0xFF141829) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? Colors.white70 : const Color(0xFF475569);

  static const _tags = [
    'Great Driver', 'Safe Driving', 'Friendly', 'On Time',
    'Clean Vehicle', 'Smooth Ride',
  ];
  final _selectedTags = <String>{};

  @override
  void initState() {
    super.initState();
    _starAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _starAnim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a star rating.');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    try {
      final payload = {
        'rating': _rating,
        if (_commentCtrl.text.trim().isNotEmpty) 'comment': _commentCtrl.text.trim(),
        if (_selectedTags.isNotEmpty) 'tags': _selectedTags.toList(),
      };

      if (widget.isMotorVehicle) {
        // POST /api/v1/passenger/motor-vehicle/trip-requests/:id/rate
        await PassengerApi.instance.post(
          '/motor-vehicle/trip-requests/${widget.tripId}/rate',
          payload,
        );
      } else {
        // Generic trip rating
        await PassengerApi.instance.post(
          '/trips/${widget.tripId}/rate',
          payload,
        );
      }

      if (!mounted) return;
      setState(() { _submitted = true; _submitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          _submitted ? 'Thank You!' : 'Rate Your Trip',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                ),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 24),
            Text(
              'Rating Submitted!',
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Icon(
                i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B),
                size: 30,
              )),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for your feedback!',
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Back to Home',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                // Driver avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    ),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 12),
                Text(
                  'How was your trip?',
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Trip #${widget.tripId}',
                  style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // ── Star rating ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _rating = i + 1;
                        _starAnim.forward(from: 0);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: filled ? const Color(0xFFF59E0B) : Colors.grey,
                          size: 38,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _ratingLabel(),
                  style: GoogleFonts.poppins(
                    color: _ratingLabelColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Quick tags ────────────────────────────────────────────────────
          Text(
            'What went well?',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C63FF)
                        : _isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6C63FF)
                          : _isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Comment box ───────────────────────────────────────────────────
          Text(
            'Additional comments (optional)',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell us more about your experience…',
              hintStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
              ),
            ),
            style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // ── Error ─────────────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontSize: 13),
              ),
            ),

          const SizedBox(height: 16),

          // ── Submit button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Submit Rating',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  color: _textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1: return 'Very Bad 😞';
      case 2: return 'Bad 😕';
      case 3: return 'Okay 😐';
      case 4: return 'Good 😊';
      case 5: return 'Excellent! 🌟';
      default: return 'Tap a star to rate';
    }
  }

  Color _ratingLabelColor() {
    switch (_rating) {
      case 1:
      case 2: return const Color(0xFFEF4444);
      case 3: return const Color(0xFFF59E0B);
      case 4:
      case 5: return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }
}
