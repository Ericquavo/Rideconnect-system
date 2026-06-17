// lib/screens/shared/notifications_screen.dart
// Notifications list with type icon mapping

import 'package:flutter/material.dart';

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as int,
    type: j['type'] as String,
    title: j['title'] as String,
    message: j['message'] as String,
    isRead: j['is_read'] as bool? ?? false,
    createdAt:
        j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );
}

class NotificationsScreen extends StatelessWidget {
  final List<AppNotification> notifications;

  const NotificationsScreen({super.key, required this.notifications});

  IconData _iconForType(String type) {
    if (type.startsWith('trip.')) return Icons.directions_car_rounded;
    if (type.startsWith('payment.')) return Icons.payment_rounded;
    if (type.startsWith('driver.')) return Icons.person_pin_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return ListTile(
            leading: Icon(_iconForType(notif.type)),
            title: Text(notif.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif.message),
                if (notif.createdAt != null)
                  Text(
                    notif.createdAt!.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            trailing:
                notif.isRead
                    ? null
                    : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
          );
        },
      ),
    );
  }
}
