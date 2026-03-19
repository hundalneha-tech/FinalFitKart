// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activity = TodayActivity.mock();
    final perks     = Perk.mockList().where((p) => p.isFeatured).toList();
    final weekly    = WeeklyData.mockWeek();

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ─────────────────────────
                  SliverToBoxAdapter(child: _buildAppBar(context)),

                  // ── Balance card ────────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _BalanceCard(activity: activity),
                  )),

                  // ── Steps + Calories row ─────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(children: [
                      Expanded(child: _StatMiniCard(icon: Icons.directions_walk, iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,   value: '${activity.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}', label: 'Steps')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatMiniCard(icon: Icons.local_fire_department, iconBg: const Color(0xFFFFF1F0), iconColor: AppColors.red, value: activity.calories.toInt().toString(), label: 'Kcal')),
                    ]),
                  )),

                  // ── Daily Goal card ──────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _DailyGoalCard(activity: activity),
                  )),

                  // ── Featured Perks ───────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SectionHeader(title: 'Featured Perks', action: 'See All'),
                  )),
                  SliverToBoxAdapter(child: SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: perks.length,
                      itemBuilder: (_, i) => _PerkCard(perk: perks[i]),
                    ),
                  )),

                  // ── Weekly Earning Trend ─────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: _WeeklyChart(data: weekly),
                  )),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),

            // ── Yellow boost banner (sticky bottom) ──
            BoostBanner(onActivate: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Rewards', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.primary)),
            const Text('Keep moving, keep earning', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        )),
        IconButton(icon: const Icon(Icons.notifications_none_outlined, size: 26), onPressed: () {}),
        const SizedBox(width: 4),
        const AvatarCircle(name: 'Alex Stride', size: 38),
      ],
    ),
  );
}

// ── Balance Card ──────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final TodayActivity activity;
  const _BalanceCard({required this.activity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: cardDecoration(),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Balance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              Text('₹1,240.50', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
                child: const Text('+12.5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
              ),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(width: 18, height: 18, decoration: const BoxDecoration(color: AppColors.coin, shape: BoxShape.circle),
                  child: const Center(child: Text('C', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 6),
                const Text('4,820 Coins Earned', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  child: const Text('View History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ],
        )),
        const SizedBox(width: 16),
        Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
        ),
      ],
    ),
  );
}

// ── Mini stat card ────────────────────────────────────────────
class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String value, label;
  const _StatMiniCard({required this.icon, required this.iconBg, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: cardDecoration(),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ]),
  );
}

// ── Daily Goal card ───────────────────────────────────────────
class _DailyGoalCard extends StatelessWidget {
  final TodayActivity activity;
  const _DailyGoalCard({required this.activity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Daily Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${(activity.progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        FKProgressBar(value: activity.progress, height: 9),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${activity.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} / ${activity.goalSteps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} steps',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Row(children: const [
              Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('On track', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
        ),
      ],
    ),
  );
}

// ── Perk card ─────────────────────────────────────────────────
class _PerkCard extends StatelessWidget {
  final Perk perk;
  const _PerkCard({required this.perk});

  @override
  Widget build(BuildContext context) => Container(
    width: 175,
    margin: const EdgeInsets.only(right: 12),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(perk.imageUrl, height: 130, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 130, color: AppColors.primaryBg,
                  child: const Icon(Icons.image_outlined, size: 36, color: AppColors.textMuted))),
            ),
            if (perk.discountLabel.isNotEmpty)
              Positioned(top: 8, right: 8, child: DiscountBadge(label: perk.discountLabel)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(perk.brand, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(perk.description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CoinBadge(amount: perk.coins.toDouble(), fontSize: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Redeem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Weekly Earning Chart ──────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<WeeklyData> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), e.value.coins)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Earning Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= data.length) return const SizedBox();
                    return Text(data[idx].day, style: const TextStyle(fontSize: 11, color: AppColors.textMuted));
                  },
                )),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(getDotPainter: (s, _, __, ___) =>
                    FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeColor: Colors.white, strokeWidth: 2)),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.02)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
