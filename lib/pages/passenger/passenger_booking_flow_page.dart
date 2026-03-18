import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/passenger_language_service.dart';
import 'book_ride_page.dart';
import 'immediate_trip_request_page.dart';

class PassengerBookingFlowPage extends StatefulWidget {
  final VoidCallback? onBookingCompleted;

  const PassengerBookingFlowPage({super.key, this.onBookingCompleted});

  @override
  State<PassengerBookingFlowPage> createState() =>
      _PassengerBookingFlowPageState();
}

class _PassengerBookingFlowPageState extends State<PassengerBookingFlowPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final PassengerLanguageService _lang = PassengerLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          color: const Color(0xFF0F1428),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF6C63FF), Color(0xFF3B82F6)],
                ),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              tabs: <Widget>[
                Tab(text: _lang.t('book.scheduled')),
                Tab(text: _lang.t('book.immediate')),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              BookRidePage(onBookingCompleted: widget.onBookingCompleted),
              ImmediateTripRequestPage(
                onRequestLifecycleUpdate: widget.onBookingCompleted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
