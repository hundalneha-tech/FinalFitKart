// lib/screens/activity_history_screen.dart
// Daily / Weekly / Monthly activity — Heart Points + Steps charts
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});
  @override State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tab = TabController(length: 3, vsync: this);
  final _sb = Supabase.instance.client;

  // ── Data ────────────────────────────────────────────────
  bool _loading = true;
  bool _showHeartPoints = true; // toggle: Heart Points | Steps

  // Day view — 24 hourly buckets
  List<int> _daySteps   = List.filled(24, 0);
  List<int> _dayHPts    = List.filled(24, 0);
  int _dayTotalSteps    = 0;
  int _dayTotalHP       = 0;
  String _dayLabel      = '';

  // Week view — 7 day buckets
  List<int> _weekSteps  = List.filled(7, 0);
  List<int> _weekHPts   = List.filled(7, 0);
  int _weekTotalSteps   = 0;
  int _weekTotalHP      = 0;
  List<String> _weekLabels = [];

  // Month view — days-in-month buckets
  List<int> _monthSteps = [];
  List<int> _monthHPts  = [];
  int _monthTotalSteps  = 0;
  int _monthTotalHP     = 0;
  String _monthLabel    = '';

  // Session list
  List<Map<String,dynamic>> _sessions = [];

  // Navigation offsets
  int _dayOffset   = 0;
  int _weekOffset  = 0;
  int _monthOffset = 0;

  final _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final _weekdays = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

  @override
  void initState() {
    super.initState();
    _tab.addListener(() { if (_tab.indexIsChanging) _loadAll(); });
    _loadAll();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadDay(), _loadWeek(), _loadMonth(), _loadSessions()]);
    if (mounted) setState(() => _loading = false);
  }

  // ── Day ─────────────────────────────────────────────────
  Future<void> _loadDay() async {
    final now = DateTime.now().add(Duration(days: _dayOffset));
    final start = DateTime(now.year, now.month, now.day);
    final end   = start.add(const Duration(days: 1));

    _dayLabel = _dayOffset == 0 ? 'Today' : _dayOffset == -1 ? 'Yesterday'
        : '${now.day} ${_months[now.month-1]}';

    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await _sb.from('workout_sessions')
          .select('start_time, end_time, steps, duration_seconds')
          .eq('user_id', uid)
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String());

      final steps = List.filled(24, 0);
      final hpts  = List.filled(24, 0);
      int totalSteps = 0, totalHP = 0;

      for (final s in data as List) {
        final dt    = DateTime.tryParse(s['start_time'] as String? ?? '') ?? start;
        final hour  = dt.toLocal().hour;
        final st    = (s['steps'] as num?)?.toInt() ?? 0;
        final mins  = ((s['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
        final hp    = _calcHP(st, mins);
        steps[hour] += st;
        hpts[hour]  += hp;
        totalSteps  += st;
        totalHP     += hp;
      }

      // Fallback — seed from profiles.total_steps if no sessions
      if (totalSteps == 0) {
        final p = await _sb.from('profiles').select('total_steps').eq('id', uid).single();
        totalSteps = (p['total_steps'] as num?)?.toInt() ?? 0;
        totalHP    = _calcHP(totalSteps, 30);
        steps[8]   = (totalSteps * 0.7).toInt();
        steps[9]   = (totalSteps * 0.3).toInt();
        hpts[8]    = (totalHP * 0.7).toInt();
        hpts[9]    = (totalHP * 0.3).toInt();
      }

      _daySteps = steps; _dayHPts = hpts;
      _dayTotalSteps = totalSteps; _dayTotalHP = totalHP;
    } catch (_) {}
  }

  // ── Week ────────────────────────────────────────────────
  Future<void> _loadWeek() async {
    final now      = DateTime.now();
    final monday   = now.subtract(Duration(days: now.weekday - 1 + (-_weekOffset * 7)));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd   = weekStart.add(const Duration(days: 7));

    _weekLabels = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return _weekdays[d.weekday % 7];
    });

    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await _sb.from('workout_sessions')
          .select('start_time, steps, duration_seconds')
          .eq('user_id', uid)
          .gte('start_time', weekStart.toIso8601String())
          .lt('start_time', weekEnd.toIso8601String());

      final steps = List.filled(7, 0);
      final hpts  = List.filled(7, 0);
      int totalSteps = 0, totalHP = 0;

      for (final s in data as List) {
        final dt  = DateTime.tryParse(s['start_time'] as String? ?? '') ?? weekStart;
        final idx = dt.toLocal().difference(weekStart).inDays.clamp(0, 6);
        final st  = (s['steps'] as num?)?.toInt() ?? 0;
        final mins = ((s['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
        final hp  = _calcHP(st, mins);
        steps[idx] += st;
        hpts[idx]  += hp;
        totalSteps += st;
        totalHP    += hp;
      }

      // Fallback mock data to show something if no sessions
      if (totalSteps == 0 && _weekOffset == 0) {
        final p = await _sb.from('profiles').select('total_steps').eq('id', uid).single();
        final ts = (p['total_steps'] as num?)?.toInt() ?? 0;
        if (ts > 0) {
          final today = now.weekday - 1;
          steps[today] = ts;
          hpts[today]  = _calcHP(ts, 30);
          totalSteps   = ts;
          totalHP      = hpts[today];
        }
      }

      _weekSteps = steps; _weekHPts = hpts;
      _weekTotalSteps = totalSteps; _weekTotalHP = totalHP;
    } catch (_) {}
  }

  // ── Month ───────────────────────────────────────────────
  Future<void> _loadMonth() async {
    final now   = DateTime.now();
    final month = DateTime(now.year, now.month + _monthOffset);
    final start = DateTime(month.year, month.month, 1);
    final end   = DateTime(month.year, month.month + 1, 1);
    final days  = end.difference(start).inDays;

    _monthLabel = '${_months[month.month-1]} ${month.year}';

    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await _sb.from('workout_sessions')
          .select('start_time, steps, duration_seconds')
          .eq('user_id', uid)
          .gte('start_time', start.toIso8601String())
          .lt('start_time', end.toIso8601String());

      final steps = List.filled(days, 0);
      final hpts  = List.filled(days, 0);
      int totalSteps = 0, totalHP = 0;

      for (final s in data as List) {
        final dt  = DateTime.tryParse(s['start_time'] as String? ?? '') ?? start;
        final idx = (dt.toLocal().day - 1).clamp(0, days - 1);
        final st  = (s['steps'] as num?)?.toInt() ?? 0;
        final mins = ((s['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
        final hp  = _calcHP(st, mins);
        steps[idx] += st;
        hpts[idx]  += hp;
        totalSteps += st;
        totalHP    += hp;
      }

      // Fallback for current month
      if (totalSteps == 0 && _monthOffset == 0) {
        final p = await _sb.from('profiles').select('total_steps').eq('id', uid).single();
        final ts = (p['total_steps'] as num?)?.toInt() ?? 0;
        if (ts > 0) {
          final today = now.day - 1;
          steps[today] = ts;
          hpts[today]  = _calcHP(ts, 30);
          totalSteps   = ts;
          totalHP      = hpts[today];
        }
      }

      _monthSteps = steps; _monthHPts = hpts;
      _monthTotalSteps = totalSteps; _monthTotalHP = totalHP;
    } catch (_) {}
  }

  // ── Sessions list ────────────────────────────────────────
  Future<void> _loadSessions() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await _sb.from('workout_sessions')
          .select('*')
          .eq('user_id', uid)
          .order('start_time', ascending: false)
          .limit(30);
      _sessions = List<Map<String,dynamic>>.from(data as List);
    } catch (_) {}
  }

  int _calcHP(int steps, int mins) {
    if (mins == 0 && steps > 0) mins = steps ~/ 100;
    if (mins == 0) return 0;
    final spm = steps / mins;
    return spm >= 100 ? mins * 2 : mins;
  }

  // ── Formatters ────────────────────────────────────────────
  String _fmtSteps(int s) => s > 999 ? '${(s/1000).toStringAsFixed(1)}k' : '$s';
  String _timeAgo(String? raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) { return ''; }
  }
  String _fmtDur(int? secs) {
    if (secs == null || secs == 0) return '–';
    final m = secs ~/ 60; final s = secs % 60;
    return m > 59 ? '${m ~/ 60}h ${m % 60}m' : '${m}m ${s}s';
  }

  // ── Navigate day/week/month ───────────────────────────────
  void _prev() { setState(() { if (_tab.index == 0) _dayOffset--; else if (_tab.index == 1) _weekOffset++; else _monthOffset--; }); _loadAll(); }
  void _next() {
    if (_tab.index == 0 && _dayOffset >= 0) return;
    if (_tab.index == 1 && _weekOffset <= 0) return;
    if (_tab.index == 2 && _monthOffset >= 0) return;
    setState(() { if (_tab.index == 0) _dayOffset++; else if (_tab.index == 1) _weekOffset--; else _monthOffset++; });
    _loadAll();
  }

  bool get _canGoNext => (_tab.index == 0 && _dayOffset < 0) || (_tab.index == 1 && _weekOffset > 0) || (_tab.index == 2 && _monthOffset < 0);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('My Activity',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      bottom: TabBar(
        controller: _tab,
        labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary, indicatorWeight: 2,
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [Tab(text: 'Day'), Tab(text: 'Week'), Tab(text: 'Month')]),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : RefreshIndicator(
          color: AppColors.primary, onRefresh: _loadAll,
          child: TabBarView(controller: _tab, children: [
            _buildDayView(),
            _buildWeekView(),
            _buildMonthView(),
          ])));

  // ── Day view ─────────────────────────────────────────────
  Widget _buildDayView() {
    final data = _showHeartPoints ? _dayHPts : _daySteps;
    final total = _showHeartPoints ? _dayTotalHP : _dayTotalSteps;
    final labels = List.generate(24, (i) {
      if (i == 0) return '12\nAM';
      if (i == 12) return '12\nPM';
      if (i < 12) return '$i\nAM';
      return '${i-12}\nPM';
    });
    // Show only every 4 hours
    final showLabels = [0, 4, 8, 12, 16, 20];

    return _buildView(
      navLabel: _dayLabel,
      totalLabel: _showHeartPoints ? '$total pts' : _fmtSteps(total),
      data: data,
      labels: List.generate(24, (i) => showLabels.contains(i) ? labels[i] : ''),
      barColor: _showHeartPoints ? AppColors.green : AppColors.primary,
      goalLine: _showHeartPoints ? 40 : 10000,
      barWidth: 8,
      suffix: _showHeartPoints ? 'Heart Points' : 'Steps',
      sessions: _sessionsForDay(),
    );
  }

  // ── Week view ────────────────────────────────────────────
  Widget _buildWeekView() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1 + (-_weekOffset * 7)));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label = '${weekStart.day} ${_months[weekStart.month-1]} – ${weekEnd.day} ${_months[weekEnd.month-1]}';
    final total = _showHeartPoints ? _weekTotalHP : _weekTotalSteps;
    final data  = _showHeartPoints ? _weekHPts : _weekSteps;

    return _buildView(
      navLabel: label,
      totalLabel: _showHeartPoints ? '$total pts' : _fmtSteps(total),
      data: data, labels: _weekLabels,
      barColor: _showHeartPoints ? AppColors.green : AppColors.primary,
      goalLine: _showHeartPoints ? 40 : 10000,
      barWidth: 28,
      suffix: _showHeartPoints ? 'Heart Points' : 'Steps',
      sessions: _sessionsForWeek(),
      weeklyGoalBadge: _showHeartPoints && _weekTotalHP >= 150,
    );
  }

  // ── Month view ───────────────────────────────────────────
  Widget _buildMonthView() {
    final total = _showHeartPoints ? _monthTotalHP : _monthTotalSteps;
    final data  = _showHeartPoints ? _monthHPts : _monthSteps;
    final labels = List.generate(data.length, (i) {
      final d = i + 1;
      return [1,8,15,22,29].contains(d) ? '$d' : '';
    });

    return _buildView(
      navLabel: _monthLabel,
      totalLabel: _showHeartPoints ? '$total pts' : _fmtSteps(total),
      data: data, labels: labels,
      barColor: _showHeartPoints ? AppColors.green : AppColors.primary,
      goalLine: _showHeartPoints ? 40 : 10000,
      barWidth: 7,
      suffix: _showHeartPoints ? 'Heart Points' : 'Steps',
      sessions: _sessions,
      isMonth: true,
    );
  }

  // ── Shared view builder ───────────────────────────────────
  Widget _buildView({
    required String navLabel, required String totalLabel,
    required List<int> data, required List<String> labels,
    required Color barColor, required double goalLine, required double barWidth,
    required String suffix, required List<Map<String,dynamic>> sessions,
    bool weeklyGoalBadge = false, bool isMonth = false,
  }) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    child: Column(children: [

      // ── Nav + total ──────────────────────────────────────
      Container(padding: const EdgeInsets.all(16), decoration: cardDecoration(), child: Column(children: [
        Row(children: [
          GestureDetector(onTap: _prev, child: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.textPrimary)),
          Expanded(child: Center(child: Column(children: [
            Text(navLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.favorite_rounded, size: 14, color: barColor),
              const SizedBox(width: 4),
              Text(totalLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: barColor)),
            ]),
          ]))),
          GestureDetector(
            onTap: _canGoNext ? _next : null,
            child: Icon(Icons.chevron_right_rounded, size: 28,
              color: _canGoNext ? AppColors.textPrimary : AppColors.border)),
        ]),
        const SizedBox(height: 16),

        // ── Bar chart ──────────────────────────────────────
        _BarChart(
          data: data, labels: labels, barColor: barColor,
          goalLine: goalLine, barWidth: barWidth,
          showHeartPoints: _showHeartPoints),

        const SizedBox(height: 12),

        // ── Toggle ─────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ToggleChip('Heart Points', _showHeartPoints, AppColors.green, () => setState(() => _showHeartPoints = true)),
          const SizedBox(width: 8),
          _ToggleChip('Steps', !_showHeartPoints, AppColors.primary, () => setState(() => _showHeartPoints = false)),
        ]),

        // ── Weekly goal badge ──────────────────────────────
        if (weeklyGoalBadge) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.green.withOpacity(0.3))),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('You hit the magic number!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('You scored ${totalLabel.replaceAll(' pts','')} Heart Points this week',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Container(width: 52, height: 52,
                decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(child: Text('150', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.green)))),
            ])),
        ],
      ])),
      const SizedBox(height: 12),

      // ── Info card ─────────────────────────────────────────
      if (_showHeartPoints)
        Container(padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: const Text(
            'You score Heart Points for each minute of activity that gets your heart pumping, like a brisk walk. Increase the intensity to earn more.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5))),
      if (_showHeartPoints) const SizedBox(height: 12),

      // ── Session list ──────────────────────────────────────
      if (sessions.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            const Text('🏃', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('No workouts yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Start a session from the Move tab', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]))
      else ...[
        if (isMonth) ..._buildMonthSessions(sessions)
        else ...sessions.map((s) => _SessionTile(session: s, timeAgo: _timeAgo(s['start_time'] as String?), fmtDur: _fmtDur)),
      ],
    ]));

  // Group month sessions by week
  List<Widget> _buildMonthSessions(List<Map<String,dynamic>> sessions) {
    final groups = <String, List<Map<String,dynamic>>>{};
    for (final s in sessions) {
      try {
        final d = DateTime.parse(s['start_time'] as String).toLocal();
        final weekStart = d.subtract(Duration(days: d.weekday - 1));
        final weekEnd   = weekStart.add(const Duration(days: 6));
        final key = '${weekStart.day} ${_months[weekStart.month-1]} – ${weekEnd.day} ${_months[weekEnd.month-1]}';
        groups.putIfAbsent(key, () => []).add(s);
      } catch (_) {}
    }
    final widgets = <Widget>[];
    groups.forEach((label, list) {
      final hp = list.fold(0, (sum, s) => sum + _calcHP((s['steps'] as num?)?.toInt() ?? 0, ((s['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60));
      widgets.add(Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text('$hp Heart Points', style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
        ])));
      widgets.addAll(list.map((s) => _SessionTile(session: s, timeAgo: _timeAgo(s['start_time'] as String?), fmtDur: _fmtDur)));
      widgets.add(const SizedBox(height: 8));
    });
    return widgets;
  }

  // Filter sessions
  List<Map<String,dynamic>> _sessionsForDay() {
    final now   = DateTime.now().add(Duration(days: _dayOffset));
    final start = DateTime(now.year, now.month, now.day);
    final end   = start.add(const Duration(days: 1));
    return _sessions.where((s) {
      try { final d = DateTime.parse(s['start_time'] as String).toLocal(); return d.isAfter(start) && d.isBefore(end); } catch (_) { return false; }
    }).toList();
  }

  List<Map<String,dynamic>> _sessionsForWeek() {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1 + (-_weekOffset * 7)));
    final start  = DateTime(monday.year, monday.month, monday.day);
    final end    = start.add(const Duration(days: 7));
    return _sessions.where((s) {
      try { final d = DateTime.parse(s['start_time'] as String).toLocal(); return d.isAfter(start) && d.isBefore(end); } catch (_) { return false; }
    }).toList();
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<int> data;
  final List<String> labels;
  final Color barColor;
  final double goalLine, barWidth;
  final bool showHeartPoints;

  const _BarChart({required this.data, required this.labels, required this.barColor,
    required this.goalLine, required this.barWidth, required this.showHeartPoints});

  @override
  Widget build(BuildContext context) {
    final max  = data.isEmpty ? 1 : data.reduce((a,b) => a>b?a:b).toDouble();
    final disp = max < goalLine ? goalLine : max;

    return SizedBox(height: 130, child: Stack(children: [
      // Goal line
      if (showHeartPoints)
        Positioned(
          top: 130 - (goalLine / disp * 100) - 10,
          left: 0, right: 0,
          child: Row(children: [
            Text('${goalLine.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            Expanded(child: Container(height: 1,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.green.withOpacity(0.4), width: 1, style: BorderStyle.solid))))),
          ])),

      // Bars
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (int i = 0; i < data.length; i++) Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Check mark if above goal
            if (showHeartPoints && data[i] >= goalLine.toInt())
              Icon(Icons.check_rounded, size: 10, color: barColor),
            // Bar
            Flexible(child: FractionallySizedBox(
              heightFactor: disp > 0 ? (data[i] / disp).clamp(0.0, 1.0) : 0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: barWidth > 15 ? 2 : 0.5),
                decoration: BoxDecoration(
                  color: data[i] > 0 ? barColor : AppColors.border,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))))),
            const SizedBox(height: 4),
            // Label
            Text(labels[i], textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: AppColors.textMuted, height: 1.2)),
          ])),
      ]),
    ]));
  }
}

// ── Toggle chip ───────────────────────────────────────────────────────────────
Widget _ToggleChip(String label, bool active, Color color, VoidCallback onTap) =>
  GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? color : AppColors.textSecondary))));

// ── Session tile ──────────────────────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final Map<String,dynamic> session;
  final String timeAgo;
  final String Function(int?) fmtDur;

  const _SessionTile({required this.session, required this.timeAgo, required this.fmtDur});

  String get _type => (session['type'] as String?) ?? 'walk';
  String get _emoji => _type == 'run' ? '🏃' : _type == 'cycle' ? '🚴' : '🚶';
  String get _label => _type == 'run' ? 'Run' : _type == 'cycle' ? 'Cycling' : 'Morning walk';
  Color  get _color => _type == 'run' ? AppColors.accent : _type == 'cycle' ? AppColors.green : AppColors.primary;
  int    get _steps => (session['steps'] as num?)?.toInt() ?? 0;
  int    get _dur   => (session['duration_seconds'] as num?)?.toInt() ?? 0;
  int    get _hp    => _dur > 0 ? (_steps / (_dur / 60) >= 100 ? _dur ~/ 60 * 2 : _dur ~/ 60) : 0;
  double get _dist  => (session['distance_km'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    // Format start time
    String startTime = '';
    try {
      final d = DateTime.parse(session['start_time'] as String).toLocal();
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2,'0');
      final p = d.hour >= 12 ? 'PM' : 'AM';
      startTime = '$h:$m $p';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14,12,14,12),
      decoration: cardDecoration(),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text('$startTime  ·  ${fmtDur(_dur)}${_dist > 0 ? "  ·  ${_dist.toStringAsFixed(2)} km" : ""}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Icon(Icons.favorite_rounded, size: 12, color: AppColors.green),
            const SizedBox(width: 3),
            Text('$_hp pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
          ]),
          Text('$_steps steps', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]));
  }
}
