// lib/screens/profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'wallet_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _sb = Supabase.instance.client;
  Map<String,dynamic>? _profile;
  Map<String,dynamic>? _wallet;
  List<Map<String,dynamic>> _causes = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }

    // Load profile + causes independently so one failure doesn't block the other
    try {
      final p = await _sb.from('profiles').select('*, wallets(*)').eq('id', uid).single();
      if (mounted) setState(() {
        _profile = p;
        final w = p['wallets'];
        _wallet  = w is List ? (w as List).firstOrNull as Map<String,dynamic>? : w as Map<String,dynamic>?;
      });
    } catch (_) {}

    try {
      final causes = await _sb.from('causes')
          .select('*').eq('is_active', true)
          .order('current_coins', ascending: false);
      if (mounted) setState(() {
        _causes = List<Map<String,dynamic>>.from(causes as List);
      });
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // ── Getters ──────────────────────────────────────────────
  String get _name => _profile?['name'] ?? _sb.auth.currentUser?.email?.split('@')[0] ?? 'Walker';
  String get _initials {
    final parts = _name.trim().split(' ');
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : _name[0].toUpperCase();
  }
  double get _balance => (_wallet?['balance'] as num?)?.toDouble() ?? 0;
  int    get _steps   => (_profile?['total_steps'] as num?)?.toInt() ?? 0;
  double get _inr     => _balance * 0.33;
  String get _level   => _profile?['level'] ?? 'Walker';
  String _fmt(int n)  => n > 999999 ? '${(n/1000000).toStringAsFixed(1)}M' : n > 999 ? '${(n/1000).toStringAsFixed(1)}k' : '$n';

  // ── Donate flow ──────────────────────────────────────────
  Future<void> _openDonateFlow([Map<String,dynamic>? preselectedCause]) async {
    if (_causes.isEmpty) { _snack('No active causes available'); return; }
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _DonateSheet(
        causes:   _causes,
        balance:  _balance,
        preselected: preselectedCause,
        onDonate: (causeId, coins) => _processDonation(causeId, coins),
      ));
    _load(); // refresh balance after donation
  }

  Future<bool> _processDonation(String causeId, int coins) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      // Deduct coins
      await _sb.rpc('transact_coins', params: {
        'p_user_id':    uid,
        'p_amount':     -coins,
        'p_type':       'SPEND_DONATE',
        'p_description': 'Donation to cause',
        'p_ref_id':     causeId,
        'p_ref_type':   'cause',
      });
      // Record donation (trigger updates cause.current_coins)
      await _sb.from('donations').insert({
        'user_id':      uid,
        'cause_id':     causeId,
        'coins_donated': coins,
        'inr_value':    (coins * 0.33).toStringAsFixed(2),
        'status':       'pending',
      });
      return true;
    } catch (e) {
      if (mounted) _snack('Donation failed: ${e.toString().split(']').last}');
      return false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
    ));
  }

  void _showProDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(gradient: AppColors.grad, shape: BoxShape.circle),
          child: const Center(child: Text('🌟', style: TextStyle(fontSize: 36)))),
        const SizedBox(height: 16),
        const Text('FitKart Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Unlock premium features', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ...[
          ('🚀', '3× Coin Multiplier', 'Triple your daily FKC earnings'),
          ('📊', 'Advanced Analytics', 'Detailed step & earnings charts'),
          ('🎯', 'Exclusive Challenges', 'Pro-only high-reward challenges'),
          ('⚡', 'Unlimited Boosts', 'Activate 2× boost anytime'),
          ('🏆', 'Pro Badge', 'Stand out on the leaderboard'),
        ].map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Text(f.$1, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(f.$3, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
          ]))),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('₹299 / month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(width: 8),
            Text('or ₹2,499/yr', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _snack('Pro upgrade coming soon! 🚀 We will notify you when it launches.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Get Pro — Coming Soon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Maybe later', style: TextStyle(color: AppColors.textSecondary))),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : SafeArea(child: RefreshIndicator(
          color: AppColors.primary, onRefresh: _load,
          child: CustomScrollView(slivers: [

            // ── Header ─────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,14,16,8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Stack(children: [
                  Container(width: 62, height: 62,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                      shape: BoxShape.circle),
                    child: Center(child: Text(_initials,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)))),
                  Positioned(bottom:1, right:1, child: Container(width:18, height:18,
                    decoration: BoxDecoration(color:AppColors.green, shape:BoxShape.circle,
                      border: Border.all(color:Colors.white, width:2)),
                    child: const Center(child: Icon(Icons.check, color:Colors.white, size:9)))),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Text(_level, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const Text('🏆 Top 5% this week', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
              ]),
            )),

            // ── SOS banner ─────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14,12,14,12),
                decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red.withOpacity(0.2))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
                    child: const Text('SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Emergency SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
                    const Text('Instantly alert your emergency contacts...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                  ])),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ]),
              ),
            )),

            // ── Wallet card ─────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Total Balance', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text('≈ ₹${_inr.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                  ]),
                  const SizedBox(height: 6),
                  Text('${_balance.toStringAsFixed(0)} FKC',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 8),
                  // ← WIRED: Navigate to Wallet History
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletHistoryScreen())),
                    child: const Row(children: [
                      Icon(Icons.history_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text('View Wallet History', style: TextStyle(fontSize: 13, color: Colors.white70)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                    ]),
                  ),
                ]),
              ),
            )),

            // ── Lifetime stats ──────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,14),
              child: Row(children: [
                Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primaryBg, shape: BoxShape.circle),
                      child: const Center(child: Text('🚶', style: TextStyle(fontSize: 18)))),
                    const SizedBox(height: 10),
                    Text(_fmt(_steps), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const Text('LIFETIME STEPS', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.3)),
                  ]))),
                const SizedBox(width: 12),
                Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFFFF1F0), shape: BoxShape.circle),
                      child: const Center(child: Text('🔥', style: TextStyle(fontSize: 18)))),
                    const SizedBox(height: 10),
                    Text(_steps > 0 ? '${(_steps*0.04/1000).toStringAsFixed(1)}k' : '0',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const Text('CALORIES BURNT', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.3)),
                  ]))),
              ]),
            )),

            // ── Walk for a Cause ────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,4),
              child: Row(children: [
                const Text('Walk for a Cause', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
            )),
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.fromLTRB(16,0,16,8),
              child: Text('Convert your steps into real-world impact', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            )),

            // ── Cause cards — REAL DATA — adaptive height ────
            SliverToBoxAdapter(child: _causes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
              : LayoutBuilder(builder: (ctx, constraints) {
                  // Card height = image (70) + padding+text+bar+row (≈105) = 175 min
                  // Add 10% of screen height as breathing room for larger fonts/densities
                  final cardH = (MediaQuery.of(ctx).size.height * 0.22).clamp(175.0, 240.0);
                  return SizedBox(
                    height: cardH,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16,0,16,4),
                      itemCount: _causes.length,
                      itemBuilder: (_, i) => _CauseCard(
                        cause: _causes[i],
                        cardHeight: cardH,
                        onDonate: () => _openDonateFlow(_causes[i]),
                      )));
                })),

            // ── Donate button ────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,12,16,0),
              child: GestureDetector(
                onTap: _openDonateFlow,   // ← WIRED
                child: Container(height: 50, width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('❤️', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Donate Coins Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]))),
            )),

            // ── Account Settings ─────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,16,16,0),
              child: Container(decoration: cardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.fromLTRB(16,14,16,8),
                  child: Text('Account Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                _SettingRow(icon: '👤', label: 'Personal Information', sub: 'Name, Email, Connected Devices',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(page: SettingsPage.personalInfo)))),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _SettingRow(icon: '💳', label: 'Withdrawal Methods', sub: 'UPI, Bank Account, Gift Cards',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(page: SettingsPage.withdrawal)))),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _SettingRow(icon: '❤️', label: 'Donation Preferences', sub: 'Causes you care about',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(page: SettingsPage.donationPrefs)))),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _SettingRow(icon: '🔒', label: 'Privacy & Security', sub: 'App lock, Data sharing',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen(page: SettingsPage.privacy)))),
              ])),
            )),

            // ── Upgrade + Sign Out ───────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,12,16,0),
              child: Container(height: 50,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🌟', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('Upgrade to Pro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ])),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16,8,16,24),
              child: GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('You will need to sign in again.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out', style: TextStyle(color: Colors.white))),
                    ]));
                  if (ok == true) await _sb.auth.signOut();
                },
                child: Container(height: 46, width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.redBg)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.logout, color: AppColors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
                  ]))),
            )),
          ]),
        )),
  );
}

// ── Donate bottom sheet ───────────────────────────────────────────────────────
class _DonateSheet extends StatefulWidget {
  final List<Map<String,dynamic>> causes;
  final double balance;
  final Map<String,dynamic>? preselected;
  final Future<bool> Function(String causeId, int coins) onDonate;
  const _DonateSheet({required this.causes, required this.balance, required this.onDonate, this.preselected});
  @override State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet> {
  late Map<String,dynamic> _selected;
  int _coins = 50;
  bool _donating = false;

  final _amounts = [10, 25, 50, 100, 250, 500];

  String _causeEmoji(Map c) {
    final t = (c['title'] as String? ?? '').toLowerCase();
    if (t.contains('water'))  return '💧';
    if (t.contains('forest') || t.contains('tree')) return '🌱';
    if (t.contains('animal') || t.contains('stray')) return '🐾';
    return '❤️';
  }

  double _progress(Map c) {
    final cur = (c['current_coins'] as num?)?.toDouble() ?? 0;
    final tgt = (c['target_coins']  as num?)?.toDouble() ?? 1;
    return (cur / tgt).clamp(0.0, 1.0);
  }

  @override void initState() {
    super.initState();
    _selected = widget.preselected ?? widget.causes.first;
  }

  Future<void> _submit() async {
    if (_coins > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not enough FKC balance!'), backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _donating = true);
    final ok = await widget.onDonate(_selected['id'] as String, _coins);
    if (mounted) {
      setState(() => _donating = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Donated $_coins FKC to ${_selected['title']} ❤️'),
          backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99))),

      const Text('Donate Coins', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('Balance: ${widget.balance.toStringAsFixed(0)} FKC',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 20),

      // Cause selector
      const Align(alignment: Alignment.centerLeft,
        child: Text('Choose Cause', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      const SizedBox(height: 10),
      ...widget.causes.map((c) {
        final sel = _selected['id'] == c['id'];
        return GestureDetector(
          onTap: () => setState(() => _selected = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1)),
            child: Row(children: [
              Text(_causeEmoji(c), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['title'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(c['ngo_name'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: _progress(c), minHeight: 3,
                    backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.green))),
              ])),
              if (sel) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ])));
      }),

      const SizedBox(height: 16),
      const Align(alignment: Alignment.centerLeft,
        child: Text('Donation Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      const SizedBox(height: 10),

      // Amount chips
      Wrap(spacing: 8, runSpacing: 8, children: _amounts.map((a) {
        final sel = _coins == a;
        return GestureDetector(
          onTap: () => setState(() => _coins = a),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
            child: Text('$a FKC', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.textPrimary))));
      }).toList()),

      const SizedBox(height: 8),
      Text('≈ ₹${(_coins * 0.33).toStringAsFixed(2)} real-world value',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 20),

      // Confirm
      SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: _donating ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _donating
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Donate $_coins FKC ❤️',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
    ])));
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final String icon, label, sub;
  final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.label, required this.sub, this.onTap});

  @override Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16,13,16,13),
        child: Row(children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(sub,   style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
        ]))));
}

class _CauseCard extends StatelessWidget {
  final Map<String,dynamic> cause;
  final VoidCallback onDonate;
  final double cardHeight;
  const _CauseCard({required this.cause, required this.onDonate, this.cardHeight = 200});

  String get _emoji {
    final t = (cause['title'] as String? ?? '').toLowerCase();
    if (t.contains('water'))  return '💧';
    if (t.contains('forest') || t.contains('tree')) return '🌱';
    if (t.contains('animal') || t.contains('stray')) return '🐾';
    return '❤️';
  }

  String get _gradientKey {
    final t = (cause['title'] as String? ?? '').toLowerCase();
    if (t.contains('water')) return 'blue';
    if (t.contains('forest') || t.contains('tree')) return 'green';
    return 'pink';
  }

  List<Color> get _gradient {
    switch (_gradientKey) {
      case 'blue':  return [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)];
      case 'green': return [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)];
      default:      return [const Color(0xFFFFF0F6), const Color(0xFFFFE4EF)];
    }
  }

  double get _progress {
    final cur = (cause['current_coins'] as num?)?.toDouble() ?? 0;
    final tgt = (cause['target_coins']  as num?)?.toDouble() ?? 1;
    return (cur / tgt).clamp(0.0, 1.0);
  }

  String get _progressLabel {
    final pct = (_progress * 100).toStringAsFixed(0);
    final tgt = (cause['target_coins'] as num?)?.toInt() ?? 0;
    final tgtLabel = tgt > 999999 ? '${(tgt/1000000).toStringAsFixed(0)}M' : tgt > 999 ? '${(tgt/1000).toStringAsFixed(0)}k' : '$tgt';
    return '$pct% of ${tgtLabel}c';
  }

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onDonate,
    child: Container(
      width: 162, margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: (cardHeight * 0.40).clamp(65.0, 95.0), width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradient),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 36)))),
        Padding(padding: const EdgeInsets.fromLTRB(9,6,9,6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(cause['title'] as String? ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Padding(padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(_progressLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
            ClipRRect(borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: _progress, minHeight: 4,
                backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.green))),
            const SizedBox(height: 4),
            const Row(children: [
              Text('Donate Coins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              Spacer(),
              Text('❤️', style: TextStyle(fontSize: 12)),
            ]),
          ])),
      ])));
}
