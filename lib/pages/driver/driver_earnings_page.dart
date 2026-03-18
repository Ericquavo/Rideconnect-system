import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

/// Driver earnings tab: daily/weekly/monthly summary and earnings list.
class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key});

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  late Future<_EarningsData> _earningsFuture;
  final DriverLanguageService _lang = DriverLanguageService.instance;
  final DriverSyncService _sync = DriverSyncService.instance;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF475569);
  Color get _textMuted =>
      _isDarkMode ? Colors.white70 : const Color(0xFF334155);
  Color get _cardBg =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFC9D6F2);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _earningsFuture = _loadEarnings();
    _sync.dataVersionNotifier.addListener(_onSyncDataChanged);
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _sync.dataVersionNotifier.removeListener(_onSyncDataChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() => _earningsFuture = _loadEarnings());
  }

  void _onSyncDataChanged() {
    if (!mounted) return;
    setState(() => _earningsFuture = _loadEarnings());
  }

  Future<void> _refresh() async {
    setState(() => _earningsFuture = _loadEarnings());
    await _earningsFuture;
  }

  Future<_EarningsData> _loadEarnings() async {
    final api = DriverApi.instance;
    final response = await api.getEarnings();
    final monthlyResponse = await api.getMonthlyEarnings();

    final data = api.extractDataMap(response);
    final monthly = api.extractDataMap(monthlyResponse);

    final today = api.readDouble(data, const [
      'today',
      'today_earnings',
      'daily',
    ]);
    final week = api.readDouble(data, const ['week', 'weekly', 'this_week']);
    final month = api.readDouble(data, const [
      'month',
      'monthly',
      'this_month',
    ]);
    final completedRides = api.readInt(data, const [
      'completed_rides',
      'rides_completed',
      'total_completed',
    ]);
    final hoursOnline = api.readDouble(data, const [
      'hours_online',
      'online_hours',
      'time_online_hours',
    ]);

    final historyRaw = api.extractList(
      response,
      preferredKeys: const ['history', 'earnings', 'transactions'],
    );

    final monthlyTarget = api.readDouble(monthly, const [
      'goal',
      'target',
      'monthly_target',
    ], fallback: month > 0 ? month * 1.25 : 0);

    final history =
        historyRaw.map((item) {
          final date = api.readString(item, const [
            'date',
            'created_at',
            'earning_date',
          ], fallback: _lang.t('common.unknown'));
          final amount = api.readDouble(item, const [
            'amount',
            'fare',
            'total',
          ]);
          final rides = api.readInt(item, const [
            'rides',
            'ride_count',
            'trips',
          ]);
          return _EarningHistory(date: date, amount: amount, rides: rides);
        }).toList();

    return _EarningsData(
      today: today,
      week: week,
      month: month,
      completedRides: completedRides,
      hoursOnline: hoursOnline,
      monthlyTarget: monthlyTarget,
      history: history,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<_EarningsData>(
          future: _earningsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: _textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: Text(_lang.t('common.retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF6C63FF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _lang.t('earnings.title'),
                          style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSummaryCards(data),
                    const SizedBox(height: 20),
                    _buildPerformanceOverview(data),
                    const SizedBox(height: 20),
                    Text(
                      _lang.t('earnings.recent'),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (data.history.isEmpty)
                      Text(
                        _lang.t('earnings.emptyRecent'),
                        style: GoogleFonts.poppins(color: _textSecondary),
                      )
                    else
                      ...data.history.map(
                        (entry) => _earningTile(
                          entry.date,
                          '\$${entry.amount.toStringAsFixed(2)}',
                          _lang.t(
                            'earnings.ridesCount',
                            args: {'count': '${entry.rides}'},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(_EarningsData data) {
    return Column(
      children: [
        _SummaryCard(
          title: _lang.t('earnings.today'),
          value: '\$${data.today.toStringAsFixed(2)}',
          subtitle: _lang.t(
            'earnings.ridesCompleted',
            args: {'count': '${data.completedRides}'},
          ),
          color: const Color(0xFF10B981),
          icon: Icons.today_rounded,
          isDarkMode: _isDarkMode,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: _lang.t('earnings.thisWeek'),
          value: '\$${data.week.toStringAsFixed(2)}',
          subtitle: _lang.t('earnings.weeklyTotal'),
          color: const Color(0xFF3B82F6),
          icon: Icons.calendar_view_week_rounded,
          isDarkMode: _isDarkMode,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: _lang.t('earnings.thisMonth'),
          value: '\$${data.month.toStringAsFixed(2)}',
          subtitle: _lang.t('earnings.monthlyTotal'),
          color: const Color(0xFF6C63FF),
          icon: Icons.calendar_month_rounded,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }

  Widget _buildPerformanceOverview(_EarningsData data) {
    final monthGoal = data.monthlyTarget <= 0 ? data.month : data.monthlyTarget;
    final progress =
        monthGoal <= 0 ? 0.0 : (data.month / monthGoal).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lang.t('earnings.performanceOverview'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: _lang.t('earnings.completedRides'),
                  value: '${data.completedRides}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: _lang.t('earnings.hoursOnline'),
                  value: '${data.hoursOnline.toStringAsFixed(1)}h',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildProgressRow(
            _lang.t('earnings.monthlyGoal'),
            progress,
            '\$${data.month.toStringAsFixed(2)} / \$${monthGoal.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double progress, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(color: _textMuted, fontSize: 12),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: _isDarkMode ? Colors.white38 : const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: const Color(0xFF6C63FF),
            backgroundColor:
                _isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _earningTile(String date, String amount, String rides) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: GoogleFonts.poppins(color: _textMuted, fontSize: 13),
                ),
                Text(
                  rides,
                  style: GoogleFonts.poppins(
                    color:
                        _isDarkMode ? Colors.white38 : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsData {
  final double today;
  final double week;
  final double month;
  final int completedRides;
  final double hoursOnline;
  final double monthlyTarget;
  final List<_EarningHistory> history;

  const _EarningsData({
    required this.today,
    required this.week,
    required this.month,
    required this.completedRides,
    required this.hoursOnline,
    required this.monthlyTarget,
    required this.history,
  });
}

class _EarningHistory {
  final String date;
  final double amount;
  final int rides;

  const _EarningHistory({
    required this.date,
    required this.amount,
    required this.rides,
  });
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool isDarkMode;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color:
                        isDarkMode ? Colors.white70 : const Color(0xFF334155),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color:
                        isDarkMode ? Colors.white38 : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white54 : const Color(0xFF475569),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
