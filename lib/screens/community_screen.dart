// lib/screens/community_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friends   = Friend.mockList();
    final challenge = Challenge.mockList().last; // Walk to the Moon

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Community', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('Connect and compete with friends', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  )),
                  IconButton(icon: const Icon(Icons.search, size: 24), onPressed: () {}),
                ],
              ),
            )),

            // ── Global Challenge banner ─────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _GlobalChallengeBanner(challenge: challenge),
            )),

            // ── Stats row ───────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: cardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _CommunityStat(icon: Icons.people_alt_outlined, iconColor: AppColors.primary, value: '12', label: 'Friends'),
                    _StatDivider(),
                    _CommunityStat(icon: Icons.emoji_events_outlined, iconColor: AppColors.primary, value: '#4', label: 'Rank'),
                    _StatDivider(),
                    _CommunityStat(icon: Icons.favorite_outline, iconColor: AppColors.accent, value: '128', label: 'Cheers'),
                  ],
                ),
              ),
            )),

            // ── Active Friends ──────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(title: 'Active Friends', action: 'Find More'),
            )),
            SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _FriendTile(friend: friends[i]),
              childCount: friends.length,
            )),

            // ── Recent Activity ─────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(icon: const Icon(Icons.history, size: 20, color: AppColors.textSecondary), onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _activityItem('RK', const Color(0xFF6366F1), 'Rahul K.', 'earned 50 coins', '🪙 ₹50', '2 mins ago'),
                    const Divider(height: 16),
                    _activityItem('SJ', const Color(0xFF10B981), 'Sarah J.', 'completed 10k steps', '🚶 10.2k', '15 mins ago'),
                    const Divider(height: 16),
                    _activityItem('AV', const Color(0xFF8B5CF6), 'Amit V.', 'reached a 30-day streak', '🔥 HOT', '1 hour ago'),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Show All Activity', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _activityItem(String initials, Color color, String name, String action, String badge, String time) =>
    Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary), children: [
          TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: action, style: const TextStyle(fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
        ])),
        Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(20)),
        child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
    ]);
}

// ── Global Challenge banner ───────────────────────────────────
class _GlobalChallengeBanner extends StatelessWidget {
  final Challenge challenge;
  const _GlobalChallengeBanner({required this.challenge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Global Challenge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(challenge.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.public, color: Colors.white, size: 18)),
        ]),
        const SizedBox(height: 10),
        Text(challenge.globalProgress ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.yellow)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.65, backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.yellow), minHeight: 6),
          )),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text('Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ],
    ),
  );
}

// ── Community stat item ───────────────────────────────────────
class _CommunityStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value, label;
  const _CommunityStat({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: iconColor, size: 22),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: AppColors.borderLight);
}

// ── Friend tile ───────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final Friend friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          AvatarCircle(name: friend.name, size: 46, showOnline: friend.isOnline),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              StreakBadge(days: friend.streakDays),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${friend.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} steps',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              GestureDetector(
                child: const Text('View', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))),
            ],
          ),
        ],
      ),
    ),
  );
}
