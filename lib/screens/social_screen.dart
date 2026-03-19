// lib/screens/social_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _weeklySelected = true;
  final _leaderboard  = LeaderboardEntry.mockList();
  final _challenges   = Challenge.mockList().take(2).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Social Hub', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('Compete with the community', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                )),
                IconButton(icon: const Icon(Icons.notifications_none_outlined, size: 24), onPressed: () {}),
              ],
            ),
          )),

          // ── Invite + My Community buttons ─────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: const Text('Invite Friends'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.textPrimary),
                label: const Text('My Community', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ]),
          )),

          // ── Trending Challenges ───────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SectionHeader(title: 'Trending Challenges', action: 'See All'),
          )),
          SliverToBoxAdapter(child: SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _challenges.length,
              itemBuilder: (_, i) => _ChallengeCard(challenge: _challenges[i]),
            ),
          )),

          // ── Leaderboard ───────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                _TogglePill(
                  left: 'Weekly', right: 'Monthly',
                  leftActive: _weeklySelected,
                  onLeft: () => setState(() => _weeklySelected = true),
                  onRight: () => setState(() => _weeklySelected = false),
                ),
              ],
            ),
          )),

          // ── Top 3 podium ──────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PodiumRow(entries: _leaderboard.take(3).toList()),
          )),

          // ── Rest of leaderboard ───────────────
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) {
              final entry = _leaderboard.skip(3).toList()[i];
              return _LeaderboardTile(entry: entry);
            },
            childCount: (_leaderboard.length - 3).clamp(0, 999),
          )),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
  );
}

// ── Challenge card ────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _ChallengeCard({required this.challenge});

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
              child: Image.network(challenge.imageUrl, height: 95, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 95, color: AppColors.primaryBg)),
            ),
            Positioned(top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(20)),
                child: Text(challenge.type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
              )),
            Positioned(top: 8, right: 8,
              child: Text(challenge.timeLeft, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(challenge.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                // Stacked avatar dots
                const _StackedDots(),
                const SizedBox(width: 6),
                Text('+${(challenge.joined / 1000).toStringAsFixed(1)}k joined',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 34,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Join Challenge', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StackedDots extends StatelessWidget {
  const _StackedDots();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36, height: 18,
    child: Stack(children: [
      _dot(0, const Color(0xFF6366F1)),
      _dot(10, const Color(0xFFF59E0B)),
      _dot(20, const Color(0xFF10B981)),
    ]),
  );

  Widget _dot(double left, Color color) => Positioned(
    left: left,
    child: Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: color,
      border: Border.all(color: Colors.white, width: 1.5))),
  );
}

// ── Toggle pill ───────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final String left, right;
  final bool leftActive;
  final VoidCallback onLeft, onRight;
  const _TogglePill({required this.left, required this.right, required this.leftActive, required this.onLeft, required this.onRight});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _pill(left, leftActive, onLeft),
      _pill(right, !leftActive, onRight),
    ]),
  );

  Widget _pill(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? Colors.white : AppColors.textSecondary)),
    ),
  );
}

// ── Podium row ────────────────────────────────────────────────
class _PodiumRow extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _PodiumRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Render order: 2nd, 1st, 3rd
    final order = entries.length >= 3 ? [entries[1], entries[0], entries[2]] : entries;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: order.asMap().entries.map((e) {
          final isFirst = e.value.rank == 1;
          final podiumH = isFirst ? 70.0 : 50.0;
          return Column(
            children: [
              if (isFirst) const Icon(Icons.emoji_events, color: AppColors.yellow, size: 20),
              Container(
                decoration: isFirst ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.yellow, width: 3),
                ) : null,
                child: AvatarCircle(name: e.value.name, size: isFirst ? 56 : 44),
              ),
              const SizedBox(height: 6),
              Text(e.value.name, style: TextStyle(fontSize: isFirst ? 13 : 12, fontWeight: FontWeight.w700)),
              Text('${(e.value.steps / 1000).toStringAsFixed(1)}k',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                width: 36, height: podiumH,
                decoration: BoxDecoration(
                  color: isFirst ? AppColors.yellow : AppColors.border,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                alignment: Alignment.center,
                child: Text('${e.value.rank}', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15,
                  color: isFirst ? Colors.black : AppColors.textSecondary)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Leaderboard tile ──────────────────────────────────────────
class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardTile({required this.entry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: entry.isMe
        ? BoxDecoration(
            color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
          )
        : cardDecoration(),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${entry.rank}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          AvatarCircle(name: entry.name, size: 38, showOnline: entry.isMe),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Row(children: [
                const Icon(Icons.directions_walk, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('${entry.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} steps',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.steps ~/ 1000 + 10}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('₹${entry.inrEarned.toInt()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
            ],
          ),
        ],
      ),
    ),
  );
}
