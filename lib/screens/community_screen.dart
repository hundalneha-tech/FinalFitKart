// lib/screens/community_screen.dart
// Friends list from `friendships` table + activity feed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  final _sb   = Supabase.instance.client;
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<Map<String,dynamic>> _friends   = [];
  List<Map<String,dynamic>> _requests  = [];
  bool _loadingFriends = true;

  final _searchC = TextEditingController();
  List<Map<String,dynamic>> _searchResults = [];
  bool _searching = false;

  @override
  void initState() { super.initState(); _loadFriends(); }

  @override
  void dispose() { _tab.dispose(); _searchC.dispose(); super.dispose(); }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loadingFriends = false); return; }
    try {
      final data = await _sb.from('friendships')
          .select('*, friend:profiles!friendships_friend_id_fkey(id,name,level,total_steps)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final accepted  = (data as List).where((f) => f['status'] == 'accepted').toList();
      final pending   = data.where((f) => f['status'] == 'pending').toList();

      if (mounted) setState(() {
        _friends  = List<Map<String,dynamic>>.from(accepted);
        _requests = List<Map<String,dynamic>>.from(pending);
        _loadingFriends = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingFriends = false); }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final uid = _sb.auth.currentUser?.id;
    try {
      final data = await _sb.from('profiles')
          .select('id, name, level, total_steps')
          .ilike('name', '%${q.trim()}%')
          .neq('id', uid ?? '')
          .limit(10);
      if (mounted) setState(() {
        _searchResults = List<Map<String,dynamic>>.from(data);
        _searching = false;
      });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  Future<void> _addFriend(String friendId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('friendships').insert({
        'user_id':   uid,
        'friend_id': friendId,
        'status':    'pending',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Friend request sent! 👋'), backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating));
    } catch (_) {}
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : '?');
  }

  String _fmtSteps(Map p) {
    final s = (p['total_steps'] as num?)?.toInt() ?? 0;
    return s > 999 ? '${(s/1000).toStringAsFixed(1)}k steps' : '$s steps';
  }

  static const _colors = [Color(0xFF6366F1), Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF2563EB)];
  Color _color(String id) => _colors[id.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size:18, color:AppColors.textPrimary), onPressed: ()=>Navigator.pop(context)),
      title: const Text('My Community', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      bottom: TabBar(
        controller: _tab, labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary, indicatorWeight: 2,
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: 'Friends (${_friends.length})'),
          Tab(text: _requests.isEmpty ? 'Find Friends' : 'Find (${_requests.length} pending)'),
        ])),
    body: TabBarView(controller: _tab, children: [

      // ── TAB 1: Friends list ──────────────────────────────
      _loadingFriends
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            color: AppColors.primary, onRefresh: _loadFriends,
            child: _friends.isEmpty
              ? _emptyFriends()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _friends.length,
                  itemBuilder: (_, i) {
                    final f = _friends[i]['friend'] as Map<String,dynamic>? ?? {};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(),
                      child: Row(children: [
                        Container(width: 46, height: 46,
                          decoration: BoxDecoration(color: _color(f['id']?.toString() ?? ''), shape: BoxShape.circle),
                          child: Center(child: Text(_initials(f['name'] as String? ?? '?'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f['name'] as String? ?? 'Unknown',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text(f['level'] as String? ?? 'Walker',
                            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ])),
                        Text(_fmtSteps(f), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ]));
                  })),

      // ── TAB 2: Find Friends ──────────────────────────────
      Column(children: [
        // Search bar
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Padding(padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20)),
              Expanded(child: TextField(
                controller: _searchC,
                onChanged: _search,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
              if (_searching) const Padding(padding: EdgeInsets.only(right: 14),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
            ]))),

        // Pending requests
        if (_requests.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Text('Pending Requests (${_requests.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ])),
          ..._requests.map((r) {
            final f = r['friend'] as Map<String,dynamic>? ?? {};
            return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(padding: const EdgeInsets.all(12), decoration: cardDecoration(),
                child: Row(children: [
                  Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: _color(f['id']?.toString() ?? ''), shape: BoxShape.circle),
                    child: Center(child: Text(_initials(f['name'] as String? ?? '?'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('Pending', style: TextStyle(fontSize: 11, color: const Color(0xFFB45309), fontWeight: FontWeight.w600)),
                ])));
          }),
        ],

        // Search results
        Expanded(child: _searchResults.isEmpty
          ? _searchHint()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _searchResults.length,
              itemBuilder: (_, i) {
                final p = _searchResults[i];
                return Container(margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12), decoration: cardDecoration(),
                  child: Row(children: [
                    Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: _color(p['id']?.toString() ?? ''), shape: BoxShape.circle),
                      child: Center(child: Text(_initials(p['name'] as String? ?? '?'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['name'] as String? ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(p['level'] as String? ?? 'Walker',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ])),
                    GestureDetector(onTap: () => _addFriend(p['id'] as String),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))),
                  ]));
              })),
      ]),
    ]),
  );

  Widget _emptyFriends() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('👥', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    const Text('No friends yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Find friends to compete with!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: () => _tab.animateTo(1),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: const Text('Find Friends', style: TextStyle(color: Colors.white))),
  ]));

  Widget _searchHint() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🔍', style: TextStyle(fontSize: 40)),
    const SizedBox(height: 12),
    const Text('Search by name', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
  ]));
}
