import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_models.dart';
import '../providers/trip_providers.dart';

class TripPaymentPage extends ConsumerStatefulWidget {
  const TripPaymentPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripPaymentPage> createState() => _TripPaymentPageState();
}

class _TripPaymentPageState extends ConsumerState<TripPaymentPage> {
  String _selectedMethod = 'CASH';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  int _rating = 5;
  bool _isPaying = false;
  bool _isRating = false;
  double _tripFare = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
  }

  Future<void> _fetchTripDetails() async {
    try {
      final trip = await ref.read(tripRepositoryProvider).passengerTrip(widget.tripId);
      setState(() {
        _tripFare = trip.fare;
        _amountController.text = trip.fare > 0 ? trip.fare.toStringAsFixed(0) : '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _processPaymentAndRating() async {
    final amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    if (_selectedMethod.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.')),
      );
      return;
    }

    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating between 1 and 5.')),
      );
      return;
    }

    final commentText = _commentsController.text.trim();
    if (commentText.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot exceed 1000 characters.')),
      );
      return;
    }

    setState(() {
      _isPaying = true;
      _isRating = true;
    });

    try {
      // 1. Process payment
      await ref.read(tripRepositoryProvider).createPayment(
        tripId: widget.tripId,
        amount: amount,
        method: _selectedMethod,
      );

      // 2. Submit rating feedback
      await ref.read(tripRepositoryProvider).storePublicTransportFeedback(
        tripId: widget.tripId,
        rating: _rating,
        comment: commentText.isNotEmpty ? commentText : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment and rating submitted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Finalize flow: redirect back to home page/dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _isRating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => false, // Prevent physical back navigation
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Payment & Feedback',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Fare Summary Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Trip Fare',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tripFare > 0 ? 'RWF ${_tripFare.toStringAsFixed(0)}' : '--',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Section
            Text(
              'Select Payment Method',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMethodTile('CASH', Icons.payments, isDark),
                const SizedBox(width: 12),
                _buildMethodTile('CARD', Icons.credit_card, isDark),
                const SizedBox(width: 12),
                _buildMethodTile('MOBILE_MONEY', Icons.phone_android, isDark),
              ],
            ),
            const SizedBox(height: 24),

            // Amount Input Field
            Text(
              'Amount to Pay',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'RWF ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Rating Section
            Text(
              'Rate Your Experience',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => GestureDetector(
                  onTap: () {
                    setState(() => _rating = index + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      _rating > index ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 42,
                      color: _rating > index ? Colors.orange : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Comments/Reviews
            Text(
              'Comments (Optional)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your feedback...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // Confirm Pay Action
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPaying ? null : _processPaymentAndRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isPaying
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Confirm & Pay',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile(String method, IconData icon, bool isDark) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.15) : Colors.transparent,
            border: Border.all(
              color: isSelected ? const Color(0xFF6C63FF) : (isDark ? Colors.white24 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF6C63FF) : Colors.grey, size: 24),
              const SizedBox(height: 6),
              Text(
                method.split('_').first,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
