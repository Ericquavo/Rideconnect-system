import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _markingAll = false;
  bool _clearingActioned = false;
  final Set<String> _actionBusyKeys = <String>{};
  final Set<String> _deletingKeys = <String>{};
  String? _error;
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

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

  int get _unreadCount =>
      _notifications.where((Map<String, dynamic> n) => _isUnread(n)).length;
  int get _clearableCount =>
      _notifications.where((Map<String, dynamic> n) => _canBeCleared(n)).length;

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _loadNotifications();
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

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.getNotifications();
      if (!mounted) return;
      final ordered = _sortNotifications(items);
      setState(() {
        _notifications = ordered;
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

  bool _isUnread(Map<String, dynamic> n) {
    final explicit = <dynamic>[n['read'], n['is_read'], n['seen']];
    for (final value in explicit) {
      if (value is bool) return !value;
      if (value is num) return value == 0;
      if (value is String) {
        final lower = value.toLowerCase().trim();
        if (lower == 'true' || lower == '1' || lower == 'read') return false;
        if (lower == 'false' || lower == '0' || lower == 'unread') return true;
      }
    }

    final status =
        _api.readString(n, const ['status'], fallback: '').toLowerCase();
    if (status.contains('read')) return false;
    return status.contains('unread') || status.contains('new');
  }

  bool _canBeCleared(Map<String, dynamic> n) {
    if (_isUnread(n)) return false;

    final explicit = _readBoolField(n['can_be_cleared']);
    if (explicit != null) return explicit;

    final status =
        _api.readString(n, const ['status'], fallback: '').toLowerCase();
    const clearableKeywords = <String>[
      'accepted',
      'rejected',
      'cancelled',
      'canceled',
      'completed',
      'confirmed',
      'started',
      'actioned',
    ];
    for (final keyword in clearableKeywords) {
      if (status.contains(keyword)) return true;
    }
    return false;
  }

  bool? _readBoolField(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return null;
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (!_isUnread(item)) return;
    final id = _api.readString(item, const ['id', 'notification_id']);
    if (id.isEmpty) {
      if (!mounted) return;
      setState(() {
        item['read'] = true;
        item['status'] = 'read';
      });
      return;
    }

    try {
      await _api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        item['read'] = true;
        item['status'] = 'read';
        _notifications = _sortNotifications(_notifications);
      });
    } catch (_) {
      // Silent fail to keep UI responsive.
    }
  }

  List<Map<String, dynamic>> _sortNotifications(
    List<Map<String, dynamic>> raw,
  ) {
    final copy = List<Map<String, dynamic>>.from(raw);
    copy.sort((a, b) {
      final unreadA = _isUnread(a);
      final unreadB = _isUnread(b);
      if (unreadA != unreadB) return unreadA ? -1 : 1;

      final timeA = DateTime.tryParse(
        _api.readString(a, const ['created_at', 'timestamp', 'createdAt']),
      );
      final timeB = DateTime.tryParse(
        _api.readString(b, const ['created_at', 'timestamp', 'createdAt']),
      );
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });
    return copy;
  }

  Future<void> _handleDecision(
    Map<String, dynamic> item, {
    required bool accept,
  }) async {
    final actionKey = _itemActionKey(item);
    if (_actionBusyKeys.contains(actionKey)) return;
    setState(() => _actionBusyKeys.add(actionKey));

    try {
      final notificationType =
          _api.readString(item, const ['type'], fallback: '').toLowerCase();
      final passenger = _extractPassengerName(item);
      final nested = _extractNestedMap(item);
      final pickup = _api.readString(
        item,
        const ['pickup_address', 'pickup', 'pickup_location'],
        fallback: _api.readString(nested, const [
          'pickup_address',
          'pickup',
          'pickup_location',
        ]),
      );
      final dropoff = _api.readString(
        item,
        const ['dropoff_address', 'destination', 'dropoff_location'],
        fallback: _api.readString(nested, const [
          'dropoff_address',
          'destination',
          'dropoff_location',
        ]),
      );

      var referenceId = '';
      var isBookingDecision = false;
      Map<String, dynamic>? actionResponse;

      final bookingId = _extractFirstId(item, const [
        'booking_id',
        'bookingId',
      ]);
      final requestIdFromPayload = _extractFirstId(item, const [
        'request_id',
        'ride_request_id',
        'trip_request_id',
      ]);

      if (bookingId.isNotEmpty ||
          (_isBookingType(notificationType) && requestIdFromPayload.isEmpty)) {
        if (bookingId.isEmpty) {
          throw Exception(_lang.t('notifications.bookingIdMissing'));
        }
        referenceId = bookingId;
        isBookingDecision = true;
        if (accept) {
          actionResponse = await _api.confirmBooking(bookingId);
        } else {
          actionResponse = await _api.cancelBooking(bookingId);
        }
      } else {
        final requestId =
            requestIdFromPayload.isNotEmpty
                ? requestIdFromPayload
                : await _resolveRideRequestIdStrict(item);
        if (requestId.isEmpty) {
          throw Exception(_lang.t('notifications.requestIdMissing'));
        }
        referenceId = requestId;
        if (accept) {
          actionResponse = await _api.acceptRequest(requestId);
        } else {
          actionResponse = await _api.rejectRequest(requestId);
        }
      }

      final passengerId = _extractPassengerId(item, actionResponse);

      final sent = await _api.notifyPassengerDecision(
        passengerId: passengerId,
        accepted: accept,
        bookingDecision: isBookingDecision,
        passengerName: passenger,
        referenceId: referenceId,
        pickup: pickup,
        dropoff: dropoff,
      );
      if (!sent && mounted) {
        _showSnack(_lang.t('notifications.passengerNotifyPending'));
      }

      await _markRead(item);
      if (!mounted) return;
      _showSnack(
        accept
            ? _lang.t('requests.accepted', args: {'name': passenger})
            : _lang.t('requests.rejected', args: {'name': passenger}),
      );
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _actionBusyKeys.remove(actionKey));
      }
    }
  }

  String _itemActionKey(Map<String, dynamic> item) {
    final id = _api.readString(item, const ['id', 'notification_id']);
    if (id.isNotEmpty) return 'notif:$id';
    final type = _api.readString(item, const ['type']);
    final created = _api.readString(item, const [
      'created_at',
      'timestamp',
      'createdAt',
    ]);
    final title = _api.readString(item, const ['title']);
    return 'fallback:$type|$created|$title';
  }

  bool _isActionBusy(Map<String, dynamic> item) {
    return _actionBusyKeys.contains(_itemActionKey(item));
  }

  bool _isBookingType(String type) {
    return type.contains('booking') || type.contains('book');
  }

  bool _isActionableType(String type) {
    return type.contains('request') ||
        type.contains('booking') ||
        type.contains('ride_request');
  }

  String _extractPassengerName(Map<String, dynamic> item) {
    final direct = _api.readString(item, const [
      'passenger_name',
      'passenger',
      'name',
      'sender_name',
    ]);
    if (direct.isNotEmpty) return direct;

    final nested = _extractNestedMap(item);
    final nestedName = _api.readString(nested, const [
      'passenger_name',
      'passenger',
      'name',
      'sender_name',
      'rider_name',
    ]);
    if (nestedName.isNotEmpty) return nestedName;

    return _lang.t('home.requestPassenger');
  }

  Map<String, dynamic> _extractNestedMap(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['data'],
      item['meta'],
      item['payload'],
      item['details'],
      item['request'],
      item['ride_request'],
      item['booking'],
    ];
    for (final c in candidates) {
      if (c is Map<String, dynamic>) return c;
    }
    return <String, dynamic>{};
  }

  String _extractFirstId(Map<String, dynamic> item, List<String> keys) {
    final direct = _api.readString(item, keys);
    if (direct.isNotEmpty) return direct;
    final nested = _extractNestedMap(item);
    return _api.readString(nested, keys);
  }

  Future<String> _resolveRideRequestIdStrict(Map<String, dynamic> item) async {
    final direct = _extractFirstId(item, const [
      'request_id',
      'ride_request_id',
      'trip_request_id',
    ]);
    if (direct.isNotEmpty) return direct;

    final passengerRaw = _extractPassengerName(item);
    final passenger = passengerRaw.toLowerCase().trim();
    final unknownPassenger = _lang.t('home.requestPassenger').toLowerCase();

    final nested = _extractNestedMap(item);
    final pickup =
        _api
            .readString(
              item,
              const ['pickup_address', 'pickup', 'pickup_location'],
              fallback: _api.readString(nested, const [
                'pickup_address',
                'pickup',
                'pickup_location',
              ]),
            )
            .toLowerCase()
            .trim();
    final dropoff =
        _api
            .readString(
              item,
              const ['dropoff_address', 'destination', 'dropoff_location'],
              fallback: _api.readString(nested, const [
                'dropoff_address',
                'destination',
                'dropoff_location',
              ]),
            )
            .toLowerCase()
            .trim();

    if ((passenger.isEmpty || passenger == unknownPassenger) &&
        pickup.isEmpty &&
        dropoff.isEmpty) {
      return '';
    }

    final pools = <Map<String, dynamic>>[];
    pools.addAll(await _api.getRequests());
    pools.addAll(await _api.getTripRequests());

    var bestId = '';
    var bestScore = -1;

    for (final req in pools) {
      final reqId = _api.readString(req, const ['id', '_id', 'request_id']);
      if (reqId.isEmpty) continue;

      final reqStatus =
          _api.readString(req, const [
            'status',
            'request_status',
          ]).toLowerCase();
      final pendingLike =
          reqStatus.isEmpty ||
          reqStatus.contains('pending') ||
          reqStatus.contains('new') ||
          reqStatus.contains('request');
      if (!pendingLike) continue;

      final reqPassenger =
          _api
              .readString(req, const ['passenger_name', 'passenger', 'name'])
              .toLowerCase()
              .trim();
      final reqPickup =
          _api
              .readString(req, const [
                'pickup_address',
                'pickup',
                'pickup_location',
              ])
              .toLowerCase()
              .trim();
      final reqDropoff =
          _api
              .readString(req, const [
                'dropoff_address',
                'destination',
                'dropoff_location',
              ])
              .toLowerCase()
              .trim();

      var score = 0;
      if (pickup.isNotEmpty && reqPickup.isNotEmpty && reqPickup == pickup) {
        score += 4;
      }
      if (dropoff.isNotEmpty &&
          reqDropoff.isNotEmpty &&
          reqDropoff == dropoff) {
        score += 4;
      }
      if (passenger.isNotEmpty &&
          passenger != unknownPassenger &&
          reqPassenger.isNotEmpty &&
          (reqPassenger == passenger ||
              reqPassenger.contains(passenger) ||
              passenger.contains(reqPassenger))) {
        score += 3;
      }

      if (score > bestScore) {
        bestScore = score;
        bestId = reqId;
      }
    }

    if (bestScore <= 0) return '';
    return bestId;
  }

  String _extractPassengerId(
    Map<String, dynamic> item,
    Map<String, dynamic>? actionResponse,
  ) {
    final fromItem = _extractFirstId(item, const [
      'passenger_id',
      'user_id',
      'rider_id',
      'passengerId',
      'recipient_id',
    ]);
    if (fromItem.isNotEmpty) return fromItem;

    final nested = _extractNestedMap(item);
    final nestedPassenger = nested['passenger'];
    if (nestedPassenger is Map<String, dynamic>) {
      final pId = _api.readString(nestedPassenger, const [
        'id',
        '_id',
        'user_id',
      ]);
      if (pId.isNotEmpty) return pId;
    }

    if (actionResponse != null) {
      final data = _api.extractDataMap(actionResponse);
      final fromResponse = _api.readString(data, const [
        'passenger_id',
        'user_id',
        'rider_id',
        'recipient_id',
      ]);
      if (fromResponse.isNotEmpty) return fromResponse;
      final responsePassenger = data['passenger'];
      if (responsePassenger is Map<String, dynamic>) {
        final pId = _api.readString(responsePassenger, const [
          'id',
          '_id',
          'user_id',
        ]);
        if (pId.isNotEmpty) return pId;
      }
    }

    return '';
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

  String _formatDateTime(String value) {
    if (value.isEmpty) return '--';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _notifications.isEmpty) return;
    setState(() => _markingAll = true);
    try {
      await _api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n['read'] = true;
          n['status'] = 'read';
        }
      });
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _clearActionedMessages() async {
    if (_clearableCount == 0 || _clearingActioned) return;

    setState(() => _clearingActioned = true);
    try {
      await _api.clearActionedNotifications();
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _clearingActioned = false);
    }
  }

  Future<bool> _deleteSingleNotification(Map<String, dynamic> item) async {
    if (!_canBeCleared(item)) {
      _showSnack('Notification still requires action.');
      return false;
    }

    final id = _api.readString(item, const ['id', 'notification_id']);
    if (id.isEmpty) return false;

    final actionKey = _itemActionKey(item);
    if (_deletingKeys.contains(actionKey)) return false;

    setState(() => _deletingKeys.add(actionKey));
    try {
      await _api.deleteNotification(id);
      return true;
    } catch (e) {
      final text = e.toString().replaceFirst('Exception: ', '');
      _showSnack(
        e is DriverApiException && e.isActionRequiredConflict
            ? 'Notification still requires action.'
            : text,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _deletingKeys.remove(actionKey));
      }
    }
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
            onRefresh: _loadNotifications,
            color: const Color(0xFF6C63FF),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width < 390 ? 14 : 20,
                14,
                MediaQuery.of(context).size.width < 390 ? 14 : 20,
                18,
              ),
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
                else if (_notifications.isEmpty)
                  _emptyCard()
                else
                  ..._notifications.map(_notificationCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final isNarrow = MediaQuery.of(context).size.width < 390;
    final isVeryNarrow = MediaQuery.of(context).size.width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
              tooltip: _lang.t('notifications.back'),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF6C63FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_lang.t('notifications.title')} ($_unreadCount)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: isNarrow ? 18 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child:
              isVeryNarrow
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: _markingAll ? null : _markAllRead,
                        tooltip: _lang.t('notifications.markAllRead'),
                        icon: const Icon(Icons.done_all_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed:
                            _clearableCount == 0 || _clearingActioned
                                ? null
                                : _clearActionedMessages,
                        tooltip: _lang.t('notifications.clearRead'),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  )
                  : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: <Widget>[
                      TextButton(
                        onPressed: _markingAll ? null : _markAllRead,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _lang.t('notifications.markAllRead'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _clearableCount == 0 || _clearingActioned
                                ? null
                                : _clearActionedMessages,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _lang.t('notifications.clearRead'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
              onPressed: _loadNotifications,
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
        _lang.t('notifications.empty'),
        style: GoogleFonts.poppins(color: _textSecondary),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final title = _api.readString(item, const [
      'title',
    ], fallback: _lang.t('notifications.title'));
    final body = _api.readString(item, const ['message', 'body'], fallback: '');
    final type = _api.readString(item, const ['type'], fallback: 'general');
    final createdRaw = _api.readString(item, const [
      'created_at',
      'timestamp',
      'createdAt',
    ]);
    final created = _formatDateTime(createdRaw);
    final passenger = _extractPassengerName(item);
    final nested = _extractNestedMap(item);
    final pickup = _api.readString(
      item,
      const ['pickup_address', 'pickup', 'pickup_location'],
      fallback: _api.readString(nested, const [
        'pickup_address',
        'pickup',
        'pickup_location',
      ]),
    );
    final dropoff = _api.readString(
      item,
      const ['dropoff_address', 'destination', 'dropoff_location'],
      fallback: _api.readString(nested, const [
        'dropoff_address',
        'destination',
        'dropoff_location',
      ]),
    );
    final phone = _api.readString(item, const [
      'passenger_phone',
      'phone',
    ], fallback: _api.readString(nested, const ['passenger_phone', 'phone']));
    final fare = _api.readDouble(
      item,
      const ['fare', 'price', 'total_price'],
      fallback: _api.readDouble(nested, const ['fare', 'price', 'total_price']),
    );
    final unread = _isUnread(item);
    final typeLower = type.toLowerCase();
    final actionable = _isActionableType(typeLower);
    final rowBusy = _isActionBusy(item);
    final canBeCleared = _canBeCleared(item);
    final rowDeleting = _deletingKeys.contains(_itemActionKey(item));

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 390;
    final isVeryNarrow = width < 360;
    final cardPadding = isVeryNarrow ? 11.0 : 14.0;
    final bodyFont = isVeryNarrow ? 12.0 : 13.0;
    final metaFont = isVeryNarrow ? 11.0 : 12.0;
    final typeFont = isVeryNarrow ? 10.0 : 11.0;

    final content = InkWell(
      onTap: () async => _markRead(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: isVeryNarrow ? 10 : 12),
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color:
              unread
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.08)
                  : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread ? const Color(0xFF6C63FF) : _cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: isVeryNarrow ? 18 : 19,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (body.isNotEmpty) ...<Widget>[
              SizedBox(height: isVeryNarrow ? 4 : 6),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: _textSecondary,
                  fontSize: bodyFont,
                ),
              ),
            ],
            SizedBox(height: isVeryNarrow ? 6 : 8),
            _metaLine(
              '${_lang.t('notifications.passenger')}: $passenger',
              fontSize: metaFont,
            ),
            if (phone.isNotEmpty)
              _metaLine(
                '${_lang.t('notifications.phone')}: $phone',
                fontSize: metaFont,
              ),
            if (pickup.isNotEmpty)
              _metaLine(
                '${_lang.t('trips.pickup')}: $pickup',
                fontSize: metaFont,
              ),
            if (dropoff.isNotEmpty)
              _metaLine(
                '${_lang.t('trips.dropoff')}: $dropoff',
                fontSize: metaFont,
              ),
            if (fare > 0)
              _metaLine(
                '${_lang.t('request.fare')}: \$${fare.toStringAsFixed(2)}',
                fontSize: metaFont,
              ),
            SizedBox(height: isVeryNarrow ? 6 : 8),
            Text(
              '${_lang.t('notifications.type')}: $type${created.isNotEmpty ? ' • $created' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: _textSecondary.withValues(alpha: 0.85),
                fontSize: typeFont,
              ),
            ),
            if (actionable) ...<Widget>[
              SizedBox(height: isVeryNarrow ? 10 : 12),
              Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          rowBusy || rowDeleting
                              ? null
                              : () => _handleDecision(item, accept: false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF5E5B)),
                        minimumSize: Size(0, isVeryNarrow ? 38 : 42),
                      ),
                      child: Text(
                        _lang.t('requests.reject'),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF5E5B),
                          fontSize: isVeryNarrow ? 13 : 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isNarrow ? 0 : 10, height: isNarrow ? 8 : 0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          rowBusy || rowDeleting
                              ? null
                              : () => _handleDecision(item, accept: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, isVeryNarrow ? 38 : 42),
                      ),
                      child: Text(
                        _lang.t('requests.accept'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isVeryNarrow ? 13 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (rowDeleting) ...<Widget>[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );

    if (!canBeCleared) return content;

    return Dismissible(
      key: ValueKey<String>(_itemActionKey(item)),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _deleteSingleNotification(item),
      onDismissed: (_) {
        if (!mounted) return;
        setState(() {
          _notifications.removeWhere(
            (Map<String, dynamic> n) =>
                _itemActionKey(n) == _itemActionKey(item),
          );
        });
      },
      background: Container(
        margin: EdgeInsets.only(bottom: isVeryNarrow ? 10 : 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFFF5E5B).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5E5B)),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF5E5B)),
      ),
      child: content,
    );
  }

  Widget _metaLine(String text, {double fontSize = 12}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(color: _textSecondary, fontSize: fontSize),
    );
  }
}
