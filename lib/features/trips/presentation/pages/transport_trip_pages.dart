import 'package:flutter/material.dart';

import '../../../../pages/passenger/public_bus_booking_page.dart';
import 'create_trip_page.dart';

class PublicTransportTripPage extends StatelessWidget {
  const PublicTransportTripPage({super.key});

  @override
  Widget build(BuildContext context) => const PublicBusBookingPage();
}

class PrivateTransportTripPage extends StatelessWidget {
  const PrivateTransportTripPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: _TripModeAppBar(title: 'Private Trip'),
    body: CreateTripPage(),
  );
}

class MotoTripPage extends StatelessWidget {
  const MotoTripPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: _TripModeAppBar(title: 'Moto Trip'),
    body: CreateTripPage(),
  );
}

class _TripModeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TripModeAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: Text(title));
}
