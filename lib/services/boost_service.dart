// lib/services/boost_service.dart
// 2× Boost — 30-minute multiplier stored in Supabase profiles
// Checks boost_active_until column; broadcasts to WorkoutSessionManager

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoostService extends ChangeNotifier {
  static final BoostService _i = BoostService._();
  factory BoostService() => _i;
  BoostService._();

  final _sb = Supabase.instance.client;

  DateTime? _boostUntil;
  Timer?    _countdownTimer;

  bool   get isActive      => _boostUntil != null && _boostUntil!.isAfter(DateTime.now());
  double get multiplier    => isActive ? 2.0 : 1.0;
  Duration get remaining   => isActive ? _boostUntil!.difference(DateTime.now()) : Duration.zero;
  String get remainingLabel {
    final r = remaining;
    if (r.inSeconds <= 0) return '0:00';
    final m = r.inMinutes.remainder(60).toString().padLeft(2,'0');
    final s = r.inSeconds.remainder(60).toString().padLeft(2,'0');
    return '$m:$s';
  }

  // ── Load boost state from DB ──────────────────────────────
  Future<void> load() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await _sb.from('profiles')
          .select('boost_active_until')
          .eq('id', uid)
          .single();
      final raw = data['boost_active_until'];
      if (raw != null) {
        _boostUntil = DateTime.tryParse(raw as String);
        if (isActive) _startCountdown();
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Activate boost ────────────────────────────────────────
  Future<bool> activate() async {
    if (isActive) return false;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final until = DateTime.now().add(const Duration(minutes: 30));
      await _sb.from('profiles')
          .update({'boost_active_until': until.toIso8601String()})
          .eq('id', uid);
      _boostUntil = until;
      _startCountdown();
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isActive) {
        _boostUntil = null;
        _countdownTimer?.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() { _countdownTimer?.cancel(); super.dispose(); }
}
