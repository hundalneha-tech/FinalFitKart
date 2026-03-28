// lib/screens/home_screen.dart — pixel-perfect match to HTML preview
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_history_screen.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/pedometer_service.dart';
import '../widgets/redeem_flow.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/boost_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sb    = Supabase.instance.client;
  final _boost = BoostService();
  final _notif = NotificationService();
  Map<String,dynamic>? _profile;
  Map<String,dynamic>? _wallet;
  int _liveSteps    = 0;
  bool _activating  = false;
  List<double> _weeklyCoins = List.filled(7, 0.0); // Mon–Sun FKC earned
  StreamSubscription? _stepsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _boost.addListener(() { if (mounted) setState(() {}); });
    _notif.addListener(() { if (mounted) setState(() {}); });
    _boost.load();
    _notif.refresh();
    // Subscribe to live step stream
    _liveSteps = PedometerService().todaySteps;
    _stepsSub = PedometerService().stepsStream.listen((steps) {
      if (mounted) setState(() => _liveSteps = steps);
    });
  }

  @override
  void dispose() {
    _stepsSub?.cancel();
    _boost.removeListener(() {});
    _notif.removeListener(() {});
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await _sb.from('profiles').select('*, wallets(*)').eq('id', uid).single();
      if (mounted) setState(() {
        _profile = p;
        final w = p['wallets'];
        _wallet = w is List ? (w as List).firstOrNull : w;
      });
    } catch (_) {}
    await _loadWeeklyEarnings();
  }

  Future<void> _loadWeeklyEarnings() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // Get start of current week (Monday)
      final now   = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start  = DateTime(monday.year, monday.month, monday.day);
      final end    = start.add(const Duration(days: 7));

      final data = await _sb.from('coin_transactions')
          .select('amount, created_at')
          .eq('user_id', uid)
          .gt('amount', 0)  // earned only
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String());

      final buckets = List.filled(7, 0.0);
      for (final tx in data as List) {
        final dt  = DateTime.tryParse(tx['created_at'] as String? ?? '')?.toLocal();
        if (dt == null) continue;
        final idx = (dt.weekday - 1).clamp(0, 6); // Mon=0 … Sun=6
        buckets[idx] += (tx['amount'] as num?)?.toDouble() ?? 0;
      }

      // Normalise to 0.0–1.0 for chart height
      final maxVal = buckets.reduce((a,b) => a>b?a:b);
      final normalised = maxVal > 0
          ? buckets.map((v) => (v / maxVal).clamp(0.0, 1.0)).toList()
          : buckets;

      if (mounted) setState(() => _weeklyCoins = normalised);
    } catch (_) {}
  }

  String get _initials {
    final n = (_profile?['name'] ?? _sb.auth.currentUser?.email?.split('@')[0] ?? 'W').trim().split(' ');
    return n.length >= 2 ? '${n[0][0]}${n[1][0]}'.toUpperCase() : n[0][0].toUpperCase();
  }
  double get _balance => (_wallet?['balance'] as num?)?.toDouble() ?? 0;
  int    get _steps   => _liveSteps > 0 ? _liveSteps : ((_profile?['total_steps'] as num?)?.toInt() ?? 0);
  double get _inr     => _balance * 0.33;

  @override
  Widget build(BuildContext context) {
    final perks = Perk.mockList();
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(slivers: [

          // ── AppBar ─────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,14,16,8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Rewards', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Text('Keep moving, keep earning', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Stack(children: [
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _notif.refresh()),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22)),
                if (_notif.unreadCount > 0)
                  Positioned(top: 4, right: 4, child: Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
              ]),
              const SizedBox(width: 8),
              Container(width: 40, height: 40,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]), shape: BoxShape.circle),
                child: Center(child: Text(_initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)))),
            ]),
          )),

          // ── Balance card ────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,4,16,12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current Balance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(children: [
                  Text('₹${_inr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
                    child: const Text('+12.5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))),
                ]),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(children: [
                  CoinDot(),
                  const SizedBox(width: 6),
                  Text('${_balance.toStringAsFixed(0)} Coins Earned', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Text('View History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ]),
              ]),
            ),
          )),

          // ── Stats row ───────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,12),
            child: Row(children: [
              Expanded(child: _StatMini(icon: '🚶', bg: const Color(0xFFEFF6FF), val: _steps.toString(), lbl: 'Steps')),
              const SizedBox(width: 12),
              Expanded(child: _StatMini(icon: '🔥', bg: const Color(0xFFFFF1F0), val: '320', lbl: 'Kcal')),
            ]),
          )),

          // ── Daily Goal ──────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Daily Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  const Text('64%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(99),
                  child: const LinearProgressIndicator(value: 0.64, minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary))),
                const SizedBox(height: 8),
                Row(children: [
                  Text('${_steps.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m)=>'${m[1]},')} / 10,000 steps',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  const Text('✓ On track', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ]),
            ),
          )),

          // ── Featured Perks header ───────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,10),
            child: Row(children: [
              const Text('Featured Perks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          )),

          // ── Perks horizontal scroll ─────────────────────────
          SliverToBoxAdapter(child: SizedBox(
            height: 225,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16,0,16,4),
              children: perks.take(4).map((p) => _PerkCard(perk: p)).toList(),
            ),
          )),

          // ── My Activity button ───────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,14,16,0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityHistoryScreen())),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18,14,18,14),
                decoration: cardDecoration(),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('📊', style: TextStyle(fontSize: 22)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('My Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const Text('Day · Week · Month — Heart Points & Steps', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
                ]),
              ),
            ),
          )),

          // ── Weekly Earning Trend chart ──────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,14,16,0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Weekly Earning Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('This week', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 14),
                _WeekChart(data: _weeklyCoins, labels: const ['M','T','W','T','F','S','S'], todayIndex: DateTime.now().weekday - 1),
              ]),
            ),
          )),

          // ── Boost banner ────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,14,16,0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18,14,18,14),
              decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ListenableBuilder(listenable: _boost, builder: (_,__) =>
                    Text(_boost.isActive ? '2× Boost ACTIVE! 🚀' : 'Double your coins!',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                  const SizedBox(height: 2),
                  ListenableBuilder(listenable: _boost, builder: (_,__) =>
                    Text(_boost.isActive ? 'Expires in ${_boost.remainingLabel} — keep walking!' : 'Activate 2x boost for the next 30 minutes',
                      style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.5)))),
                ])),
                GestureDetector(
                  onTap: _boost.isActive ? null : () async {
                    setState(() => _activating = true);
                    await _boost.activate();
                    setState(() => _activating = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: _boost.isActive ? AppColors.green : Colors.black,
                      borderRadius: BorderRadius.circular(20)),
                    child: _activating
                      ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                      : Text(
                          _boost.isActive ? _boost.remainingLabel : 'Activate',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))),
              ]),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      )),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _StatMini extends StatelessWidget {
  final String icon, val, lbl; final Color bg;
  const _StatMini({required this.icon, required this.bg, required this.val, required this.lbl});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border.withOpacity(0.5)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0,1))]),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 16)))),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(lbl, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ]));
}

String _perkEmoji(String cat) {
  switch(cat) {
    case 'Fashion': return '👗';
    case 'Food': return '🍔';
    case 'Entertainment': return '🎬';
    case 'Beauty': return '💄';
    default: return '🎁';
  }
}

class _PerkCard extends StatelessWidget {
  final Perk perk;
  const _PerkCard({required this.perk});
  @override Widget build(BuildContext context) => Container(
    width: 160, margin: const EdgeInsets.only(right: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border.withOpacity(0.5)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        Container(height: 120, width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          child: Center(child: Text(_perkEmoji(perk.category), style: const TextStyle(fontSize: 42)))),
        Positioned(top: 8, right: 8,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(20)),
            child: Text(perk.discountLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)))),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(perk.brand, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(perk.description, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          CoinDot(),
          const SizedBox(width: 4),
          Text('${perk.coins}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(onTap: () => RedeemFlow.start(context, perk),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: const Text('Redeem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
        ]),
      ])),
    ]));
}

class _WeekChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final int todayIndex;
  const _WeekChart({required this.data, required this.labels, this.todayIndex = -1});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((v) => v > 0);
    return Column(children: [
      SizedBox(height: 100,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i=0; i<data.length; i++) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              // Value label on top if has data
              if (hasData && data[i] > 0)
                const SizedBox(height: 2),
              Expanded(child: Align(alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: data[i] > 0 ? data[i].clamp(0.05, 1.0) : 0.03,
                  child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: i == todayIndex
                        ? [AppColors.accent, AppColors.accent.withOpacity(0.8)]
                        : data[i] > 0
                          ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                          : [AppColors.border, AppColors.border]),
                    borderRadius: BorderRadius.circular(4)))))),
              const SizedBox(height: 6),
              Text(labels[i], style: TextStyle(
                fontSize: 11,
                fontWeight: i == todayIndex ? FontWeight.w800 : FontWeight.w400,
                color: i == todayIndex ? AppColors.primary : AppColors.textSecondary)),
            ])))
        ])),
      if (!hasData) ...[
        const SizedBox(height: 8),
        const Text('No earnings yet this week — start walking!',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    ]);
  }
}
