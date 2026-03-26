// lib/screens/move_screen.dart
// Live metrics: Steps, Active Time, Distance, Calories, Move Minutes, Pace, Heart Points
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/pedometer_service.dart';
import '../services/workout_session_manager.dart';
import 'workout_session_screen.dart';

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key});
  @override State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  WorkoutType _selected = WorkoutType.walk;

  // Live data from PedometerService
  int    _todaySteps  = 0;
  double _distanceKm  = 0;
  int    _activeMinutes = 0;       // increments every minute steps > 0
  int    _sessionStart = 0;        // epoch seconds when first step detected today

  StreamSubscription? _stepsSub;
  Timer? _minuteTimer;
  int    _lastStepCheck = 0;       // steps at last minute tick (for move minute detection)

  final _mgr = WorkoutSessionManager();

  @override
  void initState() {
    super.initState();
    _mgr.addListener(_onMgrUpdate);
    _startListening();
  }

  void _onMgrUpdate() { if (mounted) setState(() {}); }

  void _startListening() {
    _todaySteps = PedometerService().todaySteps;
    _distanceKm = PedometerService().distanceKm;
    if (_todaySteps > 0) _sessionStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _stepsSub = PedometerService().stepsStream.listen((steps) {
      if (mounted) setState(() {
        if (_sessionStart == 0 && steps > 0) {
          _sessionStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        }
        _todaySteps = steps;
        _distanceKm = PedometerService().distanceKm;
      });
    });

    // Every minute: check if user moved (move minute detection)
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final currentSteps = PedometerService().todaySteps;
      final stepsDelta = currentSteps - _lastStepCheck;
      _lastStepCheck = currentSteps;
      // A "move minute" requires > 50 steps in that minute (low-activity threshold)
      if (stepsDelta > 50) setState(() => _activeMinutes++);
    });
  }

  @override
  void dispose() {
    _mgr.removeListener(_onMgrUpdate);
    _stepsSub?.cancel();
    _minuteTimer?.cancel();
    super.dispose();
  }

  // ── Computed metrics ─────────────────────────────────────

  // Calories: MET-based — 0.04 kcal/step average adult
  double get _calories => _todaySteps * 0.04;

  // Active time: time since first step, in minutes
  int get _activeTimeMins {
    if (_mgr.isActive) return _mgr.elapsed ~/ 60;
    if (_sessionStart == 0) return 0;
    return ((DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStart) ~/ 60;
  }

  // Pace: min/km — standard running/walking pace format
  // Returns "–" if not enough data
  String get _pace {
    if (_distanceKm < 0.05 || _activeTimeMins < 1) return '–';
    final minsPerKm = _activeTimeMins / _distanceKm;
    final mins = minsPerKm.floor();
    final secs = ((minsPerKm - mins) * 60).round();
    return "${mins}'${secs.toString().padLeft(2,'0')}\"";
  }

  // Avg speed in km/h for display
  String get _speedKmh {
    if (_activeTimeMins < 1 || _distanceKm < 0.01) return '0.0';
    return (_distanceKm / (_activeTimeMins / 60)).toStringAsFixed(1);
  }

  // Heart Points: WHO Active Minutes equivalent
  // Moderate walking (steps/min 60-99) = 1 HP/min, Vigorous (100+) = 2 HP/min
  int get _heartPoints {
    if (_activeMinutes == 0) return 0;
    final stepsPerMin = _activeMinutes > 0 ? _todaySteps / _activeMinutes : 0;
    return stepsPerMin >= 100
      ? (_activeMinutes * 2).round()
      : (_activeMinutes * 1).round();
  }

  // Coins
  double get _coinsEarned {
    if (_mgr.isActive) return _mgr.coins;
    return (_todaySteps * 0.001).clamp(0, 10);
  }
  double get _inrValue => _coinsEarned * 0.33;

  // Ring progress
  double get _goalProgress => (_todaySteps / 10000).clamp(0.0, 1.0);
  double get _outerArc     => _goalProgress;
  double get _innerArc     => (_calories / 400).clamp(0.0, 1.0);

  // Active time formatted
  String get _activeTimeLabel {
    if (_activeTimeMins < 60) return '$_activeTimeMins min';
    return '${_activeTimeMins ~/ 60}h ${_activeTimeMins % 60}m';
  }

  Color _typeColor(WorkoutType t) {
    switch(t) { case WorkoutType.run: return AppColors.accent; case WorkoutType.cycle: return AppColors.green; default: return AppColors.primary; }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: CustomScrollView(slivers: [

      // ── AppBar ───────────────────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,14,16,8),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Keep Moving', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Row(children: [
              Container(width: 7, height: 7,
                decoration: BoxDecoration(
                  color: _mgr.isActive ? AppColors.green : AppColors.primary,
                  shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                _mgr.isActive ? 'Session Active' : 'Live Tracking',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _mgr.isActive ? AppColors.green : AppColors.primary)),
            ]),
          ])),
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: _mgr.isActive ? AppColors.green : AppColors.primary,
              shape: BoxShape.circle),
            child: Center(child: Icon(
              _mgr.isActive ? Icons.directions_walk : Icons.person,
              color: Colors.white, size: 20))),
        ]),
      )),

      // ── Ring + metrics card ──────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,4,16,12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16,20,16,16),
          decoration: cardDecoration(),
          child: Column(children: [

            // Double ring
            SizedBox(width: 210, height: 210, child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(210, 210),
                painter: _RingPainter(outerArc: _outerArc, innerArc: _innerArc)),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  _todaySteps >= 1000
                    ? '${(_todaySteps / 1000).toStringAsFixed(1)}k'
                    : '$_todaySteps',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const Text('Steps', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${(_goalProgress * 100).toStringAsFixed(0)}% of goal',
                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                if (_mgr.isActive) ...[
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
                    child: const Text('● LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                ],
              ]),
            ])),

            // Ring legend
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(AppColors.primary, 'Steps goal'),
              const SizedBox(width: 16),
              _legendDot(AppColors.accent, 'Calorie goal'),
            ]),

            const SizedBox(height: 16),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 16),

            // ── 6-metric grid ────────────────────────────────
            // Row 1: Active Time | Distance | Calories
            Row(children: [
              _MetricTile(
                emoji: '⏱️',
                value: _activeTimeLabel,
                label: 'Active Time',
                bg: const Color(0xFFEFF6FF),
                valueColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                emoji: '📍',
                value: '${_distanceKm.toStringAsFixed(2)} km',
                label: 'Distance',
                bg: const Color(0xFFECFDF5),
                valueColor: AppColors.green,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                emoji: '🔥',
                value: _calories.toStringAsFixed(0),
                label: 'Calories',
                sublabel: 'kcal',
                bg: const Color(0xFFFFF7ED),
                valueColor: const Color(0xFFF97316),
              ),
            ]),
            const SizedBox(height: 8),

            // Row 2: Move Minutes | Pace | Heart Points
            Row(children: [
              _MetricTile(
                emoji: '🏃',
                value: '$_activeMinutes',
                label: 'Move Mins',
                sublabel: 'min',
                bg: const Color(0xFFF5F3FF),
                valueColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              _MetricTile(
                emoji: '⚡',
                value: _pace,
                label: 'Pace',
                sublabel: _pace == '–' ? '' : 'min/km',
                bg: const Color(0xFFFFF1F0),
                valueColor: const Color(0xFFEF4444),
                extraLine: _pace == '–' ? '' : '$_speedKmh km/h',
              ),
              const SizedBox(width: 8),
              _MetricTile(
                emoji: '❤️',
                value: '$_heartPoints',
                label: 'Heart Pts',
                sublabel: 'pts',
                bg: const Color(0xFFFFF0F6),
                valueColor: AppColors.accent,
                extraLine: _heartPoints >= 10 ? '✓ Active' : 'Goal: 10',
              ),
            ]),
          ]),
        ),
      )),

      // ── Live Earnings banner ─────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,0,16,14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18,14,18,14),
          decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _mgr.isActive ? 'SESSION EARNINGS' : 'TODAY\'S EARNINGS',
                style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(children: [
                Container(width: 20, height: 20,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Center(child: Text('C', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))),
                const SizedBox(width: 8),
                Text('${_coinsEarned.toStringAsFixed(2)} FKC',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ]),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Text('≈ ₹${_inrValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('Redeemable', style: TextStyle(fontSize: 10, color: Colors.white70)),
              ])),
          ]),
        ),
      )),

      // ── Quick Start ──────────────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,0,16,12),
        child: Column(children: [
          Row(children: [
            const Text('Quick Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                CoinDot(size: 14),
                const SizedBox(width: 4),
                const Text('1 FKC per 100 steps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ])),
          ]),
          const SizedBox(height: 10),
          Row(children: WorkoutType.values.map((t) {
            final active = t == _selected;
            final color  = _typeColor(t);
            final label  = t == WorkoutType.walk ? '🚶 Walk' : t == WorkoutType.run ? '🏃 Run' : '🚴 Cycle';
            final mult   = t == WorkoutType.run ? '1.5×' : t == WorkoutType.cycle ? '0.8×' : '1×';
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: t != WorkoutType.cycle ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selected = t),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? color : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: active ? color : AppColors.border)),
                  child: Column(children: [
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$mult FKC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: active ? Colors.white.withOpacity(0.8) : AppColors.textMuted)),
                  ])))));
          }).toList()),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => WorkoutSessionScreen(type: _selected))),
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('Start Workout Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            )),
        ]),
      )),

      // ── Weekly Activity chart ────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,0,16,14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Weekly Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              const Text('This Week', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 14),
            _BarChart(
              data: [7200, 9100, 8500, 11200, 6800, 9400, _todaySteps],
              labels: const ['M','T','W','T','F','S','S']),
          ]),
        ),
      )),

      // ── Workout Buddies ──────────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,0,16,10),
        child: Row(children: [
          const Text('Workout Buddies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ]),
      )),
      SliverToBoxAdapter(child: _BuddyItem(initials: 'RS', color: const Color(0xFF6366F1), name: 'Rahul S.', activity: 'Walking now', dist: '0.8 km')),
      SliverToBoxAdapter(child: _BuddyItem(initials: 'PK', color: const Color(0xFFF59E0B), name: 'Priya K.', activity: 'Cycling', dist: '1.2 km')),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16,8,16,20),
        child: Container(
          height: 46, width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('👥', style: TextStyle(fontSize: 15)),
            SizedBox(width: 6),
            Text('Invite Friends', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ])),
      )),
    ])),
  );

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]);
}

// ── Metric tile ───────────────────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String emoji, value, label;
  final String? sublabel, extraLine;
  final Color bg, valueColor;

  const _MetricTile({
    required this.emoji, required this.value, required this.label,
    required this.bg, required this.valueColor,
    this.sublabel, this.extraLine,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10,10,10,10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: valueColor))),
        if (sublabel != null && sublabel!.isNotEmpty)
          Text(sublabel!, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        if (extraLine != null && extraLine!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(extraLine!, style: TextStyle(fontSize: 9, color: valueColor.withOpacity(0.8), fontWeight: FontWeight.w600)),
        ],
      ])));
}

// ── Ring painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double outerArc, innerArc;
  const _RingPainter({required this.outerArc, required this.innerArc});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const pi = 3.14159265;

    // Outer track
    canvas.drawCircle(Offset(cx,cy), 90,
      Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = 14);
    if (outerArc > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx,cy), radius: 90),
        -pi/2, 2*pi*outerArc, false,
        Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round
          ..shader = const LinearGradient(colors:[Color(0xFF3B82F6),Color(0xFF2563EB)])
              .createShader(Rect.fromCircle(center: Offset(cx,cy), radius: 90)));
    }

    // Inner track
    canvas.drawCircle(Offset(cx,cy), 69,
      Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = 10);
    if (innerArc > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx,cy), radius: 69),
        -pi/2, 2*pi*innerArc, false,
        Paint()..style=PaintingStyle.stroke..strokeWidth=10..strokeCap=StrokeCap.round
          ..shader = const LinearGradient(colors:[Color(0xFFF472B6),Color(0xFFEC4899)])
              .createShader(Rect.fromCircle(center: Offset(cx,cy), radius: 69)));
    }
  }

  @override bool shouldRepaint(_RingPainter old) =>
      old.outerArc != outerArc || old.innerArc != innerArc;
}

// ── Supporting widgets ────────────────────────────────────────────────────────
class _BuddyItem extends StatelessWidget {
  final String initials, name, activity, dist;
  final Color color;
  const _BuddyItem({required this.initials, required this.color, required this.name, required this.activity, required this.dist});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16,0,16,8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14,12,14,12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Row(children: [
        Stack(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
          Positioned(bottom:0, right:0,
            child: Container(width:10, height:10,
              decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(activity, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(dist, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const Text('nearby', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ])));
}

class _BarChart extends StatelessWidget {
  final List<int> data;
  final List<String> labels;
  const _BarChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    final max = data.reduce((a,b) => a>b?a:b).toDouble();
    return SizedBox(height: 100, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
      children: [for (int i=0; i<data.length; i++) Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Expanded(child: Align(alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(heightFactor: max>0 ? data[i]/max : 0,
              child: Container(decoration: BoxDecoration(
                color: i==data.length-1 ? AppColors.accent : AppColors.primary,
                borderRadius: BorderRadius.circular(6)))))),
          const SizedBox(height: 6),
          Text(labels[i], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])))]));
  }
}
