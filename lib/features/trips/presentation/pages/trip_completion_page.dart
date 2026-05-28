import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trip_providers.dart';
import '../widgets/trip_error_view.dart';

class TripCompletionPage extends ConsumerStatefulWidget {
  const TripCompletionPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripCompletionPage> createState() => _TripCompletionPageState();
}

class _TripCompletionPageState extends ConsumerState<TripCompletionPage> {
  int _rating = 5;
  bool _submittingPayment = false;
  bool _submittingRating = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(tripTrackingProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Complete')),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => TripErrorView(
              message: e.toString(),
              onRetry:
                  () =>
                      ref
                          .read(tripTrackingProvider(widget.tripId).notifier)
                          .refresh(),
            ),
        data:
            (data) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 60,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                Text('Fare: ${data.trip.fare.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      _submittingPayment
                          ? null
                          : () async {
                            setState(() => _submittingPayment = true);
                            try {
                              await ref
                                  .read(tripRepositoryProvider)
                                  .createPayment(
                                    tripId: widget.tripId,
                                    amount: data.trip.fare,
                                    method: 'cash',
                                  );
                              setState(() => _message = 'Payment recorded.');
                            } catch (e) {
                              setState(() => _message = e.toString());
                            } finally {
                              if (mounted) {
                                setState(() => _submittingPayment = false);
                              }
                            }
                          },
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Confirm Payment'),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      onPressed: () => setState(() => _rating = value),
                      icon: Icon(
                        value <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFBBF24),
                      ),
                    );
                  }),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _submittingRating
                          ? null
                          : () async {
                            setState(() => _submittingRating = true);
                            try {
                              await ref
                                  .read(tripRepositoryProvider)
                                  .storePublicTransportFeedback(
                                    tripId: widget.tripId,
                                    rating: _rating,
                                  );
                              setState(() => _message = 'Rating submitted.');
                            } catch (e) {
                              setState(() => _message = e.toString());
                            } finally {
                              if (mounted) {
                                setState(() => _submittingRating = false);
                              }
                            }
                          },
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Submit Rating'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, textAlign: TextAlign.center),
                ],
              ],
            ),
      ),
    );
  }
}
