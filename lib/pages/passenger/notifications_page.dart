import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/mobile/data/mobile_flow_api_service.dart';
import '../../services/passenger_language_service.dart';

/// Notifications screen — shows ride, payment and promo alerts.
class NotificationsPage extends StatefulWidget {
  final VoidCallback onRead;
  final ValueChanged<int>? onUnreadChanged;

  const NotificationsPage({
    super.key,
    required this.onRead,
    this.onUnreadChanged,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;
  List<MobileNotificationItem> _notifications = <MobileNotificationItem>[];
  bool _allRead = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await mobileFlowApi.getNotifications();
      if (!mounted) return;

      final unread = items.where((n) => !n.read).length;
      widget.onUnreadChanged?.call(unread);

      setState(() {
        _notifications = items;
        _allRead = unread == 0;
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

  Future<void> _markAllRead() async {
    try {
      await mobileFlowApi.markAllNotificationsRead();
      setState(() {
        _notifications =
            _notifications
                .map(
                  (n) => MobileNotificationItem(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    body: n.body,
                    createdAt: n.createdAt,
                    read: true,
                  ),
                )
                .toList();
        _allRead = true;
      });
      widget.onUnreadChanged?.call(0);
      widget.onRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _markSingleRead(MobileNotificationItem item) async {
    if (item.read) return;
    try {
      await mobileFlowApi.markNotificationRead(item.id);
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications
                .map(
                  (n) =>
                      n.id == item.id
                          ? MobileNotificationItem(
                            id: n.id,
                            type: n.type,
                            title: n.title,
                            body: n.body,
                            createdAt: n.createdAt,
                            read: true,
                          )
                          : n,
                )
                .toList();
      });
      final unread = _notifications.where((n) => !n.read).length;
      widget.onUnreadChanged?.call(unread);
      if (unread == 0) {
        widget.onRead();
      }
    } catch (_) {
      // Ignore transient per-item read failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.read).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1F3A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6C63FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFF6C63FF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lang.t('notifications.title'),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (unreadCount > 0)
                            Text(
                              _lang.t(
                                'notifications.unread',
                                args: {'count': '$unreadCount'},
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF6C63FF),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (!_allRead && unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6C63FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _lang.t('notifications.markAllRead'),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF6C63FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF),
                        ),
                      )
                      : _error != null
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _loadNotifications,
                                child: Text(_lang.t('common.retry')),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          return _NotifCard(
                            title: n.title,
                            body: n.body,
                            time: _relativeTime(n.createdAt),
                            icon: _iconForType(n.type),
                            color: _colorForType(n.type),
                            isRead: n.read,
                            onTap: () => _markSingleRead(n),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('booking')) return Icons.book_online_rounded;
    if (lower.contains('trip')) return Icons.route_rounded;
    if (lower.contains('cancel')) return Icons.cancel_rounded;
    if (lower.contains('payment')) return Icons.payment_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('accepted') || lower.contains('confirmed')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('reject') || lower.contains('cancel')) {
      return const Color(0xFFFF5E5B);
    }
    if (lower.contains('trip')) return const Color(0xFF3B82F6);
    return const Color(0xFF6C63FF);
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return _lang.t('notifications.justNow');
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return _lang.t('notifications.justNow');
    if (diff.inMinutes < 60) {
      return _lang.t(
        'notifications.minutesAgo',
        args: {'m': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return _lang.t('notifications.hoursAgo', args: {'h': '${diff.inHours}'});
    }
    return _lang.t('notifications.daysAgo', args: {'d': '${diff.inDays}'});
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  final bool isRead;
  final VoidCallback onTap;

  const _NotifCard({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isRead
                  ? Colors.white.withValues(alpha: 0.04)
                  : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isRead
                    ? Colors.white.withValues(alpha: 0.07)
                    : color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
