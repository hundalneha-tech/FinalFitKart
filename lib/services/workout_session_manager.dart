// lib/services/workout_session_manager.dart
// Global singleton that keeps workout session alive across navigation
// Any screen can check if a session is running and return to it

import 'dart:async';
import 'boost_service.dart';
import 'package:flutter/foundation.dart';


enum WorkoutType { walk, run, cycle }

extension WorkoutTypeExt on WorkoutType {
  String get label => name[0].toUpperCase() + name.substring(1);
  String get emoji {
    switch (this) {
      case WorkoutType.walk:  return '🚶';
      case WorkoutType.run:   return '🏃';
      case WorkoutType.cycle: return '🚴';
    }
  }
}

class WorkoutSessionManager extends ChangeNotifier {
  static final WorkoutSessionManager _i = WorkoutSessionManager._();
  factory WorkoutSessionManager() => _i;
  WorkoutSessionManager._();

  // Session state
  bool        _isActive   = false;
  bool        _isPaused   = false;
  WorkoutType _type       = WorkoutType.walk;
  int         _elapsed    = 0;   // seconds
  int         _steps      = 0;
  double      _distanceKm = 0;
  double      _coins      = 0;
  double      _calories   = 0;

  Timer? _clockTimer;

  // ── Getters ──────────────────────────────────────────────
  bool        get isActive    => _isActive;
  bool        get isPaused    => _isPaused;
  WorkoutType get type        => _type;
  int         get elapsed     => _elapsed;
  int         get steps       => _steps;
  double      get distanceKm  => _distanceKm;
  double      get coins       => _coins;
  double      get calories    => _calories;

  String get elapsedFormatted {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // ── Controls ─────────────────────────────────────────────

  void start(WorkoutType type) {
    _type     = type;
    _isActive = true;
    _isPaused = false;
    _elapsed  = 0;
    _steps    = 0;
    _distanceKm = 0;
    _coins    = 0;
    _calories = 0;
    _startClock();
    notifyListeners();
  }

  void pause() {
    _isPaused = true;
    _clockTimer?.cancel();
    notifyListeners();
  }

  void resume() {
    _isPaused = false;
    _startClock();
    notifyListeners();
  }

  void stop() {
    _isActive = false;
    _isPaused = false;
    _clockTimer?.cancel();
    notifyListeners();
  }

  void updateStats({int? steps, double? distanceKm}) {
    if (steps != null)      _steps      = steps;
    if (distanceKm != null) _distanceKm = distanceKm;
    _calories = _steps * 0.04;
    final typeMult  = _type == WorkoutType.run ? 1.5 : _type == WorkoutType.cycle ? 0.8 : 1.0;
    final boostMult = BoostService().multiplier;
    _coins = (_steps * 0.001 * typeMult * boostMult).clamp(0, 10);
    notifyListeners();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
