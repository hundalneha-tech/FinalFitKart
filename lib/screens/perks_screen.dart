// lib/screens/perks_screen.dart
// Perks loaded from Supabase `perks` table — real data, category filter, real balance
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/redeem_flow.dart';

class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});
  @override State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  final _sb = Supabase.instance.client;

  List<Map<String,dynamic>> _allPerks  = [];
  List<Map<String,dynamic>> _filtered  = [];
  double  _balance  = 0;
  bool    _loading  = true;
  String  _cat      = 'All';

  // Category chips — label shown in UI → DB value filter
  final _cats = ['All', 'Fashion', 'Food', 'Entertainment', 'Beauty', 'Fitness'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _sb.auth.currentUser?.id;
    try {
      final perksData = await _sb.from('perks')
          .select('id, brand, category, description, discount_label, coin_price, is_featured, is_active')
          .eq('is_active', true)
          .order('is_featured', ascending: false)
          .order('coin_price');

      double bal = 0;
      if (uid != null) {
        try {
          final w = await _sb.from('wallets').select('balance').eq('user_id', uid).single();
          bal = (w['balance'] as num?)?.toDouble() ?? 0;
        } catch (_) {}
      }

      if (mounted) setState(() {
        _allPerks = List<Map<String,dynamic>>.from(perksData as List);
        _balance  = bal;
        _applyFilter();
        _loading  = false;
      });
    } catch (_) {
      // Fallback to mock if DB query fails (e.g. no perks seeded yet)
      if (mounted) setState(() {
        _allPerks = Perk.mockList().map((p) => {
          'id': p.id, 'brand': p.brand, 'category': p.category,
          'description': p.description, 'discount_label': p.discountLabel,
          'coin_price': p.coins, 'is_featured': p.isFeatured, 'is_active': true,
        }).toList();
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    if (_cat == 'All') {
      _filtered = List.from(_allPerks);
    } else {
      _filtered = _allPerks.where((p) => p['category'] == _cat).toList();
    }
  }

  void _onCatTap(String cat) {
    setState(() { _cat = cat; _applyFilter(); });
  }

  // Convert DB map → Perk model for RedeemFlow
  Perk _toPerk(Map<String,dynamic> p) => Perk(
    id:            p['id']?.toString() ?? '',
    brand:         p['brand'] as String? ?? '',
    category:      p['category'] as String? ?? '',
    description:   p['description'] as String? ?? '',
    coins:         (p['coin_price'] as num?)?.toInt() ?? 0,
    discount:      0,
    discountLabel: p['discount_label'] as String? ?? '',
    imageUrl:      '',
    isFeatured:    p['is_featured'] as bool? ?? false,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: RefreshIndicator(
      color: AppColors.primary, onRefresh: _load,
      child: CustomScrollView(slivers: [

        // ── AppBar ────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,14,16,8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Perks Store', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Text('Turn your steps into savings', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            const Icon(Icons.storefront_outlined, color: AppColors.textPrimary, size: 22),
          ]),
        )),

        // ── Balance pill — REAL ───────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,0,16,14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16,14,16,14),
            decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.15))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('YOUR BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Row(children: [
                  CoinDot(size: 22),
                  const SizedBox(width: 6),
                  Text(_balance.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(width: 4),
                  const Text('FKC', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const Spacer(),
              Container(padding: const EdgeInsets.fromLTRB(14,8,14,8),
                decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text('≈ ₹${(_balance * 0.33).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.green)),
                  const Text('INR Value', style: TextStyle(fontSize: 10, color: AppColors.green)),
                ])),
            ]),
          ),
        )),

        // ── Hot Deals ─────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,0,16,10),
          child: Row(children: [
            const Text('Hot Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            const Text('🔥', style: TextStyle(fontSize: 18)),
          ]),
        )),
        SliverToBoxAdapter(child: SizedBox(
          height: (MediaQuery.of(context).size.height * 0.13).clamp(100.0, 130.0),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16,0,16,4),
            children: const [
              _HotDeal(gradient: [Color(0xFF2563EB), Color(0xFFEC4899)], badge: 'Flash Sale',  title: '50% Off Amazon',   sub: 'Limited time only'),
              _HotDeal(gradient: [Color(0xFFFBBF24), Color(0xFFF59E0B)], badge: 'New Arrival', title: 'Free Starbucks',   sub: 'Walk 10k steps',  darkText: true),
              _HotDeal(gradient: [Color(0xFF10B981), Color(0xFF059669)], badge: 'Trending',    title: 'Myntra ₹500 Off',  sub: 'Fashion & style'),
            ],
          ),
        )),

        // ── Category chips ────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cats.length,
              separatorBuilder: (_,__) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat    = _cats[i];
                final active = _cat == cat;
                final emoji  = _catEmoji(cat);
                return GestureDetector(
                  onTap: () => _onCatTap(cat),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.primary : AppColors.border)),
                    child: Text('$emoji $cat', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textSecondary))));
              }),
          ),
        )),

        // ── Available Vouchers ────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16,0,16,10),
          child: Row(children: [
            Text(
              _cat == 'All' ? 'Available Vouchers' : '$_cat Vouchers',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            if (!_loading)
              Text('${_filtered.length} offers',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        )),

        // ── Perk list ─────────────────────────────────────
        _loading
          ? const SliverToBoxAdapter(child: SizedBox(height: 200,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary))))
          : _filtered.isEmpty
            ? SliverToBoxAdapter(child: _empty())
            : SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _VoucherCard(
                  perk:    _toPerk(_filtered[i]),
                  canAfford: _balance >= (((_filtered[i]['coin_price'] as num?)?.toInt() ?? 0)),
                ),
                childCount: _filtered.length,
              )),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    )),
  );

  String _catEmoji(String cat) {
    switch (cat) {
      case 'Fashion':       return '👗';
      case 'Food':          return '🍔';
      case 'Entertainment': return '🎬';
      case 'Beauty':        return '💄';
      case 'Fitness':       return '🏃';
      default:              return '⊞';
    }
  }

  Widget _empty() => SizedBox(height: 200, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🎁', style: TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    Text('No $_cat perks available', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 4),
    const Text('Check back soon!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ])));
}

// ── Hot deal card ─────────────────────────────────────────────────────────────
class _HotDeal extends StatelessWidget {
  final List<Color> gradient;
  final String badge, title, sub;
  final bool darkText;
  const _HotDeal({required this.gradient, required this.badge, required this.title, required this.sub, this.darkText = false});

  @override Widget build(BuildContext context) => Container(
    width: 200, margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
      borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
        child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
      const Spacer(),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(sub,   style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
    ]));
}

// ── Voucher card ──────────────────────────────────────────────────────────────
class _VoucherCard extends StatelessWidget {
  final Perk perk;
  final bool canAfford;
  const _VoucherCard({required this.perk, required this.canAfford});

  String get _emoji {
    switch (perk.category) {
      case 'Fashion':       return '👗';
      case 'Food':          return '🍔';
      case 'Entertainment': return '🎬';
      case 'Beauty':        return '💄';
      case 'Fitness':       return '🏃';
      default:              return '🎁';
    }
  }

  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16,0,16,12),
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(children: [
        // Image / emoji area
        Stack(children: [
          Container(height: 150, width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 44)))),
          // Discount badge
          Positioned(top: 12, right: 12,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppColors.yellowBg, borderRadius: BorderRadius.circular(20)),
              child: Text(perk.discountLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))))),
          // Featured badge
          if (perk.isFeatured)
            Positioned(top: 12, left: 12,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: const Text('⭐ Featured', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))),
        ]),
        // Details
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(perk.brand, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(perk.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          const Text('Price', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            CoinDot(),
            const SizedBox(width: 5),
            Text('${perk.coins} FKC',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => RedeemFlow.start(context, perk),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: canAfford ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(20)),
                child: Text('Redeem Now',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: canAfford ? Colors.white : AppColors.textSecondary)))),
          ]),
          // Can't afford hint
          if (!canAfford)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('Need ${perk.coins} FKC • Walk more to unlock!',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
        ])),
      ]),
    ));
}
