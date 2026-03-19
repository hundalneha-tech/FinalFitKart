// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user    = UserProfile.mock();
    final walks   = WalkSession.mockList();
    final causes  = Cause.mockList();
    final monthly = WeeklyData.mockMonths();

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Profile header ──────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _ProfileHeader(user: user),
            )),

            // ── Emergency SOS banner ────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SOSBanner(),
            )),

            // ── Wallet card (gradient) ──────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _WalletCard(user: user),
            )),

            // ── Lifetime stats ──────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(child: _LifeStatCard(icon: Icons.directions_walk, iconBg: AppColors.primaryBg, iconColor: AppColors.primary,
                  value: '1.2M', label: 'LIFETIME STEPS')),
                const SizedBox(width: 12),
                Expanded(child: _LifeStatCard(icon: Icons.local_fire_department, iconBg: const Color(0xFFFFF1F0), iconColor: AppColors.red,
                  value: '45.2k', label: 'CALORIES BURNT')),
              ]),
            )),

            // ── Walk for a Cause ─────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(title: 'Walk for a Cause', action: 'See All'),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
              child: const Text('Convert your steps into real-world impact',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 195,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: causes.length,
                itemBuilder: (_, i) => _CauseCard(cause: causes[i]),
              ),
            )),

            // ── Earnings Trend chart ─────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _EarningsTrendCard(data: monthly),
            )),

            // ── Recent Walks ─────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(title: 'Recent Walks', action: 'View All'),
            )),
            SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _WalkTile(session: walks[i]),
              childCount: walks.length,
            )),

            // ── Donate Coins button ───────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: PrimaryButton(
                label: 'Donate Coins Now',
                icon: Icons.volunteer_activism,
                color: AppColors.accent,
              ),
            )),

            // ── Account Settings ─────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Account Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    _SettingRow(icon: Icons.person_outline, title: 'Personal Information', sub: 'Name, Email, Connected Devi...'),
                    _SettingRow(icon: Icons.account_balance_wallet_outlined, title: 'Withdrawal Methods', sub: 'UPI, Bank Account, Gift Cards'),
                    _SettingRow(icon: Icons.favorite_outline, title: 'Donation Preferences', sub: 'Causes you care about'),
                    _SettingRow(icon: Icons.security_outlined, title: 'Privacy & Security', sub: 'App lock, Data sharing', isLast: true),
                  ],
                ),
              ),
            )),

            // ── Action buttons ───────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: PrimaryButton(
                label: 'Upgrade to Pro',
                icon: Icons.workspace_premium_outlined,
                color: AppColors.primary,
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout, size: 16, color: AppColors.red),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.redBg),
                  backgroundColor: AppColors.redBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final UserProfile user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Stack(children: [
        AvatarCircle(name: user.name, size: 62),
        Positioned(bottom: 0, right: 0,
          child: Container(
            width: 20, height: 20, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle,),
            child: const Icon(Icons.check, size: 12, color: Colors.white))),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Row(children: [
            Text('${user.level} • ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            Text('Level ${user.levelNum}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
          Row(children: const [
            Icon(Icons.emoji_events_outlined, size: 12, color: AppColors.textSecondary),
            SizedBox(width: 4),
            Text('Top 5% this week', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ],
      )),
    ],
  );
}

// ── SOS banner ────────────────────────────────────────────────
class _SOSBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.red.withOpacity(0.2))),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
        child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Emergency SOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.red)),
        Text('Instantly alert your emergency contacts if you feel unsafe during ...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    ]),
  );
}

// ── Wallet card ───────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final UserProfile user;
  const _WalletCard({required this.user});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFFEC4899)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Balance', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('≈ ₹${user.inrValue.toInt()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${user.totalCoins.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} Coins',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        GestureDetector(
          child: Row(children: const [
            Icon(Icons.history, size: 16, color: Colors.white70),
            SizedBox(width: 6),
            Text('View Wallet History', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ]),
        ),
      ],
    ),
  );
}

// ── Lifetime stat card ────────────────────────────────────────
class _LifeStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String value, label;
  const _LifeStatCard({required this.icon, required this.iconBg, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.3)),
    ]),
  );
}

// ── Cause card ────────────────────────────────────────────────
class _CauseCard extends StatelessWidget {
  final Cause cause;
  const _CauseCard({required this.cause});

  @override
  Widget build(BuildContext context) => Container(
    width: 175,
    margin: const EdgeInsets.only(right: 12),
    decoration: cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Image.network(cause.imageUrl, height: 95, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 95, color: AppColors.primaryBg,
              child: const Icon(Icons.eco_outlined, size: 30, color: AppColors.green))),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cause.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('${(cause.progress * 100).toInt()}% of ${(cause.targetCoins / 1000).toInt()}k coins',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              FKProgressBar(value: cause.progress, height: 5, color: AppColors.green),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(
                  child: const Text('Donate Coins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                const Spacer(),
                const Icon(Icons.favorite, size: 14, color: AppColors.accent),
              ]),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Earnings trend chart ──────────────────────────────────────
class _EarningsTrendCard extends StatelessWidget {
  final List<WeeklyData> data;
  const _EarningsTrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.coins)).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Earnings Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Last 7 Months', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
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
                  showTitles: true, reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    return Text(data[i].day, style: const TextStyle(fontSize: 10, color: AppColors.textMuted));
                  },
                )),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: spots, isCurved: true, color: AppColors.primary, barWidth: 2.5,
                dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeColor: Colors.white, strokeWidth: 2)),
                belowBarData: BarAreaData(show: true,
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.18), Colors.transparent],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              )],
            )),
          ),
        ],
      ),
    );
  }
}

// ── Walk tile ─────────────────────────────────────────────────
class _WalkTile extends StatelessWidget {
  final WalkSession session;
  const _WalkTile({required this.session});

  Color get _color => session.type == 'walk' ? AppColors.primary : session.type == 'run' ? AppColors.accent : AppColors.green;
  IconData get _icon => session.type == 'walk' ? Icons.directions_walk : session.type == 'run' ? Icons.directions_run : Icons.pedal_bike;

  String _fmt(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 1) return 'Yesterday, ${d.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month-1]}';
    return '${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday-1]}, ${d.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month-1]}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: _color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(_icon, color: _color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmt(session.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${session.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} steps • ${session.distanceKm} km',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+ ₹${session.inrEarned.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
            Text('${session.coinsEarned} Coins',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    ),
  );
}

// ── Setting row ───────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool isLast;
  const _SettingRow({required this.icon, required this.title, required this.sub, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.scaffold, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppColors.textSecondary)),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {},
    ),
    if (!isLast) const Divider(height: 1, indent: 66, color: AppColors.borderLight),
  ]);
}
