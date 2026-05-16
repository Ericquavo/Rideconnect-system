import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_preferences_service.dart';

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
  final Map<String, bool> _processingActions = <String, bool>{};
  bool _unreadOnly = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    DriverPreferencesService.appNotificationsNotifier.addListener(
      _onPreferenceChanged,
    );
    DriverPreferencesService.rideRequestAlertsNotifier.addListener(
      _onPreferenceChanged,
    );
    DriverPreferencesService.autoRefreshRequestsNotifier.addListener(
      _onPreferenceChanged,
    );
    _loadNotifications();
    _syncRefreshTimer();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    DriverPreferencesService.appNotificationsNotifier.removeListener(
      _onPreferenceChanged,
    );
    DriverPreferencesService.rideRequestAlertsNotifier.removeListener(
      _onPreferenceChanged,
    );
    DriverPreferencesService.autoRefreshRequestsNotifier.removeListener(
      _onPreferenceChanged,
    );
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onPreferenceChanged() {
    if (!mounted) return;
    _syncRefreshTimer();
    setState(() {});
  }

  bool get _canAutoRefresh =>
      DriverPreferencesService.appNotifications &&
      DriverPreferencesService.rideRequestAlerts &&
      DriverPreferencesService.autoRefreshRequests;

  void _syncRefreshTimer() {
    if (_canAutoRefresh) {
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => _loadNotifications(),
      );
      return;
    }

    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadNotifications() async {
    if (!_canAutoRefresh && _items.isNotEmpty) {
      return;
    }

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
    final notificationId = _notificationId(item);

    // Prevent duplicate processing of same notification
    final actionKey = _notificationKey(item);
    if (_processingActions.containsKey(actionKey)) return;
    _processingActions[actionKey] = accepted;

    // Extract ride ID (most important for the backend) - comprehensive search
    var rideId = _extractId(item, const <String>[
      'ride_id',
      'ride_request_id',
      'rideId',
      'rideid',
      'trip_id',
      'tripId',
    ]);

    // Check in data map if not found
    if (rideId.isEmpty) {
      final data = _extractDataMap(item);
      rideId = _extractString(data, const <String>[
        'ride_id',
        'rideId',
        'trip_id',
        'tripId',
        'id',
      ]);
      if (rideId.isEmpty) {
        rideId = _extractNestedObjectId(data, const <String>['ride', 'trip']);
      }
    }

    // Check in payload object
    if (rideId.isEmpty) {
      final payload = item['payload'];
      if (payload is Map<String, dynamic>) {
        rideId = _extractString(payload, const <String>[
          'ride_id',
          'rideId',
          'trip_id',
          'tripId',
          'id',
        ]);
      }
    }

    // Check in nested trip object
    if (rideId.isEmpty) {
      final trip = item['trip'];
      if (trip is Map<String, dynamic>) {
        rideId = _extractString(trip, const <String>[
          'id',
          'ride_id',
          'rideId',
          'trip_id',
          'tripId',
        ]);
      }
    }

    // Check in nested ride object
    if (rideId.isEmpty) {
      final ride = item['ride'];
      if (ride is Map<String, dynamic>) {
        rideId = _extractString(ride, const <String>[
          'id',
          'ride_id',
          'rideId',
          '_id',
        ]);
      }
    }

    // Debug logging
    print('[DRIVER_NOTIFICATIONS] Full notification: ${jsonEncode(item)}');
    print('[DRIVER_NOTIFICATIONS] Extracted rideId: "$rideId"');

    // Try to extract request/booking ID with extensive fallbacks
    var requestId = _extractId(item, const <String>[
      'request_id',
      'trip_request_id',
      'reference_id',
      'referenceId',
      'request_id_string',
    ]);

    // If still not found, check in data map
    if (requestId.isEmpty) {
      final data = _extractDataMap(item);
      requestId = _extractString(data, const <String>[
        'request_id',
        'trip_request_id',
        'trip_id',
        'reference_id',
        'id',
      ]);
      if (requestId.isEmpty) {
        requestId = _extractNestedObjectId(data, const <String>[
          'request',
          'trip_request',
        ]);
      }
    }

    var bookingId = _extractId(item, const <String>[
      'booking_id',
      'order_id',
      'orderId',
      'bookingId',
    ]);

    // If still not found, check in data map
    if (bookingId.isEmpty) {
      final data = _extractDataMap(item);
      bookingId = _extractString(data, const <String>[
        'booking_id',
        'order_id',
        'orderId',
      ]);
      if (bookingId.isEmpty) {
        bookingId = _extractNestedObjectId(data, const <String>['booking']);
      }
    }

    // Extract passenger ID with multiple fallbacks including nested objects
    var passengerId = _extractString(item, const <String>[
      'passenger_id',
      'user_id',
      'recipient_id',
      'rider_id',
      'passengerId',
      'from_user_id',
      'sender_id',
      'from_id',
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

    // Check in data map
    if (passengerId.isEmpty) {
      final data = _extractDataMap(item);
      passengerId = _extractString(data, const <String>[
        'passenger_id',
        'user_id',
        'rider_id',
        'from_user_id',
        'from_id',
      ]);
    }

    // Try to extract from nested data structures
    if (passengerId.isEmpty) {
      final payload = item['payload'];
      if (payload is Map<String, dynamic>) {
        passengerId = _extractString(payload, const <String>[
          'passenger_id',
          'user_id',
          'from_id',
          'rider_id',
        ]);
      }
    }

    // Additional fallback: try to get passenger info from notification metadata
    if (passengerId.isEmpty) {
      final from = item['from'];
      if (from is Map<String, dynamic>) {
        passengerId = _extractString(from, const <String>['id', '_id']);
      } else if (from is String) {
        passengerId = from;
      }
    }

    final passengerName = _extractString(item, const <String>[
      'passenger_name',
      'passenger',
      'name',
      'user_name',
      'from_name',
    ]);
    final pickup = _extractString(item, const <String>[
      'pickup',
      'pickup_address',
      'pickup_location',
      'from',
      'start_location',
    ]);
    final dropoff = _extractString(item, const <String>[
      'dropoff',
      'dropoff_address',
      'dropoff_location',
      'destination',
      'to',
      'end_location',
    ]);

    final isBooking = bookingId.isNotEmpty || _isBookingType(item);

    // Prefer ride_id, then booking_id, then request_id
    final actionId =
        rideId.isNotEmpty ? rideId : (isBooking ? bookingId : requestId);

    // Validate action ID
    if (actionId.isEmpty) {
      final errorMsg =
          'Request/Booking/Ride ID is missing for this notification.';
      if (!mounted) return;
      _processingActions.remove(actionKey);
      _showSnack(errorMsg, isError: true);
      return;
    }

    // Update UI to show this notification is processing
    if (mounted) {
      setState(() {});
    }
    try {
      // Log notification details for debugging
      print('[DRIVER_NOTIFICATIONS] Processing single notification:');
      print(
        '[DRIVER_NOTIFICATIONS] IDs - ride: "$rideId", request: "$requestId", booking: "$bookingId"',
      );

      // Strategy: Try available IDs in order of priority, using different endpoint types
      bool success = false;
      String lastError = '';

      // Try 1: Use trip request endpoints with request_id (primary - this is what we should use)
      if (!success && requestId.isNotEmpty) {
        try {
          print(
            '[DRIVER_NOTIFICATIONS] [1/3] Trying trip request endpoint with request_id=$requestId',
          );
          if (accepted) {
            await _api.acceptRequest(
              requestId,
              rideId: rideId,
              requestId: requestId,
              bookingId: bookingId,
            );
          } else {
            await _api.rejectRequest(
              requestId,
              rideId: rideId,
              requestId: requestId,
              bookingId: bookingId,
            );
          }
          success = true;
          print(
            '[DRIVER_NOTIFICATIONS] ✓ SUCCESS: Trip request endpoint accepted with request_id',
          );
        } catch (e) {
          lastError = e.toString().replaceFirst('Exception: ', '');
          print(
            '[DRIVER_NOTIFICATIONS] ✗ FAILED: Trip request endpoint - $lastError',
          );
        }
      }

      // Try 2: Try with ride_id as fallback
      if (!success && rideId.isNotEmpty) {
        try {
          print(
            '[DRIVER_NOTIFICATIONS] [2/3] Trying ride endpoint with ride_id=$rideId',
          );
          if (accepted) {
            await _api.acceptRequest(
              rideId,
              rideId: rideId,
              requestId: requestId,
              bookingId: bookingId,
            );
          } else {
            await _api.rejectRequest(
              rideId,
              rideId: rideId,
              requestId: requestId,
              bookingId: bookingId,
            );
          }
          success = true;
          print(
            '[DRIVER_NOTIFICATIONS] ✓ SUCCESS: Ride endpoint accepted with ride_id',
          );
        } catch (e) {
          lastError = e.toString().replaceFirst('Exception: ', '');
          print('[DRIVER_NOTIFICATIONS] ✗ FAILED: Ride endpoint - $lastError');
        }
      }

      // Try 3: Use booking endpoints if we have booking_id
      if (!success && bookingId.isNotEmpty) {
        try {
          print(
            '[DRIVER_NOTIFICATIONS] [3/3] Trying booking endpoint with booking_id=$bookingId',
          );
          if (accepted) {
            await _api.confirmBooking(bookingId);
          } else {
            await _api.cancelBooking(bookingId);
          }
          success = true;
          print('[DRIVER_NOTIFICATIONS] ✓ SUCCESS: Booking endpoint succeeded');
        } catch (e) {
          lastError = e.toString().replaceFirst('Exception: ', '');
          print(
            '[DRIVER_NOTIFICATIONS] ✗ FAILED: Booking endpoint - $lastError',
          );
        }
      }

      // Try 4: Fallback - use ride_id as numeric
      if (!success && rideId.isNotEmpty) {
        try {
          print(
            '[DRIVER_NOTIFICATIONS] [4/4] Fallback: Using ride_id as direct ID: $rideId',
          );
          final intId = int.tryParse(rideId);
          if (intId != null && intId > 0) {
            if (accepted) {
              await _api.acceptRequest(
                intId,
                rideId: rideId,
                requestId: requestId,
                bookingId: bookingId,
              );
            } else {
              await _api.rejectRequest(
                intId,
                rideId: rideId,
                requestId: requestId,
                bookingId: bookingId,
              );
            }
            success = true;
            print('[DRIVER_NOTIFICATIONS] ✓ SUCCESS: Fallback accepted');
          }
        } catch (e) {
          lastError = e.toString().replaceFirst('Exception: ', '');
          print('[DRIVER_NOTIFICATIONS] ✗ FAILED: Fallback - $lastError');
        }
      }

      if (!success) {
        final detailError = 'Last error: $lastError';
        throw Exception(
          'Could not process ride action. $detailError\nIDs: ride=$rideId, request=$requestId, booking=$bookingId',
        );
      }

      // Attempt to notify passenger if passenger ID is available
      if (passengerId.isNotEmpty) {
        try {
          await _api.notifyPassengerDecision(
            passengerId: passengerId,
            accepted: accepted,
            bookingDecision: isBooking,
            passengerName: passengerName,
            referenceId: actionId,
            pickup: pickup,
            dropoff: dropoff,
          );
        } catch (_) {
          // Continue even if passenger notification fails
        }
      }

      // Mark notification as read if it has an ID
      if (notificationId > 0) {
        try {
          await _api.markNotificationRead(notificationId);
        } catch (_) {
          // Continue even if marking read fails
        }
      }

      if (!mounted) return;

      // Show user feedback immediately (don't wait for refresh)
      _showSnack(
        accepted
            ? 'Ride request accepted! ✓'
            : 'Ride request rejected. Passenger notified.',
        isError: false,
      );

      // Refresh only after a slight delay to ensure backend processed the change
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await _loadNotifications();
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      _showSnack(errorMsg, isError: true);
    } finally {
      // Remove this notification from processing state
      _processingActions.remove(actionKey);
      if (mounted) {
        setState(() {});
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

  String _notificationKey(Map<String, dynamic> item) {
    final id = _extractString(item, const <String>['id', 'notification_id']);
    if (id.isNotEmpty) return id;
    return item.hashCode.toString();
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
    for (final nestedKey in [
      'notification_data',
      'payload',
      'metadata',
      'content',
      'extra',
    ]) {
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

  String _extractNestedObjectId(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final nested = source[key];
      if (nested is Map<String, dynamic>) {
        final nestedId = _extractId(nested, const <String>[
          'id',
          '_id',
          'ride_id',
          'trip_id',
          'request_id',
        ]);
        if (nestedId.isNotEmpty) return nestedId;
      } else if (nested is String) {
        final text = nested.trim();
        if (text.isNotEmpty) return text;
      } else if (nested is num) {
        final text = nested.toInt().toString();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
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
    final isRead = _isRead(item);
    final isAction = _isActionRequired(item);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Enhanced styling for read vs unread
    final backgroundColor =
        isRead
            ? cardBg
            : (isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                : const Color(0xFFE8EEFF));

    final borderColor =
        isRead
            ? (isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0))
            : const Color(0xFF6C63FF).withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _showNotificationDetails(item),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isRead ? 1 : 2),
          boxShadow:
              isRead
                  ? null
                  : [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Unread indicator dot
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6C63FF),
                    ),
                    margin: const EdgeInsets.only(right: 8),
                  )
                else
                  SizedBox(
                    width: 10,
                    child: Icon(
                      Icons.check_circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.7),
                      size: 10,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _getNotificationTitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textPrimary,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      fontSize: isRead ? 14 : 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isAction)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5E5B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Action',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF5E5B),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  _timeLabel(_createdAt(item)),
                  style: GoogleFonts.poppins(
                    color: textSecondary,
                    fontSize: 11,
                    fontStyle: isRead ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getNotificationBody(item),
              style: GoogleFonts.poppins(
                color: textSecondary,
                fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                fontSize: isRead ? 13 : 13.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _buildActionButtons(item),
            ),
          ],
        ),
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
    final notificationKey = _notificationKey(item);
    final bool? processingAction = _processingActions[notificationKey];
    final isProcessing = processingAction != null;

    if (_isActionRequired(item)) {
      buttons.add(
        ElevatedButton.icon(
          onPressed:
              isProcessing
                  ? null
                  : () => _applyDriverDecision(item, accepted: true),
          icon:
              processingAction == true
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Icon(Icons.check_rounded, size: 16),
          label: Text(
            processingAction == true ? 'Processing...' : 'Accept',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
        ),
      );
      buttons.add(
        OutlinedButton.icon(
          onPressed:
              isProcessing
                  ? null
                  : () => _applyDriverDecision(item, accepted: false),
          icon:
              processingAction == false
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF5E5B),
                      ),
                    ),
                  )
                  : const Icon(Icons.close_rounded, size: 16),
          label: Text(
            processingAction == false ? 'Processing...' : 'Reject',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF5E5B),
            side: const BorderSide(color: Color(0xFFFF5E5B), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (!_isRead(item)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: isProcessing ? null : () => _markRead(item),
          icon: const Icon(Icons.done_rounded, size: 16),
          label: Text(
            'Mark read',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    buttons.add(
      OutlinedButton.icon(
        onPressed: isProcessing ? null : () => _deleteItem(item),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: Text(
          'Delete',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return buttons;
  }

  void _showNotificationDetails(Map<String, dynamic> item) {
    // Auto-mark as read when opening notification
    if (!_isRead(item)) {
      _markRead(item);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF475569);
    final bgColor =
        isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.92);

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder:
                  (context, scrollController) => SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: textSecondary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Title
                          Text(
                            'Notification Details',
                            style: GoogleFonts.poppins(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Details content
                          _buildDetailField(
                            'Title',
                            _getNotificationTitle(item),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Message',
                            _getNotificationBody(item),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Date & Time',
                            _timeLabel(_createdAt(item)),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'From',
                            _extractString(item, const <String>[
                              'passenger_name',
                              'passenger',
                              'name',
                              'from_name',
                            ]),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Pickup Location',
                            _extractString(item, const <String>[
                              'pickup',
                              'pickup_address',
                              'from',
                              'start_location',
                            ]),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Dropoff Location',
                            _extractString(item, const <String>[
                              'dropoff',
                              'dropoff_address',
                              'destination',
                              'to',
                              'end_location',
                            ]),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Status',
                            _extractString(item, const <String>['status']),
                            textPrimary,
                            textSecondary,
                          ),
                          _buildDetailField(
                            'Type',
                            _extractString(item, const <String>[
                              'type',
                              'event',
                            ]),
                            textPrimary,
                            textSecondary,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
  }

  Widget _buildDetailField(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textPrimary.withValues(alpha: 0.1)),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
