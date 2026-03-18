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
      setState(() {
        _notifications = items;
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
    final read = n['read'];
    if (read is bool) return !read;
    final status =
        _api.readString(n, const ['status'], fallback: '').toLowerCase();
    return status.contains('unread') || status.contains('new');
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (!_isUnread(item)) return;
    final id = _api.readString(item, const ['id', 'notification_id']);
    if (id == null || id.isEmpty) return;

    try {
      await _api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        item['read'] = true;
        item['status'] = 'read';
      });
    } catch (_) {
      // Silent fail to keep UI responsive.
    }
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
    return Row(
      children: <Widget>[
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
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: _markingAll ? null : _markAllRead,
          child: Text(
            _lang.t('notifications.markAllRead'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
    final created = _api.readString(item, const [
      'created_at',
      'timestamp',
      'createdAt',
    ]);
    final unread = _isUnread(item);

    return InkWell(
      onTap: () => _markRead(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
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
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
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
              const SizedBox(height: 6),
              Text(
                body,
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${_lang.t('notifications.type')}: $type${created.isNotEmpty ? ' • $created' : ''}',
              style: GoogleFonts.poppins(
                color: _textSecondary.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
