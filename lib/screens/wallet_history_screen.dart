// lib/screens/wallet_history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});
  @override State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  final _sb     = Supabase.instance.client;
  final _scroll = ScrollController();

  List<Map<String,dynamic>> _txns    = [];
  bool   _loading   = true;
  bool   _loadingMore = false;
  bool   _hasMore   = true;
  String _filter    = 'All';   // All | Earned | Spent
  static const _pageSize = 20;

  final _filters = ['All', 'Earned', 'Spent'];

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200
        && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _txns = []; _hasMore = true; });
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      var q = _sb.from('coin_transactions')
          .select('id, type, amount, balance_after, description, created_at')
          .eq('user_id', uid);
      if (_filter == 'Earned') q = q.gt('amount', 0);
      if (_filter == 'Spent')  q = q.lt('amount', 0);
      final data = await q
          .order('created_at', ascending: false)
          .limit(_pageSize);
      if (mounted) setState(() {
        _txns    = List<Map<String,dynamic>>.from(data);
        _loading = false;
        _hasMore = data.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_txns.isEmpty) return;
    setState(() => _loadingMore = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loadingMore = false); return; }
    try {
      final last = _txns.last['created_at'] as String;
      var q = _sb.from('coin_transactions')
          .select('id, type, amount, balance_after, description, created_at')
          .eq('user_id', uid)
          .lt('created_at', last);
      if (_filter == 'Earned') q = q.gt('amount', 0);
      if (_filter == 'Spent')  q = q.lt('amount', 0);
      final data = await q
          .order('created_at', ascending: false)
          .limit(_pageSize);
      if (mounted) setState(() {
        _txns.addAll(List<Map<String,dynamic>>.from(data));
        _loadingMore = false;
        _hasMore = data.length == _pageSize;
      });
    } catch (_) { if (mounted) setState(() => _loadingMore = false); }
  }

  // ── Helpers ──────────────────────────────────────────────
  bool   _isCredit(Map t) => ((t['amount'] as num?) ?? 0) > 0;
  String _fmtAmount(Map t) {
    final amt = (t['amount'] as num?)?.toDouble() ?? 0;
    final sign = amt >= 0 ? '+' : '';
    return '$sign${amt.toStringAsFixed(0)} FKC';
  }
  String _fmtDate(Map t) {
    try {
      final dt = DateTime.parse(t['created_at']).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m = dt.minute.toString().padLeft(2,'0');
        final p = dt.hour >= 12 ? 'PM' : 'AM';
        return 'Today $h:$m $p';
      }
      return '${dt.day} ${months[dt.month-1]} ${dt.year}';
    } catch (_) { return ''; }
  }

  // Icon + colour per transaction type
  (IconData, Color, Color) _typeStyle(Map t) {
    final type = (t['type'] as String?) ?? '';
    if (type.startsWith('EARN'))  return (Icons.add_circle_outline_rounded, AppColors.green,      AppColors.greenBg);
    if (type == 'REDEEM_PERK' || type == 'SPEND_REDEEM') return (Icons.card_giftcard_rounded, AppColors.primary, AppColors.primaryBg);
    if (type == 'SPEND_DONATE')   return (Icons.favorite_rounded,       AppColors.accent,      AppColors.accentBg);
    if (type.startsWith('ADMIN')) return (Icons.admin_panel_settings_outlined, AppColors.yellow, AppColors.coinBg);
    if (type == 'REFUND')         return (Icons.undo_rounded,           AppColors.green,       AppColors.greenBg);
    return (Icons.swap_horiz_rounded, AppColors.textSecondary, AppColors.borderLight);
  }

  String _typeLabel(Map t) {
    switch ((t['type'] as String?) ?? '') {
      case 'EARN_STEPS':     return 'Steps Reward';
      case 'EARN_WORKOUT':   return 'Workout Bonus';
      case 'EARN_CHALLENGE': return 'Challenge Reward';
      case 'EARN_REFERRAL':  return 'Referral Bonus';
      case 'EARN_BONUS':     return 'Bonus Credit';
      case 'REDEEM_PERK':
      case 'SPEND_REDEEM':   return 'Perk Redeemed';
      case 'SPEND_DONATE':   return 'Donation';
      case 'ADMIN_CREDIT':   return 'Admin Credit';
      case 'ADMIN_DEBIT':    return 'Admin Debit';
      case 'REFUND':         return 'Refund';
      default:               return 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('Wallet History',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _load),
      ],
    ),
    body: Column(children: [

      // ── Filter chips ──────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: _filters.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() => _filter = f); _load(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppColors.primary : AppColors.border)),
                child: Text(f, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary)))));
        }).toList()),
      ),

      // ── Transaction list ──────────────────────────────────
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _txns.isEmpty
          ? _empty()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _txns.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _txns.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
                  }
                  return _TxnRow(
                    txn:       _txns[i],
                    isCredit:  _isCredit(_txns[i]),
                    amount:    _fmtAmount(_txns[i]),
                    date:      _fmtDate(_txns[i]),
                    label:     _typeLabel(_txns[i]),
                    typeStyle: _typeStyle(_txns[i]),
                  );
                },
              ))),
    ]),
  );

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🪙', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    Text(_filter == 'All' ? 'No transactions yet' : 'No ${_filter.toLowerCase()} transactions',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Start walking to earn FKC!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
  ]));
}

class _TxnRow extends StatelessWidget {
  final Map<String,dynamic> txn;
  final bool     isCredit;
  final String   amount, date, label;
  final (IconData, Color, Color) typeStyle;
  const _TxnRow({required this.txn, required this.isCredit, required this.amount,
    required this.date, required this.label, required this.typeStyle});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = typeStyle;
    final desc = (txn['description'] as String?)?.isNotEmpty == true ? txn['description'] as String : null;
    final balAfter = (txn['balance_after'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(children: [
        // Icon
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        // Label + desc
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (desc != null)
            Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
        // Amount + balance
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: isCredit ? AppColors.green : AppColors.red)),
          if (balAfter != null)
            Text('Bal: ${balAfter.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}
