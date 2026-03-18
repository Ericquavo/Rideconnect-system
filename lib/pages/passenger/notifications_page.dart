import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Notifications screen — shows ride, payment and promo alerts.
class NotificationsPage extends StatefulWidget {
  final VoidCallback onRead;
  const NotificationsPage({super.key, required this.onRead});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Ride Confirmed 🚗',
      'body': 'Your Economy ride with Ahmed K. has been confirmed. ETA: 4 min.',
      'time': 'Just now',
      'icon': Icons.directions_car_rounded,
      'color': 0xFF3B82F6,
      'read': false,
    },
    {
      'title': 'Driver Arrived 📍',
      'body': 'Your driver Sara M. has arrived at your pickup location.',
      'time': '2 min ago',
      'icon': Icons.location_on_rounded,
      'color': 0xFF10B981,
      'read': false,
    },
    {
      'title': 'Payment Successful 💳',
      'body': '\$12.50 was charged for your trip to Airport Terminal 1.',
      'time': '1 hour ago',
      'icon': Icons.payment_rounded,
      'color': 0xFF6C63FF,
      'read': false,
    },
    {
      'title': 'Special Offer 🎉',
      'body':
          'Use code RIDE20 and get 20% off your next 3 rides. Limited time!',
      'time': '3 hours ago',
      'icon': Icons.local_offer_rounded,
      'color': 0xFFFBBF24,
      'read': true,
    },
    {
      'title': 'Ride Completed ✅',
      'body': 'You have successfully completed a ride to University Campus.',
      'time': 'Yesterday',
      'icon': Icons.check_circle_rounded,
      'color': 0xFF10B981,
      'read': true,
    },
    {
      'title': 'New Feature Available ✨',
      'body':
          'RideConnect now supports scheduled rides. Plan your trips ahead!',
      'time': '2 days ago',
      'icon': Icons.new_releases_rounded,
      'color': 0xFF6C63FF,
      'read': true,
    },
  ];

  bool _allRead = false;

  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n['read'] = true;
      }
      _allRead = true;
    });
    widget.onRead();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !(n['read'] as bool)).length;

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
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
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
                            'Notifications',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (unread > 0)
                            Text(
                              '$unread unread',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF6C63FF),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (!_allRead && unread > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Mark all read',
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _notifications.length,
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  return _NotifCard(
                    title: n['title'] as String,
                    body: n['body'] as String,
                    time: n['time'] as String,
                    icon: n['icon'] as IconData,
                    color: Color(n['color'] as int),
                    isRead: n['read'] as bool,
                    onTap: () => setState(() => n['read'] = true),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
              isRead ? Colors.white.withValues(alpha: 0.04) : color.withValues(alpha: 0.08),
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
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
