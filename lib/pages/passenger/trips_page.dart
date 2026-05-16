import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import 'book_ride_page.dart';
import '../../features/trips/data/passenger_trips_api_service.dart';
import '../../services/passenger_language_service.dart';
import '../../services/currency_formatter.dart';

class TripsPage extends StatefulWidget {
  final int bookingSuccessNonce;

  const TripsPage({super.key, this.bookingSuccessNonce = 0});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage>
    with SingleTickerProviderStateMixin {
  PassengerLanguageService get _lang => PassengerLanguageService.instance;
  late TabController _tabController;
  int _lastShownBookingNonce = 0;
  bool _highlightNewestActive = false;

  bool _isLoading = true;
  String? _error;
  String? _rawError;
  List<Map<String, dynamic>> _trips = <Map<String, dynamic>>[];

  String _statusFilter = 'all';
  List<String> _availableStatusFilters = ['all'];
  DateTime? _startDate;
  DateTime? _endDate;
  int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _rawError = null;
    });

    final statusQuery = _statusFilter == 'all' ? null : _statusFilter;
    final startDate = _formatDate(_startDate);
    final endDate = _formatDate(_endDate);

    List<Map<String, dynamic>> active = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> history = <Map<String, dynamic>>[];
    String? activeError;
    String? historyError;

    try {
      final bookingTyped = await passengerTripsApi.fetchMyBookings(
        status: statusQuery,
        startDate: startDate,
        endDate: endDate,
        perPage: _perPage,
      );
      active = bookingTyped.map(_historyItemToMap).toList();

      final tripsTyped = await passengerTripsApi.fetchPassengerTrips();
      final tripMaps = tripsTyped.map(_historyItemToMap).toList();
      final seenIds =
          active
              .map((item) => (item['id'] ?? item['rideId']).toString())
              .toSet();
      for (final item in tripMaps) {
        final key = (item['id'] ?? item['rideId']).toString();
        if (!seenIds.contains(key)) {
          active.add(item);
          seenIds.add(key);
        }
      }
    } catch (e) {
      final raw =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      _rawError = raw;
      activeError = _sanitizeBackendError(raw);
    }

    try {
      final historyTyped = await passengerTripsApi.fetchRideHistory(
        status: statusQuery,
        startDate: startDate,
        endDate: endDate,
        perPage: _perPage,
      );
      history = historyTyped.map(_historyItemToMap).toList();
    } catch (e) {
      final raw =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      _rawError = raw;
      final message = _sanitizeBackendError(raw);
      if (_isHistoryRouteConflict(message)) {
        historyError = _lang.t('trips.historyConflict');
      } else {
        historyError = message;
      }
    }

    final merged = <Map<String, dynamic>>[...active, ...history];

    final statuses =
        {
            for (final t in merged) (t['rawStatus'] ?? '').toString().trim(),
          }.where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList()
          ..sort();

    final filterOptions = <String>['all', ...statuses];
    final resolvedFilter =
        filterOptions.contains(_statusFilter) ? _statusFilter : 'all';
    final shouldAnnounceBooking =
        widget.bookingSuccessNonce > _lastShownBookingNonce;

    String? uiError;
    if (activeError != null && historyError != null) {
      uiError = _lang.t(
        'trips.loadFailed',
        args: <String, String>{'error': activeError},
      );
    } else if (historyError != null) {
      uiError = historyError;
    } else if (activeError != null) {
      uiError = activeError;
    }

    if (!mounted) return;
    setState(() {
      _trips = merged;
      _availableStatusFilters = filterOptions;
      _statusFilter = resolvedFilter;
      _error = uiError;
      _isLoading = false;
      if (shouldAnnounceBooking) {
        _lastShownBookingNonce = widget.bookingSuccessNonce;
        _highlightNewestActive = true;
      }
    });

    if (shouldAnnounceBooking) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          behavior: SnackBarBehavior.floating,
          content: Text(
            _lang.t('trips.bookingUpdated'),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );

      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _highlightNewestActive = false);
      });
    }
  }

  bool _isHistoryRouteConflict(String message) {
    final lower = message.toLowerCase();
    return lower.contains('showride') ||
        (lower.contains('must be of type int') &&
            lower.contains('string given'));
  }

  /// Maps a typed [RideHistoryItem] → the flat map the UI widgets expect.
  Map<String, dynamic> _historyItemToMap(RideHistoryItem r) {
    final dateStr =
        r.bookedAt != null
            ? (_formatDateTimeString(r.bookedAt.toString()) ?? '--')
            : '--';
    return {
      'id': r.id,
      'rideId': r.rideId,
      'from': r.origin.isNotEmpty ? r.origin : '--',
      'to': r.destination.isNotEmpty ? r.destination : '--',
      'date': dateStr,
      'price': CurrencyFormatter.formatPrice(r.totalPrice),
      'driver': 'Driver',
      'status': _normalizeStatus(r.status),
      'rawStatus': r.status, // preserved for the filter dropdown
      'type': 'Economy',
      'rating': 0,
    };
  }

  /// Maps a typed [RideDetails] → the flat map the details sheet expects.
  Map<String, dynamic> _rideDetailsToMap(
    RideDetails d, {
    required Map<String, dynamic> fallback,
  }) {
    final type =
        d.rideType.isNotEmpty
            ? d.rideType
            : (fallback['type'] ?? 'Economy').toString();
    final driver =
        d.driverName.isNotEmpty
            ? d.driverName
            : (fallback['driver'] ?? 'Pending').toString();
    final from =
        d.originAddress.isNotEmpty
            ? d.originAddress
            : (fallback['from'] ?? '--').toString();
    final to =
        d.destinationAddress.isNotEmpty
            ? d.destinationAddress
            : (fallback['to'] ?? '--').toString();
    final price =
        d.pricePerSeat > 0
            ? CurrencyFormatter.formatPrice(d.pricePerSeat)
            : (fallback['price'] ?? '--').toString();
    final date =
        d.requestedAt != null
            ? (_formatDateTimeString(d.requestedAt.toString()) ?? '--')
            : (fallback['date'] ?? '--').toString();
    return {
      'id': d.id,
      'status': _normalizeStatus(d.status),
      'type': type,
      'driver': driver,
      'date': date,
      'price': price,
      'from': from,
      'to': to,
      'seats': d.seats != null ? '${d.seats}' : '${d.availableSeats}',
      'payment_status': d.paymentStatus ?? '--',
      'notes': d.notes ?? '--',
      'requested_at':
          d.requestedAt != null
              ? _formatDateTimeString(d.requestedAt.toString())
              : null,
      'in_progress_at':
          d.acceptedAt != null
              ? _formatDateTimeString(d.acceptedAt.toString())
              : null,
      'completed_at':
          d.completedAt != null
              ? _formatDateTimeString(d.completedAt.toString())
              : null,
      'cancelled_at':
          d.cancelledAt != null
              ? _formatDateTimeString(d.cancelledAt.toString())
              : null,
    };
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  String _statusLabel(String value) {
    if (value == 'all') return _lang.t('common.all');
    final text = value.replaceAll('_', ' ');
    return text
        .split(' ')
        .map(
          (word) =>
              word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
        isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    await _loadTrips();
  }

  Future<void> _clearDateFilters() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    await _loadTrips();
  }

  Future<void> _resetAllFilters() async {
    setState(() {
      _statusFilter = 'all';
      _startDate = null;
      _endDate = null;
      _perPage = 20;
    });
    await _loadTrips();
  }

  String _normalizeStatus(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('cancel')) return 'Cancelled';
    if (lower.contains('complete') || lower.contains('finish')) {
      return 'Completed';
    }
    return 'Active';
  }

  String? _formatDateTimeString(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text == '--') return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  /// Sanitize backend error messages before showing to users.
  /// Returns a user-friendly message when the server returns internal
  /// implementation details (class not found, stack traces, etc.).
  String _sanitizeBackendError(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown server error.';
    final lower = raw.toLowerCase();
    if (lower.contains('target class') && lower.contains('does not exist')) {
      return 'Server configuration error: a backend service is missing. Please contact support.';
    }
    if (lower.contains('exception') ||
        lower.contains('trace') ||
        lower.contains('stack')) {
      return 'Server error occurred. Please try again later.';
    }
    return raw;
  }

  void _showRawErrorDialog() {
    final raw = _rawError;
    if (raw == null) return;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(_lang.t('trips.errorDetails')),
            content: SingleChildScrollView(child: SelectableText(raw)),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: raw));
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copied')));
                },
                child: Text(_lang.t('common.copy')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_lang.t('common.close')),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelRide(Map<String, dynamic> trip) async {
    final id = trip['rideId'] ?? trip['id'];
    if (id == null) return;
    try {
      await passengerTripsApi.cancelBooking(id as int);
      await _loadTrips();
    } catch (e) {
      if (!mounted) return;
      final msg =
          e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          content: Text(msg, style: GoogleFonts.poppins(color: Colors.white70)),
        ),
      );
    }
  }

  Future<void> _openTripDetails(Map<String, dynamic> trip) async {
    final rideId = trip['rideId'] ?? trip['id'];
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lang.t('trips.detailsUnavailable'))),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          ),
    );

    try {
      final detailsModel = await passengerTripsApi.fetchRideDetails(
        rideId as int,
      );
      final details = _rideDetailsToMap(detailsModel, fallback: trip);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => _TripDetailsSheet(
              details: details,
              onRebook: () async {
                final seats = int.tryParse(details['seats']?.toString() ?? '1');
                final booked = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder:
                        (_) => BookRidePage(
                          initialPickup: details['from']?.toString(),
                          initialDropoff: details['to']?.toString(),
                          initialSeats: seats,
                          initialRideType: details['type']?.toString(),
                          popAfterBooking: true,
                        ),
                  ),
                );
                if (booked == true && mounted) {
                  await _loadTrips();
                }
              },
            ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131729),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _trips.where((t) => t['status'] == 'Active').toList();
    final history = _trips.where((t) => t['status'] != 'Active').toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? const [Color(0xFF0A0E1A), Color(0xFF1A1F3A)]
                  : const [Color(0xFFEFF4FF), Color(0xFFDCE8FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header section - fixed at top
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageTitle(),
                    const SizedBox(height: 16),
                    if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF5E5B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadTrips,
                              child: Text(_lang.t('common.retry')),
                            ),
                            if (_rawError != null && kDebugMode)
                              TextButton(
                                onPressed: _showRawErrorDialog,
                                child: const Text('Details'),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildStatsRow(),
                    const SizedBox(height: 14),
                    _buildFilterBar(),
                    const SizedBox(height: 10),
                    _buildActiveFilterChips(),
                    const SizedBox(height: 8),
                    _buildQueryPreview(),
                    const SizedBox(height: 16),
                    _buildTabBar(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTrips,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTripList(active, canCancel: true),
                    _buildTripList(history),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTitle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF6C63FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _lang.t('trips.myTrips'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final completed = _trips.where((t) => t['status'] == 'Completed').length;
    final totalSpent = _trips.where((t) => t['status'] == 'Completed').fold(
      0.0,
      (sum, t) {
        final raw = (t['price'] as String).replaceAll(r'$', '');
        return sum + (double.tryParse(raw) ?? 0);
      },
    );

    return Row(
      children: [
        _StatCard(
          label: _lang.t('trips.totalTrips'),
          value: '${_trips.length}',
          icon: Icons.directions_car_rounded,
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: _lang.t('status.completed'),
          value: '$completed',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: _lang.t('trips.totalSpent'),
          value: '\$${totalSpent.toStringAsFixed(2)}',
          icon: Icons.wallet_rounded,
          color: const Color(0xFF6C63FF),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  dropdownColor:
                      isDark
                          ? const Color(0xFF131729)
                          : const Color(0xFFF5F5F5),
                  decoration: _filterDecoration(_lang.t('trips.status')),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12,
                  ),
                  items:
                      _availableStatusFilters
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _statusFilter = value);
                    await _loadTrips();
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<int>(
                  value: _perPage,
                  dropdownColor:
                      isDark
                          ? const Color(0xFF131729)
                          : const Color(0xFFF5F5F5),
                  decoration: _filterDecoration(_lang.t('trips.perPage')),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12,
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 20, child: Text('20')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _perPage = value);
                    await _loadTrips();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    _startDate == null
                        ? _lang.t('trips.startDate')
                        : _formatDate(_startDate)!,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event, size: 14),
                  label: Text(
                    _endDate == null
                        ? _lang.t('trips.endDate')
                        : _formatDate(_endDate)!,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _clearDateFilters,
                child: Text(_lang.t('common.clear')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_statusFilter != 'all') {
      chips.add(
        _FilterChip(
          label: '${_lang.t('trips.status')}: ${_statusLabel(_statusFilter)}',
          onClear: () async {
            setState(() => _statusFilter = 'all');
            await _loadTrips();
          },
        ),
      );
    }

    if (_startDate != null || _endDate != null) {
      final from = _formatDate(_startDate) ?? '...';
      final to = _formatDate(_endDate) ?? '...';
      chips.add(
        _FilterChip(
          label: '${_lang.t('trips.date')}: $from ? $to',
          onClear: _clearDateFilters,
        ),
      );
    }

    if (_perPage != 20) {
      chips.add(
        _FilterChip(
          label: '${_lang.t('trips.perPage')}: $_perPage',
          onClear: () async {
            setState(() => _perPage = 20);
            await _loadTrips();
          },
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    chips.add(
      TextButton(
        onPressed: _resetAllFilters,
        child: Text(_lang.t('common.clearAll')),
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildQueryPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final params = <String, String>{'per_page': '$_perPage'};
    if (_statusFilter != 'all') {
      params['status'] = _statusFilter;
    }
    final start = _formatDate(_startDate);
    final end = _formatDate(_endDate);
    if (start != null) params['start_date'] = start;
    if (end != null) params['end_date'] = end;

    final query = Uri(queryParameters: params).query;
    final bookingsQuery = '/api/v1/passenger/bookings/my?$query';
    final tripsQuery = '/api/v1/passenger/trips';
    final historyQuery = '/api/v1/passenger/rides/history?$query';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lang.t('trips.backendQueryPreview'),
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildCopyableQueryLine('GET $bookingsQuery'),
          const SizedBox(height: 3),
          _buildCopyableQueryLine('GET $tripsQuery'),
          const SizedBox(height: 3),
          _buildCopyableQueryLine('GET $historyQuery'),
        ],
      ),
    );
  }

  Widget _buildCopyableQueryLine(String queryText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            queryText,
            style: GoogleFonts.robotoMono(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 10,
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: queryText));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                duration: Duration(milliseconds: 900),
                content: Text('Query copied'),
              ),
            );
          },
          icon: Icon(
            Icons.copy_rounded,
            size: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          tooltip: 'Copy query',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ],
    );
  }

  InputDecoration _filterDecoration(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white60 : Colors.black54,
        fontSize: 11,
      ),
      isDense: true,
      filled: true,
      fillColor:
          isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF6C63FF)),
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.black54,
        tabs: [
          Tab(text: _lang.t('status.active')),
          Tab(text: _lang.t('trips.history')),
        ],
      ),
    );
  }

  Widget _buildTripList(
    List<Map<String, dynamic>> trips, {
    bool canCancel = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  color: isDark ? Colors.white24 : Colors.black26,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  _lang.t('trips.empty'),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: trips.length,
      itemBuilder:
          (_, i) => _TripCard(
            trip: trips[i],
            onRate: (rating) => setState(() => trips[i]['rating'] = rating),
            onCancel: canCancel ? () => _cancelRide(trips[i]) : null,
            onOpenDetails: () => _openTripDetails(trips[i]),
            highlightPulse: canCancel && _highlightNewestActive && i == 0,
          ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final void Function(int) onRate;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenDetails;
  final bool highlightPulse;

  const _TripCard({
    required this.trip,
    required this.onRate,
    this.onCancel,
    this.onOpenDetails,
    this.highlightPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = PassengerLanguageService.instance;
    final isCancelled = trip['status'] == 'Cancelled';
    final statusColor =
        isCancelled ? const Color(0xFFFF5E5B) : const Color(0xFF10B981);
    final typeColors = {
      'Economy': const Color(0xFF3B82F6),
      'Premium': const Color(0xFF6C63FF),
      'Bike': const Color(0xFF10B981),
    };
    final typeColor = typeColors[trip['type']] ?? const Color(0xFF3B82F6);

    return InkWell(
      onTap: onOpenDetails,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              highlightPulse
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                highlightPulse
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.08),
            width: highlightPulse ? 1.4 : 1,
          ),
          boxShadow:
              highlightPulse
                  ? [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        trip['type'] as String,
                        style: GoogleFonts.poppins(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localizedStatus(lang, trip['status'] as String),
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (highlightPulse) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFFBBF24,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                        child: Text(
                          lang.t('common.new'),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  trip['price'] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RouteRow(from: trip['from'] as String, to: trip['to'] as String),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(
                        0xFF6C63FF,
                      ).withValues(alpha: 0.2),
                      child: Text(
                        (trip['driver'] as String)[0],
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6C63FF),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trip['driver'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  trip['date'] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (!isCancelled) ...[
              const SizedBox(height: 14),
              _RatingRow(currentRating: trip['rating'] as int, onRate: onRate),
            ],
            if (onCancel != null && trip['status'] == 'Active') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 14,
                    color: Color(0xFFFF5E5B),
                  ),
                  label: Text(
                    lang.t('trips.cancelRide'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF5E5B),
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF5E5B)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              lang.t('trips.tapForDetails'),
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedStatus(PassengerLanguageService lang, String status) {
    final lower = status.toLowerCase();
    if (lower.contains('cancel')) return lang.t('status.cancelled');
    if (lower.contains('complete')) return lang.t('status.completed');
    if (lower.contains('active')) return lang.t('status.active');
    return status;
  }
}

class _TripDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> details;
  final Future<void> Function()? onRebook;

  const _TripDetailsSheet({required this.details, this.onRebook});

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('cancel')) return const Color(0xFFFF5E5B);
    if (lower.contains('complete')) return const Color(0xFF10B981);
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final lang = PassengerLanguageService.instance;
    final status = details['status'].toString();
    final type = details['type'].toString();
    final statusColor = _statusColor(status);
    final statusLower = status.toLowerCase();
    final isCompleted = statusLower.contains('complete');
    final isCancelled = statusLower.contains('cancel');
    final requestedAt = _readDetailsTimestamp(details['requested_at']);
    final inProgressAt = _readDetailsTimestamp(details['in_progress_at']);
    final completedAt = _readDetailsTimestamp(details['completed_at']);
    final cancelledAt = _readDetailsTimestamp(details['cancelled_at']);

    final timelineSteps = <_TimelineStep>[
      _TimelineStep(
        label: lang.t('trips.requested'),
        state: _TimelineState.done,
        subtitle: requestedAt,
      ),
      _TimelineStep(
        label:
            isCancelled
                ? lang.t('status.cancelled')
                : lang.t('trips.inProgress'),
        state:
            isCancelled || isCompleted
                ? _TimelineState.done
                : _TimelineState.current,
        subtitle: isCancelled ? (cancelledAt ?? inProgressAt) : inProgressAt,
      ),
      _TimelineStep(
        label: lang.t('status.completed'),
        state:
            isCompleted
                ? _TimelineState.done
                : (isCancelled
                    ? _TimelineState.cancelled
                    : _TimelineState.pending),
        subtitle:
            isCompleted ? completedAt : (isCancelled ? cancelledAt : null),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12172A) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Text(
                  '${lang.t('trips.trip')} #${details['id']}',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      label: status,
                      color: statusColor,
                      icon: Icons.circle,
                    ),
                    _Badge(
                      label: type,
                      color: const Color(0xFF6C63FF),
                      icon: Icons.local_taxi_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: lang.t('trips.fare'),
                        value: details['price'].toString(),
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: lang.t('trips.payment'),
                        value: details['payment_status'].toString(),
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  lang.t('trips.progress'),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _TripTimeline(steps: timelineSteps, isDark: isDark),
                const SizedBox(height: 14),
                _DetailRow(
                  label: lang.t('trips.driver'),
                  value: details['driver'].toString(),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: lang.t('trips.date'),
                  value: details['date'].toString(),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: lang.t('book.seats'),
                  value: details['seats'].toString(),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: lang.t('trips.pickup'),
                  value: details['from'].toString(),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: lang.t('trips.dropoff'),
                  value: details['to'].toString(),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: lang.t('trips.notes'),
                  value: details['notes'].toString(),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (onRebook != null) {
                        await onRebook!();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(
                      lang.t('trips.rebookRoute'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _readDetailsTimestamp(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == '--') return null;
    return text;
  }
}

enum _TimelineState { done, current, pending, cancelled }

class _TimelineStep {
  final String label;
  final _TimelineState state;
  final String? subtitle;

  const _TimelineStep({
    required this.label,
    required this.state,
    this.subtitle,
  });
}

class _TripTimeline extends StatelessWidget {
  final List<_TimelineStep> steps;
  final bool isDark;

  const _TripTimeline({required this.steps, this.isDark = true});

  Color _dotColor(_TimelineState state) {
    switch (state) {
      case _TimelineState.done:
        return const Color(0xFF10B981);
      case _TimelineState.current:
        return const Color(0xFF3B82F6);
      case _TimelineState.cancelled:
        return const Color(0xFFFF5E5B);
      case _TimelineState.pending:
        return isDark ? Colors.white24 : Colors.black12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);
    final bgColor =
        isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;
          final color = _dotColor(step.state);

          return Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 12, color: color),
                    const SizedBox(height: 6),
                    Text(
                      step.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color:
                            step.state == _TimelineState.pending
                                ? (isDark ? Colors.white38 : Colors.black38)
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A)),
                        fontSize: 10,
                        fontWeight:
                            step.state == _TimelineState.current
                                ? FontWeight.w700
                                : FontWeight.w500,
                      ),
                    ),
                    if (step.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color:
                              isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 8,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 6, right: 6),
                      height: 2,
                      color:
                          step.state == _TimelineState.pending
                              ? Colors.white24
                              : color.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String from;
  final String to;

  const _RouteRow({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            const Icon(
              Icons.radio_button_checked_rounded,
              color: Color(0xFF10B981),
              size: 14,
            ),
            Container(
              width: 1,
              height: 18,
              color: Colors.white.withValues(alpha: 0.15),
              margin: const EdgeInsets.symmetric(vertical: 2),
            ),
            const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF6C63FF),
              size: 14,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                to,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final int currentRating;
  final void Function(int) onRate;

  const _RatingRow({required this.currentRating, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final lang = PassengerLanguageService.instance;
    return Row(
      children: [
        Text(
          currentRating == 0
              ? lang.t('trips.rateDriver')
              : lang.t('trips.yourRating'),
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(width: 10),
        Row(
          children: List.generate(5, (i) {
            return GestureDetector(
              onTap: () => onRate(i + 1),
              child: Icon(
                i < currentRating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color:
                    i < currentRating
                        ? const Color(0xFFFBBF24)
                        : Colors.white24,
                size: 20,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Future<void> Function() onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
