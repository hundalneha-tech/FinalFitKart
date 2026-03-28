// lib/services/workout_background_service.dart
// Android Foreground Service for background workout tracking
// Shows a persistent notification with live step + coin count
// Session continues even when app is minimised or screen off

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'workout_session_manager.dart';
import 'pedometer_service.dart';

class WorkoutBackgroundService {
  static final WorkoutBackgroundService _i = WorkoutBackgroundService._();
  factory WorkoutBackgroundService() => _i;
  WorkoutBackgroundService._();

  static const _notifId      = 888;
  static const _channelId    = 'fitkart_workout';
  static const _channelName  = 'FitKart Workout';

  final _notif = FlutterLocalNotificationsPlugin();
  final _mgr   = WorkoutSessionManager();

  Timer? _updateTimer;
  bool   _running = false;

  // ── Init (call once from main.dart) ──────────────────────
  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _notif.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotifTap,
    );

    // Create high-priority channel for foreground service
    const channel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: 'Live workout tracking notification',
      importance: Importance.low,       // low = no sound, but persistent
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Start foreground notification when session starts ────
  Future<void> startForeground(WorkoutType type) async {
    if (_running) return;
    _running = true;

    await _showNotification(type, 0, 0.0);

    // Update notification every 5 seconds with live data
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_mgr.isActive) { stopForeground(); return; }
      _showNotification(_mgr.type, _mgr.steps, _mgr.coins);
    });
  }

  // ── Stop foreground notification ─────────────────────────
  Future<void> stopForeground() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    _running = false;
    await _notif.cancel(_notifId);
  }

  // ── Show / update the persistent notification ─────────────
  Future<void> _showNotification(WorkoutType type, int steps, double coins) async {
    final emoji    = type == WorkoutType.run ? '🏃' : type == WorkoutType.cycle ? '🚴' : '🚶';
    final label    = type == WorkoutType.run ? 'Run' : type == WorkoutType.cycle ? 'Cycle' : 'Walk';
    final stepsStr = steps >= 1000 ? '${(steps/1000).toStringAsFixed(1)}k' : '$steps';
    final elapsed  = _mgr.elapsedFormatted;

    final androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: 'Live workout tracking',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,              // Cannot be dismissed by user swipe
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      usesChronometer: true,      // Shows live timer in notification
      chronometerCountDown: false,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        '$stepsStr steps  ·  ${coins.toStringAsFixed(2)} FKC earned  ·  $elapsed',
        contentTitle: '$emoji $label Session Active',
        summaryText: 'Tap to return to FitKart',
      ),
      actions: [
        const AndroidNotificationAction('pause', 'Pause',
          showsUserInterface: false, cancelNotification: false),
        const AndroidNotificationAction('stop', 'Stop',
          showsUserInterface: true, cancelNotification: false),
      ],
    );

    await _notif.show(
      _notifId,
      '$emoji $label in progress',
      '$stepsStr steps  ·  ${coins.toStringAsFixed(2)} FKC  ·  $elapsed',
      NotificationDetails(android: androidDetails),
    );
  }

  // ── Notification tap / action handler ────────────────────
  void _onNotifTap(NotificationResponse response) {
    if (response.actionId == 'pause') {
      if (_mgr.isActive && !_mgr.isPaused) _mgr.pause();
      else if (_mgr.isPaused) _mgr.resume();
    } else if (response.actionId == 'stop') {
      _mgr.stop();
      stopForeground();
    }
    // Default tap opens app (Flutter handles this automatically)
  }

  bool get isRunning => _running;
}
