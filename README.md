# FitKart Flutter App 🚶‍♂️
### Walk to Earn — Complete Flutter (Dart) Implementation

Pixel-faithful rebuild of the FlutterFlow design — all 7 screens, exact colors, components, and layout.

---

## Screens Built

| Screen | File | Matches |
|---|---|---|
| **Onboarding** | `onboarding_screen.dart` | Walk to Earn hero, Stride Cycle card, Perks preview, Get Started CTA |
| **Home** (My Rewards) | `home_screen.dart` | Balance card, Steps/Kcal tiles, Daily Goal bar, Featured Perks, Weekly chart, Boost banner |
| **Move** (Keep Moving) | `move_screen.dart` | Dual ring (blue+pink), Live Earnings gradient, Quick Start (Walk/Run/Cycle), Bar chart, Buddies |
| **Social Hub** | `social_screen.dart` | Invite/Community buttons, Challenges carousel, Leaderboard podium, Weekly/Monthly toggle |
| **My Community** | `community_screen.dart` | Global Challenge banner, Stats (Friends/Rank/Cheers), Active Friends, Activity feed |
| **Perks Store** | `perks_screen.dart` | Balance pill, Hot Deals banners, Category chips, Voucher cards with images |
| **Profile** | `profile_screen.dart` | Avatar+level, SOS banner, Wallet gradient card, Causes, Earnings chart, Walk history, Settings |

---

## Design System

All values extracted directly from your FlutterFlow screenshots:

```dart
// Primary brand colors
primary      = Color(0xFF2563EB)  // blue
accent       = Color(0xFFEC4899)  // pink/magenta
scaffold     = Color(0xFFF0F4FF)  // light blue-grey background
coin         = Color(0xFFFBBF24)  // gold
green        = Color(0xFF10B981)  // earnings/success

// Gradient (Move screen live earnings, Profile wallet)
gradStart → gradEnd = #2563EB → #EC4899

// Cards: white, 16px radius, subtle shadow, 0.5px border
```

---

## Project Structure

```
fitkart_app/
├── lib/
│   ├── main.dart                    # Entry point, onboarding gate
│   ├── theme/
│   │   └── app_theme.dart           # All colors, TextTheme, cardDecoration()
│   ├── models/
│   │   └── models.dart              # UserProfile, TodayActivity, Perk, Friend, etc.
│   ├── widgets/
│   │   └── shared_widgets.dart      # CoinBadge, InrPill, PrimaryButton, AvatarCircle,
│   │                                #   SectionHeader, FKProgressBar, CategoryChip, BoostBanner
│   ├── services/
│   │   └── pedometer_service.dart   # Health + pedometer sensor, coin conversion
│   └── screens/
│       ├── onboarding_screen.dart
│       ├── main_shell.dart          # Bottom nav (5 tabs)
│       ├── home_screen.dart
│       ├── move_screen.dart
│       ├── social_screen.dart
│       ├── community_screen.dart
│       ├── perks_screen.dart
│       └── profile_screen.dart
├── pubspec.yaml
└── README.md
```

---

## Quick Start

### 1. Create a new Flutter project and copy files

```bash
flutter create fitkart_app
cd fitkart_app
# Copy all files from this zip into the project
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Add Poppins font

Download from [Google Fonts](https://fonts.google.com/specimen/Poppins) and place in:
```
assets/fonts/Poppins-Regular.ttf
assets/fonts/Poppins-Medium.ttf
assets/fonts/Poppins-SemiBold.ttf
assets/fonts/Poppins-Bold.ttf
assets/fonts/Poppins-ExtraBold.ttf
```

Also create placeholder directories:
```bash
mkdir -p assets/images assets/icons assets/animations
touch assets/images/.gitkeep assets/icons/.gitkeep assets/animations/.gitkeep
```

### 4. Run

```bash
flutter run
```

---

## Platform Setup

### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

Min SDK in `android/app/build.gradle`:
```gradle
minSdkVersion 26
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSMotionUsageDescription</key>
<string>FitKart needs motion access to count your steps.</string>
<key>NSHealthShareUsageDescription</key>
<string>FitKart reads steps from Apple Health.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>FitKart writes activity data to Apple Health.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>FitKart uses location during workouts.</string>
```

Enable HealthKit in `ios/Runner.xcodeproj` → Signing & Capabilities → + Capability → HealthKit.

---

## Connecting to Supabase

1. Add `supabase_flutter` (already in pubspec) and init in `main.dart`:

```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);
```

2. Replace mock data in `models/models.dart` with real Supabase queries:

```dart
// Example: fetch today's steps
final data = await Supabase.instance.client
  .from('step_events')
  .select()
  .eq('user_id', userId)
  .eq('date', today)
  .single();
```

---

## Connecting Anti-Cheat Engine

In `pedometer_service.dart`, after each step sync, call your FastAPI:

```dart
final response = await http.post(
  Uri.parse('https://api.fitkart.club/validate-steps'),
  body: json.encode({
    'user_id': userId,
    'steps': _todaySteps,
    'timestamp': DateTime.now().toIso8601String(),
    'device_id': deviceId,
  }),
);
// Only credit coins if response.decision == 'APPROVE'
```

---

## Key Packages Used

| Package | Purpose |
|---|---|
| `fl_chart` | Line chart (Weekly Trend, Earnings) + Bar chart (Weekly Activity) |
| `percent_indicator` | Dual circular ring on Move screen |
| `smooth_page_indicator` | Onboarding dots |
| `health` | Apple Health / Google Fit step sync |
| `pedometer` | Raw hardware step counter fallback |
| `supabase_flutter` | Auth + database |
| `flutter_animate` | Micro-animations |
| `cached_network_image` | Perk/voucher images |

---

*FitKart Club — Move. Earn. Roar. 🐾*
