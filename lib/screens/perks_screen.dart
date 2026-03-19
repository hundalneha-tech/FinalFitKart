// lib/screens/perks_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});
  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  String _category = 'All';
  final _categories = ['All', 'Fashion', 'Food', 'Entertainment', 'Beauty'];
  final _allPerks   = Perk.mockList();

  List<Perk> get _filtered => _category == 'All'
    ? _allPerks
    : _allPerks.where((p) => p.category == _category).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Perks Store', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('Turn your steps into savings', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                )),
                IconButton(icon: const Icon(Icons.history_rounded, size: 24), onPressed: () {}),
              ],
            ),
          )),

          // ── Balance pill ────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: cardDecoration(color: const Color(0xFFFFF0F7)),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('YOUR BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
                      SizedBox(height: 4),
                      CoinBadge(amount: 1240.50, fontSize: 18),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
                    child: const Text('≈ ₹413\nINR Value',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ),
                ],
              ),
            ),
          )),

          // ── Hot Deals banner row ────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: const [
                Text('Hot Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Text('🔥', style: TextStyle(fontSize: 18)),
              ],
            ),
          )),
          SliverToBoxAdapter(child: SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _HotDealCard(
                  title: '50% Off Amazon', sub: 'Limited time only', badge: 'Flash Sale',
                  gradient: [Color(0xFF2563EB), Color(0xFFEC4899)],
                ),
                SizedBox(width: 12),
                _HotDealCard(
                  title: 'Free Starbucks', sub: 'Walk 10k steps', badge: 'New Arrival',
                  gradient: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
              ],
            ),
          )),

          // ── Category chips ──────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 0, 12),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  return CategoryChip(
                    label: cat, active: _category == cat,
                    onTap: () => setState(() => _category = cat),
                  );
                },
              ),
            ),
          )),

          // ── Available Vouchers label ─────────────
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text('Available Vouchers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),

          // ── Voucher list ────────────────────────
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _VoucherCard(perk: _filtered[i]),
            childCount: _filtered.length,
          )),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
  );
}

// ── Hot deal card ─────────────────────────────────────────────
class _HotDealCard extends StatelessWidget {
  final String title, sub, badge;
  final List<Color> gradient;
  const _HotDealCard({required this.title, required this.sub, required this.badge, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const Spacer(),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    ),
  );
}

// ── Full voucher card ─────────────────────────────────────────
class _VoucherCard extends StatelessWidget {
  final Perk perk;
  const _VoucherCard({required this.perk});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(perk.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 160, color: AppColors.primaryBg,
                    child: const Icon(Icons.image_outlined, size: 40, color: AppColors.textMuted))),
              ),
              Positioned(top: 12, right: 12, child: DiscountBadge(label: perk.discountLabel)),
            ],
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perk.brand, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(perk.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    )),
                    const Icon(Icons.more_horiz, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Price', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CoinBadge(amount: perk.coins.toDouble()),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Redeem Now', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
