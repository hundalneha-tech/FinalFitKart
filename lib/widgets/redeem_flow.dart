// lib/widgets/redeem_flow.dart
// Shared redeem perk flow used by Home + Perks screens
// Steps: 1) Check balance  2) Confirm  3) Call Supabase  4) Show voucher

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class RedeemFlow {
  /// Call this from any Redeem button
  static Future<void> start(BuildContext context, Perk perk) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;

    // ── Step 1: Check balance ────────────────────────────
    double balance = 0;
    try {
      final w = await sb.from('wallets').select('balance').eq('user_id', uid).single();
      balance = (w['balance'] as num?)?.toDouble() ?? 0;
    } catch (_) {}

    if (!context.mounted) return;

    if (balance < perk.coins) {
      // Not enough coins
      _showNotEnough(context, perk, balance);
      return;
    }

    // ── Step 2: Confirm dialog ────────────────────────────
    final confirmed = await _showConfirm(context, perk, balance);
    if (confirmed != true || !context.mounted) return;

    // ── Step 3: Process redemption ────────────────────────
    _showLoading(context);
    try {
      // Deduct coins via RPC
      await sb.rpc('transact_coins', params: {
        'p_user_id':    uid,
        'p_amount':     -perk.coins,
        'p_type':       'REDEEM_PERK',
        'p_description': 'Redeemed: ${perk.brand} — ${perk.discountLabel}',
      });

      // Insert redemption record
      final redemption = await sb.from('redemptions').insert({
        'user_id':  uid,
        'perk_id':  perk.id,
        'coins_spent': perk.coins,
        'status':   'active',
      }).select('voucher_code').single();

      final voucherCode = redemption['voucher_code'] as String? ?? _generateCode(perk);

      if (context.mounted) {
        Navigator.pop(context); // close loading
        _showVoucher(context, perk, voucherCode, balance - perk.coins);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        _showError(context, e.toString());
      }
    }
  }

  // ── Not enough coins dialog ──────────────────────────────
  static void _showNotEnough(BuildContext ctx, Perk perk, double balance) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Not Enough Coins', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('😔', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('You need ${perk.coins} FKC but only have ${balance.toStringAsFixed(0)} FKC.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text('Keep walking to earn ${(perk.coins - balance).toStringAsFixed(0)} more FKC!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Keep Walking! 🚶', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ],
    ));
  }

  // ── Confirm dialog ───────────────────────────────────────
  static Future<bool?> _showConfirm(BuildContext ctx, Perk perk, double balance) {
    return showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Brand icon
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(20)),
          child: Center(child: Text(_brandEmoji(perk.category), style: const TextStyle(fontSize: 36)))),
        const SizedBox(height: 16),
        Text(perk.brand, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(perk.discountLabel, style: const TextStyle(fontSize: 14, color: AppColors.green, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Cost', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Row(children: [
                CoinDot(),
                const SizedBox(width: 5),
                Text('${perk.coins} FKC', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Your Balance', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('${balance.toStringAsFixed(0)} FKC', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Balance After', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${(balance - perk.coins).toStringAsFixed(0)} FKC',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: balance - perk.coins >= 0 ? AppColors.green : AppColors.red)),
            ]),
          ])),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Redeem Now ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ],
    ));
  }

  // ── Loading overlay ──────────────────────────────────────
  static void _showLoading(BuildContext ctx) {
    showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        child: Padding(padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Processing redemption...', style: TextStyle(fontWeight: FontWeight.w600)),
          ])))));
  }

  // ── Voucher success screen ───────────────────────────────
  static void _showVoucher(BuildContext ctx, Perk perk, String code, double newBalance) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 20),
          // Success icon
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.greenBg, shape: BoxShape.circle),
            child: const Center(child: Text('🎉', style: TextStyle(fontSize: 40)))),
          const SizedBox(height: 16),
          const Text('Voucher Unlocked!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('${perk.brand} — ${perk.discountLabel}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // Voucher code
          const Text('Your Voucher Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                content: Text('Code copied to clipboard! 📋'),
                backgroundColor: AppColors.green,
                behavior: SnackBarBehavior.floating));
            },
            child: Container(width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFEDE9FE)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 3)),
                const SizedBox(width: 12),
                const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
              ]))),
          const SizedBox(height: 12),
          const Text('Tap to copy • Valid for 30 days',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // New balance
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CoinDot(size: 24),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('New Balance', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text('${newBalance.toStringAsFixed(0)} FKC',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ]),
              const Spacer(),
              const Text('≈', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              Text('₹${(newBalance * 0.33).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.green)),
            ])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Done 🎉', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
        ])));
  }

  // ── Error ─────────────────────────────────────────────────
  static void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('Redemption failed: $msg'),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating));
  }

  // ── Helpers ───────────────────────────────────────────────
  static String _brandEmoji(String cat) {
    switch(cat) {
      case 'Fashion':       return '👗';
      case 'Food':          return '🍔';
      case 'Entertainment': return '🎬';
      case 'Beauty':        return '💄';
      default:              return '🎁';
    }
  }

  // Fallback code if DB doesn't return one (e.g. no voucher_code column yet)
  static String _generateCode(Perk perk) {
    final prefix = perk.brand.substring(0, min(3, perk.brand.length)).toUpperCase();
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return '$prefix-$suffix';
  }
}

int min(int a, int b) => a < b ? a : b;
