# 🚶 FitKart Club — Walk. Earn. Roar.

India's walk-to-earn fitness app. Users walk → earn FitKart Coins (FKC) → redeem perks or donate to causes.

## 🏗️ Architecture

```
Mobile App (Flutter - Android + iOS)
         ↓
   Supabase Backend
         ↑
Admin Dashboard (fitkart.club/fkadmin/)
```

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) — Android + iOS |
| Admin Dashboard | HTML/JS — hosted on GoDaddy |
| Backend | Supabase (DB + Auth + Edge Functions + Realtime) |
| Website | WordPress on GoDaddy |
| CI/CD | GitHub Actions |

## 🚀 Live URLs

- **Website:** https://fitkart.club
- **Admin Dashboard:** https://fitkart.club/fkadmin/
- **Supabase Project:** https://qtdlwbtfwteidjldpyvf.supabase.co
- **GitHub Repo:** https://github.com/hundalneha-tech/FinalFitKart

## 📱 App Features

- 6-screen onboarding (Slides → Auth → Profile → Body → Health → Rewards → Referral)
- Google Sign-In + Apple Sign-In + Email/Password auth
- Step tracking (pedometer + Google Fit / Apple Health)
- FKC Coin economy (1 coin per 100 steps, ₹0.33 per coin)
- Perks & vouchers (Myntra, Zomato, Starbucks, PVR, Nike, Nykaa, Amazon, Adidas)
- Donation causes (Stray Animals, Clean Water, Plant a Forest)
- Challenges & leaderboard
- Anti-cheat engine (5-layer validation)
- Referral system (500 FKC bonus)

## 🗄️ Database

15 Supabase tables:
`profiles` `wallets` `coin_transactions` `step_events` `step_batches`
`workout_sessions` `perks` `redemptions` `causes` `donations`
`challenges` `challenge_participants` `leaderboard_entries`
`friendships` `activity_feed` `fraud_logs` `notifications`
`brand_partners` `app_settings`

## 🔧 Setup

### 1. Supabase Setup
```bash
# Run in order in Supabase SQL Editor
supabase/migrations/01_schema.sql
supabase/migrations/02_seed_data.sql
supabase/migrations/03_rls_fixes.sql
```

### 2. Flutter App
```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://qtdlwbtfwteidjldpyvf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### 3. Build Release APK
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://qtdlwbtfwteidjldpyvf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### 4. Admin Dashboard
Upload `admin/index.html` to your hosting at `/fkadmin/index.html`

## 🔑 Google OAuth Setup

1. Create project at console.cloud.google.com
2. Web Client ID: `38568298435-r70rvv0c2o0gmdmpaeo82a8bs0j1cvqm.apps.googleusercontent.com`
3. Android Client ID: `38568298435-34uhl679kp7gcfekvtba73l5860qisnb.apps.googleusercontent.com`
4. SHA-1: `AE:11:00:02:FD:B6:72:C7:58:8F:1C:D3:D3:CF:91:CE:3F:E8:64:FC`

## 💰 FKC Coin Economy

| Parameter | Value |
|---|---|
| Coins per 100 steps | 1 FKC |
| INR per coin | ₹0.33 |
| Max coins per day | 10,000 FKC |
| 2× Boost multiplier | 2.0× |
| Referral bonus | 500 FKC |

## 🛡️ Anti-Cheat Engine

5-layer validation detecting:
STEP_STUFFING, GPS_SPOOFING, BOT_PATTERN, DEVICE_FARM, SENSOR_MANIPULATION,
VELOCITY_ANOMALY, SLEEP_STEPS, DUPLICATE_SESSION, COIN_LAUNDERING,
ACCOUNT_TAKEOVER, COLLUSION_RING, RAPID_COIN_DRAIN

Risk scores: APPROVE (0-29) / REVIEW (30-59) / BLOCK (60-84) / SUSPEND (85-100)

## 📂 Project Structure

```
fitkart_app/
├── lib/
│   ├── main.dart                    # App entry + auth gate
│   ├── screens/
│   │   ├── onboarding_screen.dart   # 6-step onboarding + auth
│   │   ├── home_screen.dart         # My Rewards
│   │   ├── move_screen.dart         # Step tracking
│   │   ├── perks_screen.dart        # Voucher store
│   │   ├── social_screen.dart       # Social hub
│   │   ├── community_screen.dart    # Challenges
│   │   └── profile_screen.dart      # User profile
│   ├── services/
│   │   ├── supabase_service.dart    # Supabase client
│   │   └── pedometer_service.dart   # Step counting
│   ├── models/models.dart           # Data models
│   ├── theme/app_theme.dart         # Design system
│   └── widgets/shared_widgets.dart  # Reusable components
├── admin/
│   └── index.html                   # Admin dashboard
├── website/
│   └── index.html                   # fitkart.club website
├── supabase/
│   └── migrations/
│       ├── 01_schema.sql            # Full DB schema
│       ├── 02_seed_data.sql         # Perks, challenges, causes
│       └── 03_rls_fixes.sql         # RLS + trigger fixes
└── .github/
    └── workflows/
        └── build.yml                # CI/CD - builds APK + web
```

## 🎯 Roadmap

- [ ] Google Play Store submission
- [ ] Apple App Store submission  
- [ ] Push notifications (FCM)
- [ ] Real step tracking on Android phone
- [ ] Live leaderboard (Supabase Realtime)
- [ ] Perk redemption flow
- [ ] Coin donation flow
- [ ] Challenge progress tracking

---
*Made with ❤️ in India · FitKart Club © 2026*
