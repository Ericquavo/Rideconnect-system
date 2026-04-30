import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';

class DriverNotificationsPage extends StatefulWidget {
  const DriverNotificationsPage({super.key});

  @override
  State<DriverNotificationsPage> createState() =>
      _DriverNotificationsPageState();
}

class _DriverNotificationsPageState extends State<DriverNotificationsPage> {
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverApi _api = DriverApi.instance;

  bool _loading = true;
  bool _actionBusy = false;
  bool _unreadOnly = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _loadNotifications();
    // Auto-refresh notifications every 15 seconds for dynamic updates
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadNotifications(),
    );
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getNotifications();
      final filtered =
          _unreadOnly ? data.where((item) => !_isRead(item)).toList() : data;
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = _notificationId(item);
    if (id <= 0) return;
    try {
      await _api.markNotificationRead(id);
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = _notificationId(item);
    if (id <= 0) return;
    try {
      await _api.deleteNotification(id);
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _clearActioned() async {
    try {
      await _api.clearActionedNotifications();
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _applyDriverDecision(
    Map<String, dynamic> item, {
    required bool accepted,
  }) async {
    if (_actionBusy) return;

    final notificationId = _notificationId(item);
    final requestId = _extractId(item, const <String>[
      'request_id',
      'ride_request_id',
      'trip_request_id',
    ]);
    final bookingId = _extractId(item, const <String>['booking_id']);

    // Extract passenger ID with multiple fallbacks including nested objects
    var passengerId = _extractString(item, const <String>[
      'passenger_id',
      'user_id',
      'recipient_id',
      'rider_id',
      'passengerId',
    ]);

    // Check nested passenger object if not found at top level
    if (passengerId.isEmpty) {
      final passengerObj = item['passenger'];
      if (passengerObj is Map<String, dynamic>) {
        passengerId = _extractString(passengerObj, const <String>[
          'id',
          '_id',
          'user_id',
          'passenger_id',
        ]);
      }
    }

    final passengerName = _extractString(item, const <String>[
      'passenger_name',
      'passenger',
      'name',
    ]);
    final pickup = _extractString(item, const <String>[
      'pickup',
      'pickup_address',
      'pickup_location',
    ]);
    final dropoff = _extractString(item, const <String>[
      'dropoff',
      'dropoff_address',
      'dropoff_location',
      'destination',
    ]);

    final isBooking = bookingId.isNotEmpty || _isBookingType(item);
    final actionId = isBooking ? bookingId : requestId;

    // Validate request/booking ID
    if (actionId.isEmpty) {
      final errorMsg =
          isBooking
              ? 'Booking ID is missing for this notification.'
              : 'Request id is missing for this notification.';
      if (!mounted) return;
      _showSnack(errorMsg, isError: true);
      return;
    }

    // Validate passenger ID
    if (passengerId.isEmpty) {
      if (!mounted) return;
      _showSnack(
        'Passenger ID is missing for this notification.',
        isError: true,
      );
      return;
    }

    setState(() => _actionBusy = true);
    try {
      // Execute driver action first
      if (isBooking) {
        if (accepted) {
          await _api.confirmBooking(actionId);
        } else {
          await _api.cancelBooking(actionId);
        }
      } else {
        if (accepted) {
          await _api.acceptRequest(actionId);
        } else {
          await _api.rejectRequest(actionId);
        }
      }

      // Notify passenger of decision
      final notified = await _api.notifyPassengerDecision(
        passengerId: passengerId,
        accepted: accepted,
        bookingDecision: isBooking,
        passengerName: passengerName,
        referenceId: actionId,
        pickup: pickup,
        dropoff: dropoff,
      );

      // Mark notification as read if it has an ID
      if (notificationId > 0) {
        try {
          await _api.markNotificationRead(notificationId);
        } catch (_) {
          // Continue even if marking read fails
        }
      }

      if (!mounted) return;

      // Update local UI to reflect the change
      setState(() {
        final index = _items.indexOf(item);
        if (index >= 0) {
          final current = Map<String, dynamic>.from(_items[index]);
          final data = _extractDataMap(current);
          data['status'] = accepted ? 'accepted' : 'rejected';
          data['action_required'] = false;
          current['status'] = accepted ? 'accepted' : 'rejected';
          current['read'] = true;
          current['data'] = data;
          _items[index] = current;
        }
      });

      // Show user feedback
      if (notified) {
        _showSnack(
          accepted
              ? 'Ride request accepted. Passenger has been notified.'
              : 'Ride request rejected. Passenger has been notified.',
          isError: false,
        );
      } else {
        _showSnack(
          'Action completed. Passenger notification pending.',
          isError: false,
        );
      }

      // Refresh notifications list
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  bool _isBookingType(Map<String, dynamic> item) {
    final type =
        _extractString(item, const <String>['type', 'event']).toLowerCase();
    return type.contains('booking');
  }

  int _notificationId(Map<String, dynamic> item) {
    return _extractInt(item, const <String>['id', 'notification_id']);
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> source) {
    final data = source['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  String _extractString(Map<String, dynamic> source, List<String> keys) {
    // Check top-level fields first
    for (final key in keys) {
      final value = source[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    // Check nested data map
    final data = _extractDataMap(source);
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    // Check deeply nested structures
    for (final nestedKey in ['notification_data', 'payload', 'metadata']) {
      final nested = source[nestedKey];
      if (nested is Map<String, dynamic>) {
        for (final key in keys) {
          final value = nested[key];
          if (value != null) {
            final text = value.toString().trim();
            if (text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }

    return '';
  }

  int _extractInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      final parsed = _toInt(value);
      if (parsed > 0) return parsed;
    }

    final data = _extractDataMap(source);
    for (final key in keys) {
      final value = data[key];
      final parsed = _toInt(value);
      if (parsed > 0) return parsed;
    }

    return 0;
  }

  String _extractId(Map<String, dynamic> source, List<String> keys) {
    final direct = _extractString(source, keys);
    if (direct.isNotEmpty) return direct;
    final numeric = _extractInt(source, keys);
    return numeric > 0 ? '$numeric' : '';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return 0;
      return int.tryParse(text) ?? 0;
    }
    return 0;
  }

  bool _isRead(Map<String, dynamic> source) {
    final raw = source['read'] ?? source['is_read'] ?? source['seen'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'read') return true;
    }
    final status =
        _extractString(source, const <String>['status']).toLowerCase();
    return status == 'read';
  }

  bool _isActionRequired(Map<String, dynamic> source) {
    final raw =
        source['action_required'] ??
        source['requires_action'] ??
        source['can_action'] ??
        source['actionable'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }

    // Check status - pending requests need action
    final status =
        _extractString(source, const <String>['status']).toLowerCase();
    if (status == 'pending' || status.isEmpty) return true;

    // Check type - ride/booking requests need action
    final type =
        _extractString(source, const <String>['type', 'event']).toLowerCase();
    final isActionableType =
        type.contains('request') ||
        type.contains('booking') ||
        type.contains('ride') ||
        type.contains('trip');

    if (!isActionableType) return false;

    // Don't show action buttons for already actioned items
    final isActioned =
        status.contains('accept') ||
        status.contains('reject') ||
        status.contains('cancel') ||
        status.contains('confirm') ||
        status.contains('completed') ||
        status.contains('done');

    return !isActioned;
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFFF5E5B) : const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  DateTime? _createdAt(Map<String, dynamic> source) {
    final raw = _extractString(source, const <String>[
      'created_at',
      'time',
      'timestamp',
    ]);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '--';
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.92);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // Header with Back button
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lang.t('notifications.title'),
                        style: GoogleFonts.poppins(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(_lang.t('common.all')),
                      selected: !_unreadOnly,
                      onSelected: (_) {
                        setState(() => _unreadOnly = false);
                        _loadNotifications();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(_lang.t('common.unread')),
                      selected: _unreadOnly,
                      onSelected: (_) {
                        setState(() => _unreadOnly = true);
                        _loadNotifications();
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(_lang.t('notifications.markAllRead')),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearActioned,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: Text(_lang.t('notifications.clearActioned')),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 36),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  )
                else if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.poppins(color: textSecondary),
                    ),
                  )
                else if (_items.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _lang.t('notifications.empty'),
                      style: GoogleFonts.poppins(color: textSecondary),
                    ),
                  )
                else
                  ..._buildNotificationList(textPrimary, textSecondary, cardBg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotificationList(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
  ) {
    return _items
        .map(
          (item) =>
              _buildNotificationCard(item, textPrimary, textSecondary, cardBg),
        )
        .toList();
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> item,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _isRead(item)
                  ? Colors.transparent
                  : const Color(0xFF6C63FF).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _getNotificationTitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeLabel(_createdAt(item)),
                style: GoogleFonts.poppins(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getNotificationBody(item),
            style: GoogleFonts.poppins(color: textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: _buildActionButtons(item)),
        ],
      ),
    );
  }

  String _getNotificationTitle(Map<String, dynamic> item) {
    return _extractString(item, const <String>[
          'title',
          'subject',
          'event_name',
        ]).isEmpty
        ? 'Notification'
        : _extractString(item, const <String>[
          'title',
          'subject',
          'event_name',
        ]);
  }

  String _getNotificationBody(Map<String, dynamic> item) {
    return _extractString(item, const <String>[
          'body',
          'message',
          'content',
        ]).isEmpty
        ? 'No details provided.'
        : _extractString(item, const <String>['body', 'message', 'content']);
  }

  List<Widget> _buildActionButtons(Map<String, dynamic> item) {
    final buttons = <Widget>[];

    if (_isActionRequired(item)) {
      buttons.add(
        ElevatedButton.icon(
          onPressed:
              _actionBusy
                  ? null
                  : () => _applyDriverDecision(item, accepted: true),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text(_lang.t('requests.accept')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed:
              _actionBusy
                  ? null
                  : () => _applyDriverDecision(item, accepted: false),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: Text(_lang.t('requests.reject')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF5E5B),
          ),
        ),
      );
    }

    if (!_isRead(item)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _markRead(item),
          icon: const Icon(Icons.done_rounded, size: 16),
          label: Text(_lang.t('notifications.markRead')),
        ),
      );
    }

    buttons.add(
      OutlinedButton.icon(
        onPressed: () => _deleteItem(item),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: Text(_lang.t('notifications.delete')),
      ),
    );

    return buttons;
  }
}
