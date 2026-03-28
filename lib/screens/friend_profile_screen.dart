// lib/screens/friend_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class FriendProfileScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final Color avatarColor;

  const FriendProfileScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.avatarColor,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _recentSessions = [];
  List<Map<String, dynamic>> _causes = [];
  bool _loading = true;
  int _rank = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadProfile(),
        _loadSessions(),
        _loadRank(),
        _loadCauses(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _sb
          .from('profiles')
          .select('*, wallets(*)')
          .eq('id', widget.friendId)
          .single();
      final w = p['wallets'];
      if (mounted) setState(() {
        _profile = p;
        _wallet = w is List ? (w as List).firstOrNull : w as Map<String, dynamic>?;
      });
    } catch (e) {
      debugPrint('loadProfile error: $e');
    }
  }

  Future<void> _loadSessions() async {
    try {
      final data = await _sb
          .from('workout_sessions')
          .select('type, steps, distance_km, duration_seconds, start_time')
          .eq('user_id', widget.friendId)
          .order('start_time', ascending: false)
          .limit(5);
      if (mounted) setState(() =>
          _recentSessions = List<Map<String, dynamic>>.from(data as List));
    } catch (_) {}
  }

  Future<void> _loadRank() async {
    try {
      final data = await _sb
          .from('profiles')
          .select('id')
          .order('total_steps', ascending: false);
      final idx = (data as List).indexWhere((p) => p['id'] == widget.friendId);
      if (mounted) setState(() => _rank = idx >= 0 ? idx + 1 : 0);
    } catch (_) {}
  }

  Future<void> _loadCauses() async {
    try {
      final data = await _sb
          .from('donations')
          .select('amount, causes(title)')
          .eq('user_id', widget.friendId)
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) setState(() =>
          _causes = List<Map<String, dynamic>>.from(data as List));
    } catch (_) {}
  }

  String get _initials {
    final n = widget.friendName.trim().split(' ');
    return n.length >= 2
        ? '${n[0][0]}${n[1][0]}'.toUpperCase()
        : widget.friendName.isNotEmpty
            ? widget.friendName[0].toUpperCase()
            : '?';
  }

  int get _totalSteps => (_profile?['total_steps'] as num?)?.toInt() ?? 0;
  double get _balance => (_wallet?['balance'] as num?)?.toDouble() ?? 0;
  String get _level => _profile?['level'] as String? ?? 'Walker';
  String get _city => _profile?['city'] as String? ?? '';

  String _fmtSteps(int s) =>
      s >= 1000 ? '${(s / 1000).toStringAsFixed(1)}k' : '$s';

  String _fmtDur(int? secs) {
    if (secs == null || secs == 0) return '–';
    final m = secs ~/ 60;
    return m > 59 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

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

  String _workoutLabel(String? type) =>
      type == 'run' ? '🏃 Run' : type == 'cycle' ? '🚴 Cycle' : '🚶 Walk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(slivers: [

              // ── Header with avatar ───────────────────────────────────
              SliverToBoxAdapter(child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [widget.avatarColor, widget.avatarColor.withOpacity(0.7)])),
                child: SafeArea(child: Column(children: [
                  // Back button row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20)),
                    ])),

                  // Avatar
                  Container(width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3)),
                    child: Center(child: Text(_initials,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                          color: Colors.white)))),
                  const SizedBox(height: 12),

                  // Name
                  Text(widget.friendName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                        color: Colors.white)),
                  const SizedBox(height: 4),

                  // Level + city
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(_level,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Colors.white))),
                    if (_city.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white70, size: 13),
                        const SizedBox(width: 2),
                        Text(_city, style: const TextStyle(fontSize: 12,
                            color: Colors.white70)),
                      ]),
                    ],
                  ]),
                  const SizedBox(height: 20),
                ])),
              )),

              // ── Stats row ─────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: cardDecoration(),
                  child: Row(children: [
                    _StatItem(
                      value: _fmtSteps(_totalSteps),
                      label: 'Total Steps',
                      icon: '👟'),
                    _divider(),
                    _StatItem(
                      value: '${_balance.toStringAsFixed(1)} FKC',
                      label: 'Coins',
                      icon: '🪙'),
                    _divider(),
                    _StatItem(
                      value: _rank > 0 ? '#$_rank' : '–',
                      label: 'Leaderboard',
                      icon: '🏆'),
                    _divider(),
                    _StatItem(
                      value: '${(_totalSteps * 0.04).toStringAsFixed(0)}',
                      label: 'Calories',
                      icon: '🔥'),
                  ]),
                ),
              )),

              // ── Achievement badges ───────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Achievements',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (_totalSteps >= 1000)
                        _Badge('First Steps', '👶', AppColors.primary),
                      if (_totalSteps >= 10000)
                        _Badge('10k Walker', '🚶', AppColors.green),
                      if (_totalSteps >= 50000)
                        _Badge('50k Champ', '🏅', AppColors.yellow),
                      if (_totalSteps >= 100000)
                        _Badge('100k Legend', '🌟', AppColors.accent),
                      if (_recentSessions.length >= 5)
                        _Badge('5 Workouts', '💪', const Color(0xFF7C3AED)),
                      if (_balance >= 5)
                        _Badge('5 FKC Earned', '🪙', AppColors.yellow),
                      if (_causes.isNotEmpty)
                        _Badge('Donor', '❤️', AppColors.red),
                      if (_totalSteps == 0)
                        _Badge('Just Started', '🌱', AppColors.green),
                    ]),
                  ]),
                ),
              )),

              // ── Recent workouts ──────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Recent Workouts',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    if (_recentSessions.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No workouts yet',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary))))
                    else
                      ..._recentSessions.map((s) {
                        final steps = (s['steps'] as num?)?.toInt() ?? 0;
                        final dist = (s['distance_km'] as num?)?.toDouble() ?? 0;
                        final dur = (s['duration_seconds'] as num?)?.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Container(width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(12)),
                              child: Center(child: Text(
                                _workoutLabel(s['type'] as String?).split(' ')[0],
                                style: const TextStyle(fontSize: 20)))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_workoutLabel(s['type'] as String?),
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                              Text('${_fmtSteps(steps)} steps'
                                  '${dist > 0 ? "  ·  ${dist.toStringAsFixed(2)} km" : ""}'
                                  '${dur != null ? "  ·  ${_fmtDur(dur)}" : ""}',
                                style: const TextStyle(fontSize: 11,
                                    color: AppColors.textSecondary)),
                            ])),
                            Text(_timeAgo(s['start_time'] as String?),
                              style: const TextStyle(fontSize: 11,
                                  color: AppColors.textMuted)),
                          ]));
                      }),
                  ]),
                ),
              )),

              // ── Weekly Steps comparison ──────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Steps This Week',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.avatarColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(widget.friendName.split(' ')[0],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: widget.avatarColor))),
                    ]),
                    const SizedBox(height: 12),
                    // Mini weekly bar chart from sessions
                    _WeeklyChart(sessions: _recentSessions, color: widget.avatarColor),
                  ]),
                ),
              )),

              // ── Causes supported ────────────────────────────────────
              if (_causes.isNotEmpty)
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Causes Supported',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      ..._causes.map((d) {
                        final title = (d['causes'] as Map?)?['title'] as String? ?? 'Cause';
                        final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Text('❤️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(title,
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary))),
                            Text('${amt.toStringAsFixed(1)} FKC',
                              style: const TextStyle(fontSize: 12,
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w700)),
                          ]));
                      }),
                    ]),
                  ),
                )),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ]));
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppColors.borderLight);
}

// ── Stat item ─────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value, label, icon;
  const _StatItem({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(icon, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
  ]));
}

// ── Achievement badge ─────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label, emoji;
  final Color color;
  const _Badge(this.label, this.emoji, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]));
}

// ── Weekly chart ──────────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final Color color;
  const _WeeklyChart({required this.sessions, required this.color});

  @override
  Widget build(BuildContext context) {
    // Bucket sessions by day of week
    final days = List.filled(7, 0);
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (final s in sessions) {
      try {
        final d = DateTime.parse(s['start_time'] as String).toLocal();
        final idx = (d.weekday - 1).clamp(0, 6);
        days[idx] += (s['steps'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    final maxVal = days.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Expanded(child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: maxVal > 0 ? (days[i] / maxVal).clamp(0.05, 1.0) : 0.05,
                  child: Container(
                    decoration: BoxDecoration(
                      color: days[i] > 0 ? color : AppColors.border,
                      borderRadius: BorderRadius.circular(4)))))),
              const SizedBox(height: 4),
              Text(labels[i], style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
            ])));
        })));
  }
}
