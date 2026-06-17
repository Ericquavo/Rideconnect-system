import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/trip_models.dart';
import '../providers/trips_provider.dart';
import '../../../auth/presentation/widgets/error_dialog.dart';

/// Trip Completion Page - Rating and review screen
class TripCompletionPage extends ConsumerStatefulWidget {
  final int tripId;
  final TripData? tripData;

  const TripCompletionPage({
    super.key,
    required this.tripId,
    this.tripData,
  });

  @override
  ConsumerState<TripCompletionPage> createState() => _TripCompletionPageState();
}

class _TripCompletionPageState extends ConsumerState<TripCompletionPage> {
  int _rating = 0;
  late TextEditingController _reviewController;
  int _tip = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating(TripData data) async {
    if (_rating == 0) {
      _showErrorDialog('Please rate the driver');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ratingRequest = RatingRequest(
        rating: _rating,
        review:
            _reviewController.text.isNotEmpty ? _reviewController.text : null,
        tip: _tip > 0 ? _tip : null,
      );

      final repository = ref.read(tripsRepositoryProvider);
      await repository.rateTrip(widget.tripId, ratingRequest, data.transportType);

      if (mounted) {
        _showSuccessDialog('Thank you for rating!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(message: message),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => SuccessDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    TripData? resolvedTripData = widget.tripData;
    
    if (resolvedTripData == null) {
      final asyncData = ref.watch(tripDetailsProvider(widget.tripId));
      return asyncData.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      );
    }
    
    return _buildContent(context, resolvedTripData);
  }

  Widget _buildContent(BuildContext context, TripData data) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Trip Completed',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF4C57D6),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Success indicator
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trip Completed Successfully',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thank you for using RideConnect',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Trip summary
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    icon: Icons.location_on,
                    label: 'From',
                    value: data.originAddress,
                  ),
                  const SizedBox(height: 8),
                  _SummaryCard(
                    icon: Icons.location_on,
                    label: 'To',
                    value: data.destinationAddress,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Fare',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${data.actualFare ?? data.estimatedFare}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4C57D6),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Payment Status',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Paid',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Rating section
                  Text(
                    'Rate Your Driver',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            _rating > index ? Icons.star : Icons.star_outline,
                            size: 40,
                            color:
                                _rating > index
                                    ? Colors.orange
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Review text field
                  Text(
                    'Additional Comments (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tip section
                  Text(
                    'Add Tip (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...[100, 200, 500].map(
                        (tipAmount) => Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _tip = tipAmount);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      _tip == tipAmount
                                          ? const Color(0xFF4C57D6)
                                          : Colors.grey.shade300,
                                  width: _tip == tipAmount ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color:
                                    _tip == tipAmount
                                        ? const Color(
                                          0xFF4C57D6,
                                        ).withOpacity(0.05)
                                        : Colors.transparent,
                              ),
                              child: Text(
                                '₦$tipAmount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _tip == tipAmount
                                          ? const Color(0xFF4C57D6)
                                          : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Submit button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitRating(data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C57D6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                          : Text(
                            'Submit Rating',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4C57D6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
