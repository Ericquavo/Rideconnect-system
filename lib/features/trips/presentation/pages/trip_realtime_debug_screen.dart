import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trip_realtime_notifier.dart';

/// Debug screen for testing Firestore realtime events
///
/// Features:
/// - Enter tripId to connect
/// - Display raw Firestore events
/// - Show connection status
/// - Monitor event timestamps
class TripRealtimeDebugScreen extends ConsumerStatefulWidget {
  const TripRealtimeDebugScreen({super.key});

  @override
  ConsumerState<TripRealtimeDebugScreen> createState() =>
      _TripRealtimeDebugScreenState();
}

class _TripRealtimeDebugScreenState
    extends ConsumerState<TripRealtimeDebugScreen> {
  final TextEditingController _tripIdController = TextEditingController();
  int? _connectedTripId;

  @override
  void dispose() {
    _tripIdController.dispose();
    super.dispose();
  }

  void _connectToTrip() {
    final tripIdStr = _tripIdController.text.trim();
    if (tripIdStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a trip ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tripId = int.tryParse(tripIdStr);
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid trip ID (must be a number)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _connectedTripId = tripId);
  }

  void _disconnect() {
    setState(() => _connectedTripId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Realtime Debug'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip ID Input Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to Trip',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tripIdController,
                            enabled: _connectedTripId == null,
                            decoration: InputDecoration(
                              hintText: 'Enter Trip ID (e.g., 123)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_connectedTripId == null)
                          ElevatedButton.icon(
                            onPressed: _connectToTrip,
                            icon: const Icon(Icons.connect_without_contact),
                            label: const Text('Connect'),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.close),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    if (_connectedTripId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Chip(
                          label: Text('Connected to Trip: $_connectedTripId'),
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Events Display Section
            if (_connectedTripId != null)
              _EventsDisplay(tripId: _connectedTripId!)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enter a trip ID and connect to see events',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display realtime events
class _EventsDisplay extends ConsumerWidget {
  final int tripId;

  const _EventsDisplay({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeState = ref.watch(tripRealtimeNotifierProvider(tripId));

    return realtimeState.when(
      data:
          (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  state.isConnected ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              color:
                                  state.isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Error: ${state.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Current Event Section
              if (state.currentEvent != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Event',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Chip(
                              label: Text(state.currentEvent!.event),
                              backgroundColor: _getEventColor(
                                state.currentEvent!.event,
                              ),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EventDetailRow(
                          'Event Type',
                          state.currentEvent!.event,
                        ),
                        _EventDetailRow(
                          'Trip ID',
                          state.currentEvent!.tripId.toString(),
                        ),
                        _EventDetailRow(
                          'Timestamp',
                          state.currentEvent!.timestamp.toString(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Payload:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              _formatPayload(state.currentEvent!.payload),
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Card(
                  color: Colors.grey[100],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Waiting for events...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => Card(
            color: Colors.red[50],
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Loading Events',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'DriverAssigned':
        return Colors.blue;
      case 'DriverAccepted':
        return Colors.green;
      case 'DriverArrived':
        return Colors.orange;
      case 'TripStarted':
        return Colors.purple;
      case 'TripCompleted':
        return Colors.greenAccent;
      case 'TripCancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatPayload(Map<String, dynamic> payload) {
    return payload.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}

class _EventDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _EventDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
