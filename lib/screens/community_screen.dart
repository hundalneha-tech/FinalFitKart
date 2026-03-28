// lib/screens/community_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'friend_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<Map<String, dynamic>> _friends     = [];
  List<Map<String, dynamic>> _incoming    = []; // requests sent TO me
  List<Map<String, dynamic>> _outgoing    = []; // requests I sent (pending)
  bool _loading = true;

  final _searchC = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Set<String> _sentIds = {}; // IDs already sent request to

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadFriends(), _loadIncoming(), _loadOutgoing()]);
    if (mounted) setState(() => _loading = false);
  }

  // Friends I already accepted (both directions)
  Future<void> _loadFriends() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // Sent by me and accepted
      final sent = await _sb.from('friendships')
          .select('*, friend:profiles!friendships_friend_id_fkey(id,name,level,total_steps)')
          .eq('user_id', uid)
          .eq('status', 'accepted');

      // Received by me and accepted
      final received = await _sb.from('friendships')
          .select('*, friend:profiles!friendships_user_id_fkey(id,name,level,total_steps)')
          .eq('friend_id', uid)
          .eq('status', 'accepted');

      final all = <Map<String, dynamic>>[];
      for (final f in sent as List)   all.add(Map<String, dynamic>.from(f));
      for (final f in received as List) {
        // Remap so 'friend' always points to the other person
        final m = Map<String, dynamic>.from(f);
        m['friend'] = f['friend']; // friend here is the sender
        all.add(m);
      }
      if (mounted) setState(() => _friends = all);
    } catch (e) {
      debugPrint('loadFriends error: $e');
    }
  }

  // Requests sent TO me (friend_id = my uid, status = pending)
  Future<void> _loadIncoming() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await _sb.from('friendships')
          .select('*, sender:profiles!friendships_user_id_fkey(id,name,level,total_steps)')
          .eq('friend_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _incoming = List<Map<String, dynamic>>.from(data as List));
    } catch (e) {
      debugPrint('loadIncoming error: $e');
    }
  }

  // Requests I sent (user_id = my uid, status = pending)
  Future<void> _loadOutgoing() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await _sb.from('friendships')
          .select('friend_id')
          .eq('user_id', uid)
          .eq('status', 'pending');
      if (mounted) setState(() {
        _sentIds = {for (final r in data as List) r['friend_id'] as String};
        _outgoing = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('loadOutgoing error: $e');
    }
  }

  // Accept incoming request
  Future<void> _acceptRequest(String senderId, String friendshipId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // Update the existing row to accepted
      await _sb.from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      // Notify sender their request was accepted
      await _sb.from('notifications').insert({
        'user_id': senderId,
        'title': 'Friend request accepted! 🎉',
        'body': 'Your friend request was accepted. You are now connected!',
        'type': 'friend_accepted',
        'is_read': false,
      });

      _snack('Friend request accepted! 🎉', green: true);
      await _loadAll();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  // Decline incoming request
  Future<void> _declineRequest(String friendshipId) async {
    try {
      await _sb.from('friendships').delete().eq('id', friendshipId);
      _snack('Request declined');
      await _loadIncoming();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  // Send friend request (user_id = me, friend_id = them)
  Future<void> _sendRequest(String friendId, String friendName) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;

    // Check not already friends or pending
    if (_sentIds.contains(friendId)) {
      _snack('Request already sent to $friendName');
      return;
    }

    try {
      await _sb.from('friendships').insert({
        'user_id':   uid,
        'friend_id': friendId,
        'status':    'pending',
      });

      // Get my name to include in notification
      final me = await _sb.from('profiles').select('name').eq('id', uid).single();
      final myName = me['name'] as String? ?? 'Someone';

      // Send notification to the recipient so they see it
      await _sb.from('notifications').insert({
        'user_id': friendId,
        'title':   '$myName sent you a friend request 👋',
        'body':    'Open the Community tab to accept or decline.',
        'type':    'friend_request',
        'is_read': false,
      });

      setState(() => _sentIds.add(friendId));
      _snack('Friend request sent to $friendName! 👋', green: true);
    } catch (e) {
      _snack('Failed to send request: $e');
    }
  }

  // Cancel outgoing request
  Future<void> _cancelRequest(String friendId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('friendships')
          .delete()
          .eq('user_id', uid)
          .eq('friend_id', friendId);
      setState(() => _sentIds.remove(friendId));
      _snack('Request cancelled');
    } catch (e) {
      _snack('Error: $e');
    }
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
          .limit(20);
      if (mounted) setState(() {
        _searchResults = List<Map<String, dynamic>>.from(data as List);
        _searching = false;
      });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  void _snack(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: green ? AppColors.green : AppColors.red,
      behavior: SnackBarBehavior.floating));
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
  }

  String _fmtSteps(Map p) {
    final s = (p['total_steps'] as num?)?.toInt() ?? 0;
    return s > 999 ? '${(s / 1000).toStringAsFixed(1)}k steps' : '$s steps';
  }

  static const _colors = [
    Color(0xFF6366F1), Color(0xFFF59E0B),
    Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF2563EB)
  ];
  Color _color(String id) => _colors[id.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('My Community',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      bottom: TabBar(
        controller: _tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary, indicatorWeight: 2,
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: 'Friends (${_friends.length})'),
          Tab(text: _incoming.isEmpty ? 'Find Friends' : 'Find (${_incoming.length} 🔔)'),
        ])),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : TabBarView(controller: _tab, children: [
          _buildFriendsTab(),
          _buildFindTab(),
        ]));

  // ── TAB 1: Friends list ───────────────────────────────────────────────────
  Widget _buildFriendsTab() => RefreshIndicator(
    color: AppColors.primary, onRefresh: _loadAll,
    child: _friends.isEmpty ? _emptyFriends()
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _friends.length,
          itemBuilder: (_, i) {
            final f = (_friends[i]['friend'] as Map<String, dynamic>?) ?? {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FriendProfileScreen(
                    friendId: f['id'] as String? ?? '',
                    friendName: f['name'] as String? ?? 'Friend',
                    avatarColor: _color(f['id']?.toString() ?? ''),
                  ))),
                child: Row(children: [
                  Container(width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _color(f['id']?.toString() ?? ''),
                      shape: BoxShape.circle),
                    child: Center(child: Text(
                      _initials(f['name'] as String? ?? '?'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f['name'] as String? ?? 'Unknown',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(f['level'] as String? ?? 'Walker',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ])),
                  Row(children: [
                    Text(_fmtSteps(f),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                  ]),
                ])));
          }));

  // ── TAB 2: Find Friends ───────────────────────────────────────────────────
  Widget _buildFindTab() => Column(children: [

    // Search bar
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Padding(padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20)),
          Expanded(child: TextField(
            controller: _searchC, onChanged: _search,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search by name...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
          if (_searching)
            const Padding(padding: EdgeInsets.only(right: 14),
              child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
        ]))),

    Expanded(child: RefreshIndicator(
      color: AppColors.primary, onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [

          // ── Incoming requests (REQUESTS SENT TO ME) ─────────────────
          if (_incoming.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Friend Requests (${_incoming.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 8),
            ..._incoming.map((r) {
              final sender = r['sender'] as Map<String, dynamic>? ?? {};
              final id = r['id']?.toString() ?? '';
              final senderId = r['user_id']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: Column(children: [
                  Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _color(sender['id']?.toString() ?? ''),
                        shape: BoxShape.circle),
                      child: Center(child: Text(
                        _initials(sender['name'] as String? ?? '?'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sender['name'] as String? ?? 'Unknown',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('${_fmtSteps(sender)}  ·  ${sender['level'] ?? 'Walker'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Wants to connect',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => _acceptRequest(senderId, id),
                      child: Container(
                        height: 38, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ])))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () => _declineRequest(id),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          SizedBox(width: 6),
                          Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        ])))),
                  ]),
                ]));
            }),
            const Divider(height: 20, color: AppColors.borderLight),
          ],

          // ── Search results ───────────────────────────────────────────
          if (_searchResults.isEmpty && _searchC.text.isEmpty && _incoming.isEmpty)
            _searchHint()
          else ..._searchResults.map((p) {
            final pid = p['id'] as String;
            final alreadyFriend = _friends.any((f) =>
              (f['friend'] as Map?)?.containsKey('id') == true &&
              (f['friend'] as Map)['id'] == pid);
            final isPending = _sentIds.contains(pid);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: cardDecoration(),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _color(pid), shape: BoxShape.circle),
                  child: Center(child: Text(
                    _initials(p['name'] as String? ?? '?'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(p['level'] as String? ?? 'Walker',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ])),
                if (alreadyFriend)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded, size: 12, color: AppColors.green),
                      SizedBox(width: 4),
                      Text('Friends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                    ]))
                else if (isPending)
                  GestureDetector(
                    onTap: () => _cancelRequest(pid),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.yellow.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                      ])))
                else
                  GestureDetector(
                    onTap: () => _sendRequest(pid, p['name'] as String? ?? ''),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_add_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]))),
              ]));
          }),
        ]))),
  ]);

  Widget _emptyFriends() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('👥', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    const Text('No friends yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Find friends to compete with!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: () => _tab.animateTo(1),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: const Text('Find Friends', style: TextStyle(color: Colors.white))),
  ]));

  Widget _searchHint() => const Padding(
    padding: EdgeInsets.only(top: 40),
    child: Column(children: [
      Text('🔍', style: TextStyle(fontSize: 40)),
      SizedBox(height: 12),
      Text('Search by name to find friends', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    ]));
}
