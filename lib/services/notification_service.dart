// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _sb      = Supabase.instance.client;
  final _fcm     = FirebaseMessaging.instance;
  final _local   = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'fitkart_main';
  static const _channelName = 'FitKart Notifications';

  int  _unreadCount = 0;
  bool _initialized = false;
  int  get unreadCount => _unreadCount;

  // ── Init ─────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 2. Request permission (Android 13+ / iOS)
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false);
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // 3. Set up local notification channel (Android)
    const androidChannel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: 'FitKart activity and social notifications',
      importance: Importance.high,
      playSound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 4. Init local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings,
        onDidReceiveNotificationResponse: _onLocalNotifTap);

    // 5. Get & save FCM token
    final token = await _fcm.getToken();
    if (token != null) await _saveFcmToken(token);
    _fcm.onTokenRefresh.listen(_saveFcmToken);

    // 6. Foreground message handler — show local notification
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 7. Background tap handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 8. App opened from terminated via notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 9. Load unread count from DB
    await _loadUnreadCount();

    debugPrint('FCM init complete, token: ${token?.substring(0, 20)}...');
  }

  // ── Foreground: show as local notification ────────────────
  Future<void> _handleForeground(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null) return;

    await _local.show(
      msg.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );

    // Increment badge
    _unreadCount++;
    notifyListeners();
  }

  // ── Tap handler ───────────────────────────────────────────
  void _handleTap(RemoteMessage msg) {
    debugPrint('FCM tap: ${msg.data}');
    // Navigation handled by app based on msg.data['type']
  }

  void _onLocalNotifTap(NotificationResponse res) {
    debugPrint('Local notif tapped: ${res.payload}');
  }

  // ── Save token to Supabase profiles ──────────────────────
  Future<void> _saveFcmToken(String token) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('profiles').update({'fcm_token': token}).eq('id', uid);
      debugPrint('FCM token saved');
    } catch (e) {
      debugPrint('Save FCM token error: $e');
    }
  }

  // ── Unread count from Supabase ────────────────────────────
  Future<void> _loadUnreadCount() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await _sb.from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false);
      _unreadCount = (res as List).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(String notifId) async {
    try {
      await _sb.from('notifications').update({'is_read': true}).eq('id', notifId);
      if (_unreadCount > 0) { _unreadCount--; notifyListeners(); }
    } catch (_) {}
  }

  Future<void> refresh() => _loadUnreadCount();
}
