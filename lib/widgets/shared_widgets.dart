// lib/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Coin badge ────────────────────────────────────────────────
class CoinBadge extends StatelessWidget {
  final double amount;
  final double fontSize;
  const CoinBadge({super.key, required this.amount, this.fontSize = 13});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: fontSize + 4, height: fontSize + 4,
        decoration: const BoxDecoration(color: AppColors.coin, shape: BoxShape.circle),
        child: Center(child: Text('C', style: TextStyle(fontSize: fontSize - 3, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
      const SizedBox(width: 4),
      Text('${amount % 1 == 0 ? amount.toInt() : amount} Coins',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ],
  );
}

// ── INR value pill ────────────────────────────────────────────
class InrPill extends StatelessWidget {
  final double value;
  final Color? bg;
  final Color? textColor;
  const InrPill({super.key, required this.value, this.bg, this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? AppColors.greenBg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text('≈ ₹${value.toStringAsFixed(0)}',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: textColor ?? AppColors.green)),
  );
}

// ── Section header row ────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
    ],
  );
}

// ── Blue primary button ───────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  final bool loading;
  const PrimaryButton({super.key, required this.label, this.onPressed,
    this.icon, this.color, this.height = 52, this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: height,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
    ),
  );
}

// ── Outline button ────────────────────────────────────────────
class OutlineButton2 extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const OutlineButton2({super.key, required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    ),
  );
}

// ── Avatar circle (initials fallback) ────────────────────────
class AvatarCircle extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? color;
  final bool showOnline;
  const AvatarCircle({super.key, required this.name, this.imageUrl,
    this.size = 42, this.color, this.showOnline = false});

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get bgColor => color ?? AppColors.primary;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
        alignment: Alignment.center,
        child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? ClipOval(child: Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36))))
          : Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
      ),
      if (showOnline)
        Positioned(
          bottom: 1, right: 1,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
          ),
        ),
    ],
  );
}

// ── Streak flame badge ────────────────────────────────────────
class StreakBadge extends StatelessWidget {
  final int days;
  const StreakBadge({super.key, required this.days});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.local_fire_department, size: 14, color: AppColors.accent),
      const SizedBox(width: 2),
      Text('$days Day Streak',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    ],
  );
}

// ── Progress bar ──────────────────────────────────────────────
class FKProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color? color;
  final double height;
  final Color? bgColor;
  const FKProgressBar({super.key, required this.value, this.color, this.height = 7, this.bgColor});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      backgroundColor: bgColor ?? AppColors.border,
      valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
      minHeight: height,
    ),
  );
}

// ── Category chip ─────────────────────────────────────────────
class CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  const CategoryChip({super.key, required this.label, required this.active,
    required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: active ? Colors.white : AppColors.textSecondary), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

// ── Yellow boost banner ───────────────────────────────────────
class BoostBanner extends StatelessWidget {
  final VoidCallback onActivate;
  const BoostBanner({super.key, required this.onActivate});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.yellow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Double your coins!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
            SizedBox(height: 2),
            Text('Activate 2x boost for the next 30 minutes', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        )),
        GestureDetector(
          onTap: onActivate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
            child: const Text('Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ],
    ),
  );
}

// ── Discount badge overlay ────────────────────────────────────
class DiscountBadge extends StatelessWidget {
  final String label;
  const DiscountBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
  );
}
