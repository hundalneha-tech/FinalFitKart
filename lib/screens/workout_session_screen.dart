// lib/screens/workout_session_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../services/workout_session_manager.dart';
import '../services/pedometer_service.dart';

export '../services/workout_session_manager.dart' show WorkoutType, WorkoutTypeExt;

// ── Helpers ───────────────────────────────────────────────────────────────────
Color workoutColor(WorkoutType t) {
  switch (t) {
    case WorkoutType.walk:  return AppColors.primary;
    case WorkoutType.run:   return AppColors.accent;
    case WorkoutType.cycle: return AppColors.green;
  }
}

IconData workoutIcon(WorkoutType t) {
  switch (t) {
    case WorkoutType.walk:  return Icons.directions_walk_rounded;
    case WorkoutType.run:   return Icons.directions_run_rounded;
    case WorkoutType.cycle: return Icons.pedal_bike_rounded;
  }
}

double workoutMultiplier(WorkoutType t) {
  switch (t) {
    case WorkoutType.walk:  return 1.0;
    case WorkoutType.run:   return 1.5;
    case WorkoutType.cycle: return 0.8;
  }
}

// ── Main session screen ───────────────────────────────────────────────────────
class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutType type;
  const WorkoutSessionScreen({super.key, required this.type});
  @override State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with TickerProviderStateMixin {

  final _mgr = WorkoutSessionManager();
  bool _sessionStarted = false;
  int    _startSteps    = 0;
  double _startDistance = 0;
  int    _moveMinutes   = 0;
  int    _lastStepCheck = 0;

  StreamSubscription? _stepsSub;
  Timer? _minuteTimer;
  Timer? _mapRefreshTimer;

  // Map
  GoogleMapController? _mapCtrl;
  final List<LatLng> _routePoints = [];
  LatLng? _currentPos;
  bool _mapReady = false;
  bool _followUser = true;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (_mgr.isActive) {
      _sessionStarted = true;
      if (_mgr.isPaused) _pulseCtrl.stop();
      _subscribeSteps();
      _startMapRefresh();
    } else {
      _pulseCtrl.stop();
    }
    _mgr.addListener(_onManagerUpdate);
    _loadInitialPosition();
  }

  void _onManagerUpdate() { if (mounted) setState(() {}); }

  Future<void> _loadInitialPosition() async {
    final pts = PedometerService().routePoints;
    if (pts.isNotEmpty) {
      final last = pts.last;
      setState(() {
        _currentPos = LatLng(last.lat, last.lng);
        _routePoints.addAll(pts.map((p) => LatLng(p.lat, p.lng)));
      });
    }
  }

  void _subscribeSteps() {
    _stepsSub?.cancel();
    _lastStepCheck = PedometerService().todaySteps;
    _stepsSub = PedometerService().stepsStream.listen((total) {
      if (!_mgr.isPaused) {
        _mgr.updateStats(
          steps: total - _startSteps,
          distanceKm: PedometerService().distanceKm - _startDistance,
        );
      }
    });

    // Move minute counter
    _minuteTimer?.cancel();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final current = PedometerService().todaySteps;
      if (current - _lastStepCheck > 50 && !_mgr.isPaused) {
        setState(() => _moveMinutes++);
      }
      _lastStepCheck = current;
    });
  }

  void _startMapRefresh() {
    _mapRefreshTimer?.cancel();
    _mapRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _mgr.isPaused) return;
      final pts = PedometerService().routePoints;
      if (pts.isEmpty) return;
      final last = pts.last;
      final newPt = LatLng(last.lat, last.lng);
      if (_routePoints.isEmpty || _routePoints.last != newPt) {
        setState(() {
          _routePoints.add(newPt);
          _currentPos = newPt;
        });
        if (_followUser && _mapCtrl != null && _mapReady) {
          _mapCtrl!.animateCamera(CameraUpdate.newLatLng(newPt));
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stepsSub?.cancel();
    _minuteTimer?.cancel();
    _mapRefreshTimer?.cancel();
    _mapCtrl?.dispose();
    _mgr.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    _startSteps    = PedometerService().todaySteps;
    _startDistance = PedometerService().distanceKm;
    _moveMinutes   = 0;
    _mgr.start(widget.type);
    _sessionStarted = true;
    _pulseCtrl.repeat(reverse: true);
    _subscribeSteps();
    _startMapRefresh();
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _mgr.pause();
    _pulseCtrl.stop();
  }

  void _resume() {
    HapticFeedback.lightImpact();
    _mgr.resume();
    _pulseCtrl.repeat(reverse: true);
  }

  void _stop() {
    HapticFeedback.heavyImpact();
    _stepsSub?.cancel();
    _minuteTimer?.cancel();
    _mapRefreshTimer?.cancel();
    _pulseCtrl.stop();
    _showSummary();
  }

  void _confirmStop() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('End Workout?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('You\'ve done ${_mgr.steps} steps in ${_mgr.elapsedFormatted}. End and collect FKC?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Keep Going', style: TextStyle(fontWeight: FontWeight.w700))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () { Navigator.pop(context); _stop(); },
          child: const Text('End Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]));
  }

  void _showSummary() {
    final steps    = _mgr.steps;
    final elapsed  = _mgr.elapsed;
    final dist     = _mgr.distanceKm;
    final calories = _mgr.calories;
    final coins    = _mgr.coins;
    final type     = _mgr.type;
    final route    = List<LatLng>.from(_routePoints);
    final moveMins = _moveMinutes;
    _mgr.stop();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, isDismissible: false,
      builder: (_) => _SummarySheet(
        type: type, steps: steps, elapsed: elapsed,
        distanceKm: dist, calories: calories, coinsEarned: coins,
        moveMinutes: moveMins, routePoints: route,
        onDone: () { Navigator.pop(context); Navigator.pop(context); },
      ));
  }

  // ── Computed metrics ─────────────────────────────────────────────────────
  String get _pace {
    final dist = _mgr.distanceKm;
    final mins = _mgr.elapsed / 60;
    if (dist < 0.05 || mins < 1) return '–';
    final minsPerKm = mins / dist;
    final m = minsPerKm.floor();
    final s = ((minsPerKm - m) * 60).round();
    return "${m}'${s.toString().padLeft(2,'0')}\"";
  }

  String get _speedKmh {
    final mins = _mgr.elapsed / 60;
    if (mins < 1 || _mgr.distanceKm < 0.01) return '0.0';
    return (_mgr.distanceKm / (mins / 60)).toStringAsFixed(1);
  }

  int get _heartPoints {
    if (_moveMinutes == 0) return 0;
    final stepsPerMin = _moveMinutes > 0 ? _mgr.steps / _moveMinutes : 0;
    return stepsPerMin >= 100 ? (_moveMinutes * 2) : _moveMinutes;
  }

  String get _activeTime {
    final s = _mgr.elapsed;
    if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
    return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final color = workoutColor(widget.type);
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(child: Column(children: [
        _buildHeader(color),
        Expanded(child: _sessionStarted ? _buildActive(color) : _buildIdle(color)),
        _buildControls(color),
      ])),
    );
  }

  Widget _buildHeader(Color color) => Container(
    padding: const EdgeInsets.fromLTRB(16,12,16,12),
    decoration: BoxDecoration(color: Colors.white,
      boxShadow: [BoxShadow(color: AppColors.border.withOpacity(0.5), blurRadius: 8)]),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.scaffold, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary))),
      const SizedBox(width: 12),
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(widget.type.emoji, style: const TextStyle(fontSize: 20)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.type.label} Session',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Row(children: [
          Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _mgr.isActive && !_mgr.isPaused ? AppColors.green : AppColors.textMuted)),
          Text(
            _mgr.isActive ? (_mgr.isPaused ? 'Paused' : '● Live') : 'Ready',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _mgr.isActive && !_mgr.isPaused ? AppColors.green : AppColors.textSecondary)),
        ]),
      ])),
      if (_mgr.isActive)
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('Go back', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)))),
    ]));

  Widget _buildIdle(Color color) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 24),
      Container(width: 120, height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 24, offset: const Offset(0,8))]),
        child: Center(child: Text(widget.type.emoji, style: const TextStyle(fontSize: 52)))),
      const SizedBox(height: 28),
      Text('Ready to ${widget.type.label}?',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text(
        'Earn ${workoutMultiplier(widget.type) == 1.5 ? "1.5× " : ""}FKC for every 1,000 steps.\nYour session keeps running if you go back to the app.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
      const SizedBox(height: 32),
      _InfoCard(icon: Icons.directions_walk_rounded, color: color,
        title: 'Steps via Health Connect', subtitle: 'Auto-synced from Google Fit / Apple Health'),
      const SizedBox(height: 10),
      _InfoCard(icon: Icons.map_outlined, color: AppColors.accent,
        title: 'Live Route Map', subtitle: 'GPS tracks your path in real time'),
      const SizedBox(height: 10),
      _InfoCard(icon: Icons.monitor_heart_outlined, color: AppColors.red,
        title: 'Heart Points & Pace', subtitle: 'WHO-standard activity metrics tracked live'),
      const SizedBox(height: 32),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Text('🪙', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Earn FKC while you move',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('1,000 steps = 1 FKC${workoutMultiplier(widget.type) == 1.5 ? " × 1.5 (run bonus!)" : ""}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ])),
    ]));

  Widget _buildActive(Color color) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(children: [

      // ── Timer card ───────────────────────────────────────
      ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.75)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,8))]),
          child: Column(children: [
            Text(_mgr.elapsedFormatted,
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(_mgr.isPaused ? 'PAUSED' : 'ELAPSED TIME',
              style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ]))),
      const SizedBox(height: 12),

      // ── 6-metric grid ─────────────────────────────────────
      Row(children: [
        _LiveTile(emoji: '👟', value: _mgr.steps.toString(), label: 'Steps', color: color),
        const SizedBox(width: 8),
        _LiveTile(emoji: '⏱️', value: _activeTime, label: 'Active Time', color: AppColors.primary),
        const SizedBox(width: 8),
        _LiveTile(emoji: '📍', value: '${_mgr.distanceKm.toStringAsFixed(2)} km', label: 'Distance', color: AppColors.green),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _LiveTile(emoji: '🔥', value: '${_mgr.calories.toStringAsFixed(0)}', sublabel: 'kcal', label: 'Calories', color: const Color(0xFFF97316)),
        const SizedBox(width: 8),
        _LiveTile(emoji: '🏃', value: '$_moveMinutes', sublabel: 'min', label: 'Move Mins', color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        _LiveTile(emoji: '⚡', value: _pace, sublabel: _pace == '–' ? '' : 'min/km', label: 'Pace', color: AppColors.red,
          extra: _pace == '–' ? '' : '$_speedKmh km/h'),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _LiveTile(emoji: '❤️', value: '$_heartPoints', sublabel: 'pts', label: 'Heart Points', color: AppColors.accent,
          extra: _heartPoints >= 10 ? '✓ Active' : 'Goal: 10'),
        const SizedBox(width: 8),
        _LiveTile(emoji: '🪙', value: _mgr.coins.toStringAsFixed(2), sublabel: 'FKC', label: 'Coins', color: AppColors.yellow),
        const SizedBox(width: 8),
        _LiveTile(emoji: '₹', value: ((_mgr.coins) * 0.33).toStringAsFixed(2), sublabel: 'INR', label: 'Value', color: AppColors.green),
      ]),
      const SizedBox(height: 12),

      // ── Live Map ──────────────────────────────────────────
      Container(
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,8),
            child: Row(children: [
              const Text('🗺️ Live Route', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _followUser = !_followUser),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _followUser ? color.withOpacity(0.1) : AppColors.scaffold,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _followUser ? color : AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.my_location_rounded, size: 12, color: _followUser ? color : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_followUser ? 'Following' : 'Free',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _followUser ? color : AppColors.textSecondary)),
                  ]))),
            ])),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SizedBox(
              height: 260,
              child: _currentPos == null
                ? Container(color: const Color(0xFFE8EFF8),
                    child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.location_searching_rounded, size: 40, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text('Acquiring GPS...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Ensure location is enabled', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ])))
                : _SafeMap(
                    currentPos: _currentPos!,
                    routePoints: _routePoints,
                    color: color,
                    workoutType: widget.type,
                    onMapCreated: (ctrl) { _mapCtrl = ctrl; setState(() => _mapReady = true); },
                    onTap: () => setState(() => _followUser = false),
                  ),
            )),
        ])),
      const SizedBox(height: 8),

      // Info hint
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text('Go back to the app — session keeps running. Tap banner to return.',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500))),
        ])),
      const SizedBox(height: 4),
    ]));

  Widget _buildControls(Color color) => Container(
    padding: const EdgeInsets.fromLTRB(20,14,20,20),
    color: Colors.white,
    child: !_sessionStarted
      ? GestureDetector(
          onTap: _start,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0,6))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text('Start ${widget.type.label}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ])))
      : Row(children: [
          Expanded(child: GestureDetector(
            onTap: _mgr.isPaused ? _resume : _pause,
            child: Container(height: 58,
              decoration: BoxDecoration(
                color: _mgr.isPaused ? color : AppColors.scaffold,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _mgr.isPaused ? color : AppColors.border)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_mgr.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: _mgr.isPaused ? Colors.white : AppColors.textPrimary, size: 24),
                const SizedBox(width: 6),
                Text(_mgr.isPaused ? 'Resume' : 'Pause',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _mgr.isPaused ? Colors.white : AppColors.textPrimary)),
              ]),
            ))),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _confirmStop,
            child: Container(width: 58, height: 58,
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28))),
        ]));
}


// ── Safe Map wrapper ──────────────────────────────────────────────────────────
class _SafeMap extends StatefulWidget {
  final LatLng currentPos;
  final List<LatLng> routePoints;
  final Color color;
  final WorkoutType workoutType;
  final bool summaryMode;
  final LatLng? startPos;
  final void Function(GoogleMapController)? onMapCreated;
  final VoidCallback? onTap;

  const _SafeMap({
    required this.currentPos,
    required this.routePoints,
    required this.color,
    required this.workoutType,
    this.summaryMode = false,
    this.startPos,
    this.onMapCreated,
    this.onTap,
  });

  @override State<_SafeMap> createState() => _SafeMapState();
}

class _SafeMapState extends State<_SafeMap> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _fallback();
    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
            target: widget.currentPos, zoom: widget.summaryMode ? 15 : 16),
        onMapCreated: widget.onMapCreated,
        myLocationEnabled: !widget.summaryMode,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        scrollGesturesEnabled: !widget.summaryMode,
        zoomGesturesEnabled: !widget.summaryMode,
        rotateGesturesEnabled: !widget.summaryMode,
        onTap: widget.onTap != null ? (_) => widget.onTap!() : null,
        polylines: widget.routePoints.length >= 2 ? {
          Polyline(
            polylineId: const PolylineId('route'),
            points: widget.routePoints,
            color: widget.color,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round),
        } : {},
        markers: {
          if (widget.summaryMode && widget.startPos != null)
            Marker(
              markerId: const MarkerId('start'),
              position: widget.startPos!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Start')),
          Marker(
            markerId: const MarkerId('current'),
            position: widget.currentPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.summaryMode ? BitmapDescriptor.hueRed
              : widget.workoutType == WorkoutType.run ? BitmapDescriptor.hueRose
              : widget.workoutType == WorkoutType.cycle ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: widget.summaryMode ? 'End' : '\${widget.workoutType.label} Position')),
        });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasError = true);
      });
      return _fallback();
    }
  }

  Widget _fallback() => Container(
    color: const Color(0xFFE8EFF8),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.map_outlined, size: 40, color: AppColors.textSecondary),
      const SizedBox(height: 8),
      const Text('Map unavailable', style: TextStyle(fontSize: 13,
        fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      const Text('Check Maps API key in AndroidManifest.xml',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(20)),
        child: const Text('Route tracking still active',
          style: TextStyle(fontSize: 10, color: AppColors.primary,
            fontWeight: FontWeight.w600))),
    ])));
}

// ── Live metric tile ──────────────────────────────────────────────────────────
class _LiveTile extends StatelessWidget {
  final String emoji, value, label;
  final String? sublabel, extra;
  final Color color;
  const _LiveTile({required this.emoji, required this.value, required this.label,
    required this.color, this.sublabel, this.extra});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10,10,10,10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color))),
        if (sublabel != null && sublabel!.isNotEmpty)
          Text(sublabel!, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7), fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        if (extra != null && extra!.isNotEmpty)
          Text(extra!, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
      ])));
}

// ── Live session banner ───────────────────────────────────────────────────────
class LiveSessionBanner extends StatefulWidget {
  final VoidCallback onTap;
  const LiveSessionBanner({super.key, required this.onTap});
  @override State<LiveSessionBanner> createState() => _LiveSessionBannerState();
}

class _LiveSessionBannerState extends State<LiveSessionBanner> {
  final _mgr = WorkoutSessionManager();
  @override void initState()  { super.initState(); _mgr.addListener(_onUpdate); }
  @override void dispose()    { _mgr.removeListener(_onUpdate); super.dispose(); }
  void _onUpdate()            { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (!_mgr.isActive) return const SizedBox.shrink();
    final color = workoutColor(_mgr.type);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.85)])),
        child: Row(children: [
          Text(_mgr.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_mgr.type.label} session ${_mgr.isPaused ? "paused" : "in progress"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('${_mgr.elapsedFormatted}  ·  ${_mgr.steps} steps  ·  ${_mgr.coins.toStringAsFixed(1)} FKC',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Text('Return →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
        ])));
  }
}

// ── Summary sheet ─────────────────────────────────────────────────────────────
class _SummarySheet extends StatelessWidget {
  final WorkoutType type;
  final int steps, elapsed, moveMinutes;
  final double distanceKm, calories, coinsEarned;
  final List<LatLng> routePoints;
  final VoidCallback onDone;

  const _SummarySheet({required this.type, required this.steps, required this.elapsed,
    required this.distanceKm, required this.calories, required this.coinsEarned,
    required this.moveMinutes, required this.routePoints, required this.onDone});

  String get _dur { final m = elapsed ~/ 60; final s = elapsed % 60; return '${m}m ${s}s'; }

  String get _pace {
    if (distanceKm < 0.05 || elapsed < 60) return '–';
    final minsPerKm = (elapsed / 60) / distanceKm;
    final m = minsPerKm.floor();
    final s = ((minsPerKm - m) * 60).round();
    return "${m}'${s.toString().padLeft(2,'0')}\"";
  }

  int get _heartPoints {
    if (moveMinutes == 0) return 0;
    final spm = moveMinutes > 0 ? steps / moveMinutes : 0;
    return spm >= 100 ? moveMinutes * 2 : moveMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final color = workoutColor(type);
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24,20,24,32),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),

        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            shape: BoxShape.circle),
          child: const Center(child: Text('🏆', style: TextStyle(fontSize: 34)))),
        const SizedBox(height: 12),
        const Text('Workout Complete!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Great ${type.label.toLowerCase()}! Here\'s your summary.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // 8-stat grid
        Container(padding: const EdgeInsets.all(14), decoration: cardDecoration(),
          child: Column(children: [
            Row(children: [
              _SumStat(emoji: '👟', value: steps.toString(),              label: 'Steps'),
              _SumStat(emoji: '⏱️', value: _dur,                          label: 'Duration'),
              _SumStat(emoji: '📍', value: '${distanceKm.toStringAsFixed(2)}km', label: 'Distance'),
              _SumStat(emoji: '🔥', value: '${calories.toStringAsFixed(0)}kcal', label: 'Calories'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _SumStat(emoji: '🏃', value: '$moveMinutes min',            label: 'Move Mins'),
              _SumStat(emoji: '⚡', value: _pace,                         label: 'Avg Pace'),
              _SumStat(emoji: '❤️', value: '$_heartPoints pts',           label: 'Heart Pts'),
              _SumStat(emoji: '🪙', value: '+${coinsEarned.toStringAsFixed(2)}', label: 'FKC Earned'),
            ]),
          ])),
        const SizedBox(height: 12),

        // Route map (if GPS captured)
        if (routePoints.length >= 2) ...[
          Container(decoration: cardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(14,12,14,8),
              child: Text('🗺️ Your Route', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: SizedBox(height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: routePoints.last, zoom: 15),
                  zoomControlsEnabled: false, mapToolbarEnabled: false,
                  myLocationButtonEnabled: false, scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false, rotateGesturesEnabled: false,
                  polylines: {
                    Polyline(polylineId: const PolylineId('summary_route'),
                      points: routePoints, color: color, width: 5,
                      startCap: Cap.roundCap, endCap: Cap.roundCap)
                  },
                  markers: {
                    Marker(markerId: const MarkerId('start'), position: routePoints.first,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                    Marker(markerId: const MarkerId('end'), position: routePoints.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                  }))),
          ])),
          const SizedBox(height: 12),
        ],

        // FKC earned
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.yellow.withOpacity(0.4))),
          child: Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FKC Earned', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text('+${coinsEarned.toStringAsFixed(2)} FKC',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              Text('≈ ₹${(coinsEarned * 0.33).toStringAsFixed(2)} redeemable value',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            if (type == WorkoutType.run) ...[ const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: const Text('1.5× Bonus!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
            ],
          ])),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Collect FKC 🪙',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)))),
      ])));
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _SumStat extends StatelessWidget {
  final String emoji, value, label;
  const _SumStat({required this.emoji, required this.value, required this.label});
  @override Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 4),
    FittedBox(fit: BoxFit.scaleDown,
      child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
  ]));
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle;
  const _InfoCard({required this.icon, required this.color, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Icon(Icons.check_circle, color: color, size: 18),
    ]));
}
