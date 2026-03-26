// lib/screens/notifications_screen.dart
// Loads notifications from Supabase `notifications` table
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _sb = Supabase.instance.client;
  List<Map<String,dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final data = await _sb.from('notifications')
          .select('*')
          .or('user_id.eq.$uid,user_id.is.null')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() {
        _notifs  = List<Map<String,dynamic>>.from(data);
        _loading = false;
      });
      // Mark all read
      await NotificationService().markAllRead();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  String _timeAgo(Map n) {
    try {
      final dt  = DateTime.parse(n['created_at']).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 7)  return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  (IconData, Color, Color) _style(Map n) {
    switch ((n['type'] as String?) ?? 'general') {
      case 'goal_reached':   return (Icons.flag_rounded,           AppColors.green,   AppColors.greenBg);
      case 'challenge':      return (Icons.emoji_events_rounded,   AppColors.yellow,  AppColors.coinBg);
      case 'donation':       return (Icons.favorite_rounded,       AppColors.accent,  AppColors.accentBg);
      case 'coin_earned':    return (Icons.toll_rounded,           AppColors.primary, AppColors.primaryBg);
      case 'fraud_alert':    return (Icons.warning_rounded,        AppColors.red,     AppColors.redBg);
      case 'promotional':    return (Icons.local_offer_rounded,    AppColors.primary, AppColors.primaryBg);
      default:               return (Icons.notifications_rounded,  AppColors.textSecondary, AppColors.borderLight);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    appBar: AppBar(
      backgroundColor: AppColors.scaffold,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context)),
      title: const Text('Notifications',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      actions: [
        TextButton(
          onPressed: _load,
          child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : _notifs.isEmpty
        ? _empty()
        : RefreshIndicator(
            color: AppColors.primary, onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _notifs.length,
              separatorBuilder: (_,__) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n       = _notifs[i];
                final isRead  = n['is_read'] as bool? ?? false;
                final (icon, color, bg) = _style(n);
                return GestureDetector(
                  onTap: () async {
                    await NotificationService().markRead(n['id'] as String);
                    setState(() => _notifs[i] = {...n, 'is_read': true});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration().copyWith(
                      color: isRead ? Colors.white : AppColors.primaryBg.withOpacity(0.6),
                      border: Border.all(color: isRead ? AppColors.border.withOpacity(0.6) : AppColors.primary.withOpacity(0.2))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 42, height: 42,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: color, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n['title'] as String? ?? '',
                            style: TextStyle(fontSize: 13, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: AppColors.textPrimary))),
                          Text(_timeAgo(n), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ]),
                        const SizedBox(height: 3),
                        Text(n['body'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                      ])),
                      if (!isRead)
                        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, left: 6),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    ]),
                  ));
              })),
  );

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('🔔', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    const Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('We\'ll notify you about rewards, challenges\nand more as you walk!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
  ]));
}
