// lib/screens/passenger/book_ride_screen.dart
// Trip creation form with exact field mapping

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/trip_service_v2.dart';
import 'passenger_tracking_screen.dart';

class BookRideScreen extends StatefulWidget {
  final int passengerId;
  final String authToken;

  const BookRideScreen({
    super.key,
    required this.passengerId,
    required this.authToken,
  });

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  double? _pickupLat, _pickupLng;
  double? _dropoffLat, _dropoffLng;
  String _selectedTransportType = 'moto';
  String _selectedPaymentMethod = 'cash';
  bool _isLoading = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  double _estimateFare() {
    const baseMap = {'moto': 1200.0, 'car': 2500.0, 'bus': 600.0};
    return baseMap[_selectedTransportType] ?? 2500.0;
  }

  Future<void> _onBookRide() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set pickup location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dropoffLat == null || _dropoffLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set dropoff location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      const uuid = Uuid();
      final idempotencyKey = uuid.v4();

      final service = TripServiceV2(authToken: widget.authToken);
      final trip = await service.createTrip(
        passengerId: widget.passengerId,
        pickupLocation: _pickupController.text.trim(),
        dropoffLocation: _dropoffController.text.trim(),
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        dropoffLat: _dropoffLat!,
        dropoffLng: _dropoffLng!,
        transportType: _selectedTransportType,
        paymentMethod: _selectedPaymentMethod,
        pickupPlaceName: _pickupController.text.trim(),
        dropoffPlaceName: _dropoffController.text.trim(),
        idempotencyKey: idempotencyKey,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => PassengerTrackingScreen(
                  trip: trip,
                  authToken: widget.authToken,
                ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Ride')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup location
              Text(
                '📍 Pickup Location',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pickupController,
                decoration: InputDecoration(
                  hintText: 'Enter pickup location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator:
                    (v) =>
                        v?.trim().isEmpty ?? true
                            ? 'Pickup location required (min 3 chars)'
                            : v!.length < 3
                            ? 'Pickup location too short'
                            : null,
              ),
              if (_pickupLat != null && _pickupLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lat: ${_pickupLat!.toStringAsFixed(4)} | Lng: ${_pickupLng!.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),

              // Dropoff location
              Text(
                '🏁 Dropoff Location',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dropoffController,
                decoration: InputDecoration(
                  hintText: 'Enter dropoff location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator:
                    (v) =>
                        v?.trim().isEmpty ?? true
                            ? 'Dropoff location required (min 3 chars)'
                            : v!.length < 3
                            ? 'Dropoff location too short'
                            : null,
              ),
              if (_dropoffLat != null && _dropoffLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lat: ${_dropoffLat!.toStringAsFixed(4)} | Lng: ${_dropoffLng!.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),

              // Transport type
              Text(
                '🚗 Transport Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    ['moto', 'car', 'bus'].map((type) {
                      final icons = {'moto': '🏍️', 'car': '🚗', 'bus': '🚌'};
                      return FilterChip(
                        label: Text('${icons[type]} ${type.toUpperCase()}'),
                        selected: _selectedTransportType == type,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedTransportType = type);
                          }
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              // Payment method
              Text(
                '💳 Payment Method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    ['cash', 'momo', 'card'].map((method) {
                      return FilterChip(
                        label: Text(method.toUpperCase()),
                        selected: _selectedPaymentMethod == method,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPaymentMethod = method);
                          }
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              // Estimated fare
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Fare:'),
                    Text(
                      'RWF ${_estimateFare().toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Book button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onBookRide,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Book Trip'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
