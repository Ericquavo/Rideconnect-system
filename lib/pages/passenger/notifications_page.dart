import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/mobile/data/mobile_flow_api_service.dart';
import '../../services/passenger_language_service.dart';

class NotificationsPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback onRead;
  final ValueChanged<int>? onUnreadChanged;

  const NotificationsPage({
    super.key,
    this.onBack,
    required this.onRead,
    this.onUnreadChanged,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final PassengerLanguageService _lang = PassengerLanguageService.instance;

  bool _loading = true;
  bool _unreadOnly = false;
  String? _error;
  List<MobileNotificationItem> _items = <MobileNotificationItem>[];

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
      final data = await mobileFlowApi.getNotifications(
        unreadOnly: _unreadOnly,
      );
      final unreadCount = data.where((n) => !n.read).length;

      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
      widget.onUnreadChanged?.call(unreadCount);
      if (unreadCount == 0) {
        widget.onRead();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markRead(MobileNotificationItem item) async {
    if (item.id <= 0) return;
    try {
      await mobileFlowApi.markNotificationRead(item.id);
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteItem(MobileNotificationItem item) async {
    if (item.id <= 0) return;
    try {
      await mobileFlowApi.deleteNotification(item.id);
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await mobileFlowApi.markAllNotificationsRead();
      widget.onRead();
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _clearActioned() async {
    try {
      await mobileFlowApi.clearActionedNotifications();
      await _loadNotifications();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
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
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              if (widget.onBack != null)
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              Text(
                _lang.t('notifications.title'),
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
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
                    label: Text(_lang.t('notifications.filterUnread')),
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
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
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
                    _lang.t('notifications.emptyTitle'),
                    style: GoogleFonts.poppins(color: textSecondary),
                  ),
                )
              else
                ..._items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            item.read
                                ? Colors.transparent
                                : const Color(
                                  0xFF6C63FF,
                                ).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
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
                              _timeLabel(item.createdAt),
                              style: GoogleFonts.poppins(
                                color: textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: GoogleFonts.poppins(color: textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (!item.read)
                              OutlinedButton.icon(
                                onPressed: () => _markRead(item),
                                icon: const Icon(Icons.done_rounded, size: 16),
                                label: Text(_lang.t('notifications.markRead')),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _deleteItem(item),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: Text(_lang.t('notifications.delete')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
