// lib/services/notification_service.dart
// FCM push notifications + in-app notification feed from Supabase
// 
// SETUP REQUIRED (one-time):
//   1. Go to firebase.google.com → create project → Add Android app
//      Package name: com.fitkart.app
//   2. Download google-services.json → place at android/app/google-services.json
//   3. In android/build.gradle add: classpath 'com.google.gms:google-services:4.3.15'
//   4. In android/app/build.gradle add: apply plugin: 'com.google.gms.google-services'
//   5. In pubspec.yaml add:
//        firebase_core: ^2.24.0
//        firebase_messaging: ^14.7.10
//        flutter_local_notifications: ^16.3.0
//   6. In main.dart call: await NotificationService().init();

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _sb = Supabase.instance.client;
  int  _unreadCount = 0;
  bool _initialized = false;

  int  get unreadCount => _unreadCount;

  // ── Init ─────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadUnreadCount();

    // NOTE: Real FCM init goes here once Firebase is configured.
    // Uncomment after adding Firebase dependencies:
    //
    // await Firebase.initializeApp();
    // final messaging = FirebaseMessaging.instance;
    //
    // // Request permission (iOS + Android 13+)
    // await messaging.requestPermission(alert: true, badge: true, sound: true);
    //
    // // Get FCM token and save to Supabase profiles
    // final token = await messaging.getToken();
    // if (token != null) await _saveFcmToken(token);
    //
    // // Handle foreground messages
    // FirebaseMessaging.onMessage.listen(_handleForeground);
    //
    // // Handle background tap
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  Future<void> _loadUnreadCount() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await _sb.from('notifications')
          .select('id')
          .eq('is_read', false)
          .or('user_id.eq.$uid,user_id.is.null');
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

  // Called from screens when they navigate back from notifications
  Future<void> refresh() => _loadUnreadCount();

  // ── FCM token save (uncomment after Firebase setup) ───────
  // Future<void> _saveFcmToken(String token) async {
  //   final uid = _sb.auth.currentUser?.id;
  //   if (uid == null) return;
  //   await _sb.from('profiles').update({'fcm_token': token}).eq('id', uid);
  // }
}
