// lib/screens/passenger/notifications_screen.dart
// Enhanced notifications screen – GET /api/v1/notifications

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/passenger_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
  Color get _card => _isDark ? const Color(0xFF141829) : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? Colors.white70 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await PassengerApi.instance.getNotifications();
      if (!mounted) return;
      setState(() { _notifications = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                // Mark all as read – no API endpoint for bulk, just visual
                setState(() {
                  for (final n in _notifications) {
                    n['read_at'] = DateTime.now().toIso8601String();
                  }
                });
              },
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? _buildError()
              : _notifications.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 56),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80,
              color: _isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.poppins(
              color: _isDark ? Colors.white38 : const Color(0xFF94A3B8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You\'re all caught up!',
            style: GoogleFonts.poppins(
              color: _isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _NotificationCard(
          notification: _notifications[i],
          isDark: _isDark,
          card: _card,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
  });
  final Map<String, dynamic> notification;
  final bool isDark;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString()
        ?? notification['subject']?.toString()
        ?? 'Notification';
    final body = notification['body']?.toString()
        ?? notification['message']?.toString()
        ?? notification['content']?.toString()
        ?? '';
    final type = (notification['type'] ?? notification['notification_type'] ?? 'info')
        .toString().toLowerCase();
    final createdAt = notification['created_at']?.toString() ?? '';
    final isRead = notification['read_at'] != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? card : (isDark
            ? const Color(0xFF6C63FF).withValues(alpha: 0.06)
            : const Color(0xFFEEECFF)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0))
              : const Color(0xFF6C63FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _typeGradient(type)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(type), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.poppins(color: textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(createdAt),
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    if (type.contains('trip') || type.contains('ride')) {
      return Icons.directions_car_rounded;
    }
    if (type.contains('payment') || type.contains('wallet')) {
      return Icons.payments_rounded;
    }
    if (type.contains('driver')) return Icons.person_rounded;
    if (type.contains('promo') || type.contains('offer')) return Icons.local_offer_rounded;
    if (type.contains('warning') || type.contains('alert')) return Icons.warning_rounded;
    return Icons.notifications_rounded;
  }

  List<Color> _typeGradient(String type) {
    if (type.contains('trip') || type.contains('ride')) {
      return const [Color(0xFF3B82F6), Color(0xFF6366F1)];
    }
    if (type.contains('payment') || type.contains('wallet')) {
      return const [Color(0xFF10B981), Color(0xFF34D399)];
    }
    if (type.contains('promo') || type.contains('offer')) {
      return const [Color(0xFFF59E0B), Color(0xFFFBBF24)];
    }
    if (type.contains('warning') || type.contains('alert')) {
      return const [Color(0xFFEF4444), Color(0xFFF87171)];
    }
    return const [Color(0xFF6C63FF), Color(0xFF8B5CF6)];
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month-1]}';
    } catch (_) { return raw; }
  }
}
