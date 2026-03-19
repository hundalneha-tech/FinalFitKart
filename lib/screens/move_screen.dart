// lib/screens/move_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key});
  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  String _selectedType = 'Walk';
  final _types = const ['Walk', 'Run', 'Cycle'];
  final _friends = Friend.mockList().where((f) => f.nearbyKm != null).toList();

  @override
  Widget build(BuildContext context) {
    final activity = TodayActivity.mock();
    final weekly   = WeeklyData.mockWeek();

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ───────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Keep Moving', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.location_on, size: 13, color: AppColors.textSecondary),
                        SizedBox(width: 2),
                        Text('Mumbai, India', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ],
                  )),
                  const AvatarCircle(name: 'JD', size: 40, color: AppColors.primary),
                ],
              ),
            )),

            // ── Step ring card ────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _StepRingCard(activity: activity),
            )),

            // ── Live Earnings gradient banner ─────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _LiveEarningsBanner(activity: activity),
            )),

            // ── Quick Start ───────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _QuickStart(
                selected: _selectedType,
                types: _types,
                onSelect: (t) => setState(() => _selectedType = t),
              ),
            )),

            // ── Weekly Activity bar chart ─────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _WeeklyActivityCard(data: weekly),
            )),

            // ── Workout Buddies ───────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SectionHeader(title: 'Workout Buddies', action: 'See All'),
            )),
            SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i >= _friends.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    child: OutlineButton2(label: 'Invite Friends', icon: Icons.person_add_alt),
                  );
                }
                return _BuddyTile(friend: _friends[i]);
              },
              childCount: _friends.length + 1,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Step ring card ────────────────────────────────────────────
class _StepRingCard extends StatelessWidget {
  final TodayActivity activity;
  const _StepRingCard({required this.activity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: cardDecoration(),
    child: Column(
      children: [
        // Dual ring using percent_indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring – blue (steps)
            CircularPercentIndicator(
              radius: 110,
              lineWidth: 14,
              percent: activity.progress,
              backgroundColor: AppColors.border,
              linearGradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              circularStrokeCap: CircularStrokeCap.round,
              center: const SizedBox.shrink(),
            ),
            // Inner ring – pink (calories)
            CircularPercentIndicator(
              radius: 88,
              lineWidth: 10,
              percent: (activity.calories / 600).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              linearGradient: const LinearGradient(
                colors: [AppColors.accentLight, AppColors.accent],
              ),
              circularStrokeCap: CircularStrokeCap.round,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    activity.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},'),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const Text('Steps Today', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),

        // Goal label below ring
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Goal: 10k', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Calories + Minutes mini cards
        Row(children: [
          Expanded(child: _MiniStatCard(
            icon: Icons.local_fire_department, iconBg: const Color(0xFFFFF1F0), iconColor: AppColors.red,
            value: activity.calories.toInt().toString(), label: 'Calories', badge: '+5%',
          )),
          const SizedBox(width: 12),
          Expanded(child: _MiniStatCard(
            icon: Icons.timer_outlined, iconBg: const Color(0xFFECFDF5), iconColor: AppColors.green,
            value: activity.activeMinutes.toString(), label: 'Minutes',
          )),
        ]),
      ],
    ),
  );
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String value, label;
  final String? badge;
  const _MiniStatCard({required this.icon, required this.iconBg, required this.iconColor,
    required this.value, required this.label, this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.scaffold, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 16)),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
              child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    ),
  );
}

// ── Live Earnings banner ──────────────────────────────────────
class _LiveEarningsBanner extends StatelessWidget {
  final TodayActivity activity;
  const _LiveEarningsBanner({required this.activity});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.gradStart, AppColors.gradEnd],
        begin: Alignment.centerLeft, end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIVE EARNINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Center(child: Text('C', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(width: 8),
              Text('${activity.coinsEarned} Coins',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('≈ ₹${activity.inrEarned.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const Text('Redeemable', style: TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Quick Start ───────────────────────────────────────────────
class _QuickStart extends StatelessWidget {
  final String selected;
  final List<String> types;
  final ValueChanged<String> onSelect;
  const _QuickStart({required this.selected, required this.types, required this.onSelect});

  IconData _icon(String t) => t == 'Walk' ? Icons.directions_walk : t == 'Run' ? Icons.directions_run : Icons.pedal_bike;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Quick Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Row(
        children: types.map((t) {
          final isActive = t == selected;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: t != types.last ? 8 : 0),
            child: GestureDetector(
              onTap: () => onSelect(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icon(t), size: 16, color: isActive ? Colors.white : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ));
        }).toList(),
      ),
      const SizedBox(height: 10),
      PrimaryButton(
        label: 'Start Workout Session',
        icon: Icons.play_arrow_rounded,
        color: Colors.black,
        onPressed: () {},
      ),
    ],
  );
}

// ── Weekly Activity bar chart ─────────────────────────────────
class _WeeklyActivityCard extends StatelessWidget {
  final List<WeeklyData> data;
  const _WeeklyActivityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxSteps = data.map((d) => d.steps).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(children: const [
                Icon(Icons.check, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text('This Week', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxSteps * 1.2,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 22,
                  getTitlesWidget: (v, _) => Text(data[v.toInt()].day,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                )),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: e.value.steps.toDouble(),
                  color: AppColors.primary,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                )],
              )).toList(),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Buddy tile ────────────────────────────────────────────────
class _BuddyTile extends StatelessWidget {
  final Friend friend;
  const _BuddyTile({required this.friend});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: cardDecoration(),
      child: Row(
        children: [
          AvatarCircle(name: friend.name, showOnline: friend.isOnline, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (friend.activity != null)
                Text(friend.activity!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
          if (friend.nearbyKm != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${friend.nearbyKm} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const Text('nearby', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    ),
  );
}
