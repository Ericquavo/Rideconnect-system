import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';

class DriverBookingQueuePage extends StatefulWidget {
  const DriverBookingQueuePage({super.key});

  @override
  State<DriverBookingQueuePage> createState() => _DriverBookingQueuePageState();
}

class _DriverBookingQueuePageState extends State<DriverBookingQueuePage> {
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverApi _api = DriverApi.instance;

  bool _loading = true;
  bool _actionBusy = false;
  String? _error;
  List<Map<String, dynamic>> _bookings = <Map<String, dynamic>>[];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDark ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _cardBg =>
      _isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFC9D6F2);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDark ? Colors.white54 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _loadBookings();
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

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getBookings();
      if (!mounted) return;
      setState(() {
        _bookings = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm(
    dynamic bookingId, {
    required String passengerId,
    required String passengerName,
    required String pickup,
    required String dropoff,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _api.confirmBooking(bookingId);
      await _api.notifyPassengerDecision(
        passengerId: passengerId,
        accepted: true,
        bookingDecision: true,
        passengerName: passengerName,
        referenceId: '$bookingId',
        pickup: pickup,
        dropoff: dropoff,
      );
      if (!mounted) return;
      await _loadBookings();
      _showSnack(_lang.t('bookings.confirmed'));
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancel(
    dynamic bookingId, {
    required String passengerId,
    required String passengerName,
    required String pickup,
    required String dropoff,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _api.cancelBooking(bookingId);
      await _api.notifyPassengerDecision(
        passengerId: passengerId,
        accepted: false,
        bookingDecision: true,
        passengerName: passengerName,
        referenceId: '$bookingId',
        pickup: pickup,
        dropoff: dropoff,
      );
      if (!mounted) return;
      await _loadBookings();
      _showSnack(_lang.t('bookings.cancelled'));
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            _isDark ? const Color(0xFF131729) : const Color(0xFFF8FAFF),
        content: Text(
          text,
          style: GoogleFonts.poppins(
            color: _isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            color: const Color(0xFF6C63FF),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: <Widget>[
                _header(),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  )
                else if (_error != null)
                  _errorCard()
                else if (_bookings.isEmpty)
                  _emptyCard()
                else
                  ..._bookings.map(_bookingCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.book_online_rounded,
            color: Color(0xFF6C63FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _lang.t('bookings.title'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          children: <Widget>[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadBookings,
              child: Text(_lang.t('common.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        _lang.t('bookings.empty'),
        style: GoogleFonts.poppins(color: _textSecondary),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> item) {
    final id = _api.readString(item, const ['id', 'booking_id']);
    final idLabel = id.isEmpty ? '--' : id;
    final passengerId = _api.readString(item, const [
      'passenger_id',
      'user_id',
      'rider_id',
      'passengerId',
    ]);
    final passenger = _api.readString(item, const [
      'passenger_name',
      'passenger',
      'name',
    ], fallback: _lang.t('home.requestPassenger'));
    final pickup = _api.readString(item, const [
      'pickup_address',
      'pickup',
      'pickup_location',
    ], fallback: _lang.t('home.requestPickupMissing'));
    final dropoff = _api.readString(item, const [
      'dropoff_address',
      'destination',
      'dropoff_location',
    ], fallback: _lang.t('home.requestDestinationMissing'));
    final seats = _api.readInt(item, const [
      'seats',
      'seats_booked',
    ], fallback: 1);
    final statusRaw = _api.readString(item, const [
      'status',
    ], fallback: 'pending');
    final fare = _api.readDouble(item, const [
      'total_price',
      'fare',
      'price',
    ], fallback: 0);

    final normalizedStatus = statusRaw.toLowerCase();
    final actionAllowed =
        id.isNotEmpty &&
        (normalizedStatus.contains('pending') ||
            normalizedStatus.contains('request'));
    final statusColor = _statusColor(normalizedStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$passenger  #$idLabel',
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(normalizedStatus),
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_lang.t('trips.pickup')}: $pickup',
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
          ),
          Text(
            '${_lang.t('trips.dropoff')}: $dropoff',
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '${_lang.t('book.seats')}: $seats • ${_lang.t('request.fare')}: \$${fare.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      actionAllowed && !_actionBusy
                          ? () => _cancel(
                            id,
                            passengerId: passengerId,
                            passengerName: passenger,
                            pickup: pickup,
                            dropoff: dropoff,
                          )
                          : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF5E5B)),
                  ),
                  child: Text(
                    _lang.t('bookings.cancel'),
                    style: GoogleFonts.poppins(color: const Color(0xFFFF5E5B)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      actionAllowed && !_actionBusy
                          ? () => _confirm(
                            id,
                            passengerId: passengerId,
                            passengerName: passenger,
                            pickup: pickup,
                            dropoff: dropoff,
                          )
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _lang.t('bookings.confirm'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    if (status.contains('confirm')) return _lang.t('bookings.confirmedStatus');
    if (status.contains('cancel')) return _lang.t('bookings.cancelledStatus');
    return _lang.t('bookings.pendingStatus');
  }

  Color _statusColor(String status) {
    if (status.contains('confirm')) return const Color(0xFF10B981);
    if (status.contains('cancel')) return const Color(0xFFFF5E5B);
    return const Color(0xFF3B82F6);
  }
}
