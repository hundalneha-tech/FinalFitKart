// lib/screens/social_screen.dart
// Real data: challenges + leaderboard from Supabase; join challenge wired
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'community_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _sb   = Supabase.instance.client;
  final _notif = NotificationService();
  bool  _weekly = true;

  List<Map<String,dynamic>> _challenges  = [];
  List<Map<String,dynamic>> _leaderboard = [];
  Set<String>               _joined      = {};
  bool _loadingC = true;
  bool _loadingL = true;
  RealtimeChannel? _leaderboardChannel;

  @override
  void initState() {
    super.initState();
    _notif.addListener(() { if (mounted) setState(() {}); });
    _loadChallenges();
    _loadLeaderboard();
    _subscribeLeaderboard();
  }

  @override
  void dispose() {
    _notif.removeListener(() {});
    _leaderboardChannel?.unsubscribe();
    super.dispose();
  }

  // ── Load challenges ──────────────────────────────────────
  Future<void> _loadChallenges() async {
    setState(() => _loadingC = true);
    final uid = _sb.auth.currentUser?.id;
    try {
      final data = await _sb.from('challenges')
          .select('*')
          .eq('is_active', true)
          .order('participant_count', ascending: false)
          .limit(6);
      _challenges = List<Map<String,dynamic>>.from(data);

      if (uid != null) {
        final joined = await _sb.from('challenge_participants')
            .select('challenge_id')
            .eq('user_id', uid);
        _joined = {for (final j in joined as List) j['challenge_id'] as String};
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingC = false);
  }

  // ── Load leaderboard ─────────────────────────────────────
  Future<void> _loadLeaderboard() async {
    setState(() => _loadingL = true);
    try {
      final period    = _weekly ? 'weekly'  : 'monthly';
      final now       = DateTime.now();
      final periodKey = _weekly
          ? '${now.year}-W${_isoWeek(now).toString().padLeft(2,'0')}'
          : '${now.year}-${now.month.toString().padLeft(2,'0')}';

      final data = await _sb.from('leaderboard_entries')
          .select('*, profile:profiles(name, level)')
          .eq('period', period)
          .eq('period_key', periodKey)
          .order('steps', ascending: false)
          .limit(20);
      _leaderboard = List<Map<String,dynamic>>.from(data);
    } catch (_) {}
    if (mounted) setState(() => _loadingL = false);
  }


  // ── Realtime: auto-refresh leaderboard on any change ─────
  void _subscribeLeaderboard() {
    _leaderboardChannel = _sb
        .channel('public:leaderboard_entries')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leaderboard_entries',
          callback: (payload) {
            debugPrint('Leaderboard update detected — refreshing');
            if (mounted) _loadLeaderboard();
          })
        .subscribe();
  }

  int _isoWeek(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final startOfYear = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(startOfYear).inDays) ~/ 7) + 1;
  }

  // ── Join challenge ────────────────────────────────────────
  Future<void> _joinChallenge(String challengeId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    // Optimistically mark as joined in UI immediately
    setState(() => _joined.add(challengeId));

    try {
      // Insert participant record (UNIQUE constraint prevents duplicates)
      await _sb.from('challenge_participants').insert({
        'challenge_id': challengeId,
        'user_id':      uid,
      });

      // Increment participant_count using rpc (call separately, not inside update)
      try {
        await _sb.rpc('increment_challenge_count', params: {'challenge_id': challengeId});
      } catch (_) {
        // Non-critical — count update fails silently, join still recorded
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Joined challenge! 🏃 Good luck!'),
        backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating));
    } catch (e) {
      // Revert optimistic update if truly failed (e.g. not a duplicate)
      final isDuplicate = e.toString().contains('duplicate') || e.toString().contains('23505');
      if (!isDuplicate) {
        setState(() => _joined.remove(challengeId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not join challenge. Please try again.'),
          backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating));
      }
      // If duplicate key error = already joined, keep the optimistic state (joined = true)
    }
  }

  // ── Share invite ──────────────────────────────────────────
  void _share() {
    Clipboard.setData(const ClipboardData(text: 'Join me on FitKart — walk to earn real money! 🚶 Download: fitkart.club'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Invite link copied! Share it with friends 📋'),
      backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating));
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : '?');
  }

  static const _podiumColors = [AppColors.primary, Color(0xFF6366F1), Color(0xFFF59E0B)];
  Color _color(int i) => _podiumColors[i % _podiumColors.length];

  String _challengeEmoji(Map c) {
    switch ((c['type'] as String?) ?? '') {
      case 'steps':    return '🏃';
      case 'distance': return '📍';
      case 'calories': return '🔥';
      case 'streak':   return '🌅';
      default:         return '⚡';
    }
  }

  String _timeLeft(Map c) {
    final end = c['end_time'] as String?;
    if (end == null) return 'Ongoing';
    try {
      final d = DateTime.parse(end).difference(DateTime.now());
      if (d.isNegative) return 'Ended';
      if (d.inDays > 0) return '${d.inDays}d left';
      return '${d.inHours}h left';
    } catch (_) { return ''; }
  }

  String _fmtParticipants(Map c) {
    final n = (c['participant_count'] as num?)?.toInt() ?? 0;
    return n > 999 ? '+${(n/1000).toStringAsFixed(1)}k joined' : '+$n joined';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async { await _loadChallenges(); await _loadLeaderboard(); },
      child: CustomScrollView(slivers: [

        // ── AppBar ─────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,14,16,8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Social Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Text('Compete with the community', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Stack(children: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _notif.refresh()),
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22)),
              if (_notif.unreadCount > 0)
                Positioned(top:6, right:6, child: Container(width:9, height:9,
                  decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
            ]),
          ]),
        )),

        // ── Action buttons ──────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,0,16,14),
          child: Row(children: [
            Expanded(child: GestureDetector(onTap: _share,
              child: Container(height: 44,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('👥', style: TextStyle(fontSize: 14)), SizedBox(width: 6),
                  Text('Invite Friends', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ])))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
              child: Container(height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('👥', style: TextStyle(fontSize: 14)), SizedBox(width: 6),
                  Text('My Community', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ])))),
          ]),
        )),

        // ── Trending Challenges — REAL DATA ─────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,0,16,10),
          child: Row(children: [
            const Text('Trending Challenges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
        )),
        SliverToBoxAdapter(child: SizedBox(
          height: (MediaQuery.of(context).size.height * 0.26).clamp(195.0, 230.0),
          child: _loadingC
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
            : _challenges.isEmpty
              ? const Center(child: Text('No active challenges', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16,0,16,4),
                  itemCount: _challenges.length,
                  itemBuilder: (_, i) => _ChallengeCard(
                    challenge:  _challenges[i],
                    emoji:      _challengeEmoji(_challenges[i]),
                    timeLeft:   _timeLeft(_challenges[i]),
                    joined:     _fmtParticipants(_challenges[i]),
                    isJoined:   _joined.contains(_challenges[i]['id']),
                    onJoin:     () => _joinChallenge(_challenges[i]['id'] as String),
                  )))),

        // ── Leaderboard — REAL DATA ──────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,4,16,12),
          child: Row(children: [
            const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            Container(padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                _tabPill('Weekly',  _weekly, () { setState(() => _weekly = true);  _loadLeaderboard(); }),
                _tabPill('Monthly', !_weekly, () { setState(() => _weekly = false); _loadLeaderboard(); }),
              ])),
          ]),
        )),

        // Podium (top 3)
        if (!_loadingL && _leaderboard.length >= 3)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,12),
            child: Container(padding: const EdgeInsets.all(16), decoration: cardDecoration(),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
                _PodiumCol(entry: _leaderboard[1], rank: 2, barH: 50, bordered: false, initials: _initials((_leaderboard[1]['profile'] as Map?)?['name'] ?? '')),
                Column(children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  _PodiumCol(entry: _leaderboard[0], rank: 1, barH: 70, bordered: true,  initials: _initials((_leaderboard[0]['profile'] as Map?)?['name'] ?? '')),
                ]),
                _PodiumCol(entry: _leaderboard[2], rank: 3, barH: 50, bordered: false, initials: _initials((_leaderboard[2]['profile'] as Map?)?['name'] ?? '')),
              ])))) ,

        if (_loadingL)
          const SliverToBoxAdapter(child: SizedBox(height: 120,
            child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) {
              final offset = _leaderboard.length >= 3 ? 3 : 0;
              if (i + offset >= _leaderboard.length) return null;
              final e   = _leaderboard[i + offset];
              final uid = _sb.auth.currentUser?.id;
              final isMe = e['user_id'] == uid;
              final name = (_leaderboard[i + offset]['profile'] as Map?)?['name'] as String? ?? 'Unknown';
              return _LbItem(rank: i + offset + 1, initials: _initials(name),
                color: _color(i + offset), name: name, isMe: isMe,
                steps: ((e['steps'] as num?)?.toInt() ?? 0).toString(),
                coins: ((e['coins_earned'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
            },
            childCount: (_leaderboard.length - (_leaderboard.length >= 3 ? 3 : 0)).clamp(0, 99),
          )),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    )),
  );

  Widget _tabPill(String label, bool active, VoidCallback onTap) =>
    GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(17)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textSecondary))));
}

// ── Challenge card ────────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  final Map<String,dynamic> challenge;
  final String emoji, timeLeft, joined;
  final bool isJoined;
  final VoidCallback onJoin;
  const _ChallengeCard({required this.challenge, required this.emoji, required this.timeLeft, required this.joined, required this.isJoined, required this.onJoin});

  String get _type {
    switch ((challenge['type'] as String?) ?? '') {
      case 'steps':    return 'Steps';
      case 'distance': return 'Distance';
      case 'calories': return 'Calories';
      case 'streak':   return 'Streak';
      default:         return 'Challenge';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 165, margin: const EdgeInsets.only(right: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isJoined ? AppColors.primary : AppColors.border.withOpacity(0.5), width: isJoined ? 1.5 : 1)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(children: [
        Container(height: 85, width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32)))),
        Positioned(top:8, left:8, child: Container(
          padding: const EdgeInsets.symmetric(horizontal:10, vertical:3),
          decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(20)),
          child: Text(_type, style: const TextStyle(fontSize:11, fontWeight:FontWeight.w800, color:Colors.black)))),
        Positioned(top:8, right:8, child: Text(timeLeft,
          style: const TextStyle(fontSize:10, color:Colors.white, fontWeight:FontWeight.w600))),
        if (isJoined)
          Positioned(bottom:8, right:8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal:8, vertical:2),
            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
            child: const Text('✓ Joined', style: TextStyle(fontSize:9, fontWeight:FontWeight.w800, color:Colors.white)))),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(10,8,10,8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(challenge['title'] as String? ?? '', style: const TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:AppColors.textPrimary), maxLines:1, overflow:TextOverflow.ellipsis),
          Padding(padding: const EdgeInsets.symmetric(vertical:2),
            child: Text(joined, style: const TextStyle(fontSize:10, color:AppColors.textSecondary))),
          SizedBox(width: double.infinity, height: 30,
            child: ElevatedButton(
              onPressed: isJoined ? null : onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: isJoined ? AppColors.green : AppColors.primary,
                disabledBackgroundColor: AppColors.green,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              child: Text(isJoined ? '✓ Joined' : 'Join Challenge',
                style: const TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:Colors.white)))),
        ])),
    ]));
}

// ── Podium column ─────────────────────────────────────────────────────────────
class _PodiumCol extends StatelessWidget {
  final Map<String,dynamic> entry; final int rank; final double barH; final bool bordered; final String initials;
  const _PodiumCol({required this.entry, required this.rank, required this.barH, required this.bordered, required this.initials});

  static const _colors = [AppColors.primary, Color(0xFF6366F1), Color(0xFFF59E0B)];
  Color get _color => _colors[(rank - 1).clamp(0, 2)];

  String get _name {
    final p = entry['profile'] as Map?;
    final n = p?['name'] as String? ?? 'Unknown';
    return n.length > 8 ? n.split(' ').first : n;
  }
  String get _steps {
    final s = (entry['steps'] as num?)?.toInt() ?? 0;
    return s > 999 ? '${(s/1000).toStringAsFixed(1)}k' : '$s';
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: bordered ? 56 : 44, height: bordered ? 56 : 44,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle,
        border: bordered ? Border.all(color: AppColors.yellow, width: 3) : null),
      child: Center(child: Text(initials, style: TextStyle(fontSize: bordered ? 16 : 14, fontWeight: FontWeight.w800, color: Colors.white)))),
    const SizedBox(height: 4),
    Text(_name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    Text(_steps, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    const SizedBox(height: 4),
    Container(width: 36, height: barH,
      decoration: BoxDecoration(
        color: rank == 1 ? AppColors.yellow : AppColors.border,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
      child: Center(child: Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
        color: rank == 1 ? Colors.black : AppColors.textSecondary)))),
  ]);
}

// ── Leaderboard item ──────────────────────────────────────────────────────────
class _LbItem extends StatelessWidget {
  final int rank; final String initials, name, steps, coins; final Color color; final bool isMe;
  const _LbItem({required this.rank, required this.initials, required this.color, required this.name, required this.steps, required this.coins, required this.isMe});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16,0,16,8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14,12,14,12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? AppColors.primary : AppColors.border.withOpacity(0.5), width: isMe ? 1.5 : 1),
        boxShadow: isMe ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10)] : null),
      child: Row(children: [
        SizedBox(width: 24, child: Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: isMe ? AppColors.primary : AppColors.textSecondary))),
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text('🚶 $steps steps', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(coins, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text('FKC', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ])));
}
