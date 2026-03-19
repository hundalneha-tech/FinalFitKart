// lib/screens/onboarding_screen.dart
// High-conversion 6-step onboarding flow:
// Step 0: Splash/Slides  →  Step 1: Auth  →  Step 2: Profile
// Step 3: Body metrics   →  Step 4: Health sync  →  Step 5: Rewards explainer
// Step 6: Referral

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
// ROOT: OnboardingScreen — manages the full flow
// ─────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  const OnboardingScreen({super.key, required this.onGetStarted, required this.onLogin});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0=slides, 1=auth, 2=profile, 3=body, 4=health, 5=rewards, 6=referral

  // Collected data
  final _profileData = <String, dynamic>{};

  void _next() => setState(() => _step++);
  void _skip() => widget.onGetStarted();

  void _onAuthSuccess() => setState(() => _step = 2);

  @override
  void initState() {
    super.initState();

    // If user is already signed in when onboarding loads
    // (e.g. returned from Google OAuth redirect), skip to profile step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _step <= 1) {
        setState(() => _step = 2);
      }
    });

    // Listen for OAuth sign-in completing
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted && _step <= 1) {
        setState(() => _step = 2);
      }
    });
  }

  void _saveProfile(Map<String, dynamic> data) {
    _profileData.addAll(data);
    _next();
  }

  Future<void> _finishOnboarding() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && _profileData.isNotEmpty) {
        await Supabase.instance.client.from('profiles').update(_profileData).eq('id', uid);
      }
    } catch (_) {}
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child),
      child: switch (_step) {
        0 => _SlidesScreen(key: const ValueKey(0), onGetStarted: _next, onLogin: _next),
        1 => _AuthScreen(key: const ValueKey(1), onSuccess: _onAuthSuccess),
        2 => _ProfileScreen(key: const ValueKey(2), onNext: _saveProfile, onSkip: _skip),
        3 => _BodyScreen(key: const ValueKey(3), onNext: _saveProfile, onSkip: _next),
        4 => _HealthSyncScreen(key: const ValueKey(4), onNext: _next, onSkip: _next),
        5 => _RewardsScreen(key: const ValueKey(5), onNext: _next),
        _ => _ReferralScreen(key: const ValueKey(6), onFinish: _finishOnboarding),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 0 — SLIDES (3 hero slides + CTA)
// ─────────────────────────────────────────────────────────────
class _SlidesScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  const _SlidesScreen({super.key, required this.onGetStarted, required this.onLogin});
  @override
  State<_SlidesScreen> createState() => _SlidesScreenState();
}

class _SlidesScreenState extends State<_SlidesScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide('Walk. Earn. Roar. 🚶', 'Every step you take earns FitKart Coins (FKC). Walk to work, walk to the mall — every step counts.', Color(0xFF1A7B8A)),
    _Slide('Redeem Amazing Perks 🎁', 'Spend your FKC on Myntra, Zomato, Starbucks, PVR and 50+ top brands. Your steps have real ₹ value.', Color(0xFF2563EB)),
    _Slide('Walk for a Cause ❤️', 'Donate your coins to feed stray animals, plant forests, and bring clean water to rural India.', Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Column(children: [
      // Skip
      Align(alignment: Alignment.topRight,
        child: TextButton(onPressed: widget.onLogin, child: const Text('Log In', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)))),

      // Slides
      Expanded(flex: 5, child: PageView.builder(
        controller: _ctrl,
        itemCount: _slides.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) {
          final s = _slides[i];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(32)),
              child: Stack(children: [
                // Background pattern
                Positioned.fill(child: CustomPaint(painter: _DotPainter())),
                Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Phone mockup
                    _PhoneMockup(color: s.color),
                    const SizedBox(height: 32),
                  ]),
                )),
              ]),
            ),
          );
        },
      )),

      // Bottom content
      Expanded(flex: 5, child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(children: [
          // Text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(key: ValueKey(_page), children: [
              Text(_slides[_page].title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2)),
              const SizedBox(height: 12),
              Text(_slides[_page].subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 24),
          SmoothPageIndicator(controller: _ctrl, count: 3,
            effect: const ExpandingDotsEffect(activeDotColor: AppColors.primary, dotColor: AppColors.border, dotHeight: 8, dotWidth: 8, expansionFactor: 3)),
          const Spacer(),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
              _StatPill('2.4M+', 'Walkers'),
              _Divider(),
              _StatPill('₹0.33', 'per FKC'),
              _Divider(),
              _StatPill('50+', 'Brands'),
            ]),
          ),
          const SizedBox(height: 20),

          // CTA
          PrimaryButton(label: 'Get Started — It\'s Free', onPressed: widget.onGetStarted),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onLogin,
            child: RichText(text: const TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                TextSpan(text: 'Already a member? '),
                TextSpan(text: 'Log In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ))),
          const SizedBox(height: 8),
        ]),
      )),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────
// STEP 1 — AUTH (Google + Apple + Email)
// ─────────────────────────────────────────────────────────────
class _AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const _AuthScreen({super.key, required this.onSuccess});
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  bool _loading = false;
  bool _isSignUp = true;
  bool _obscure = true;
  final _emailC = TextEditingController();
  final _passC  = TextEditingController();
  final _nameC  = TextEditingController();

  @override
  void dispose() { _tab.dispose(); _emailC.dispose(); _passC.dispose(); _nameC.dispose(); super.dispose(); }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        // Web browser: use Supabase OAuth redirect
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin + '/',
        );
        setState(() => _loading = false);
        return;
      }
      // Android / iOS: use native GoogleSignIn package
      const webClientId = '38568298435-r70rvv0c2o0gmdmpaeo82a8bs0j1cvqm.apps.googleusercontent.com';
      const androidClientId = '38568298435-34uhl679kp7gcfekvtba73l5860qisnb.apps.googleusercontent.com';
      final g = GoogleSignIn(clientId: androidClientId, serverClientId: webClientId);
      final user = await g.signIn();
      if (user == null) { setState(() => _loading = false); return; }
      final auth = await user.authentication;
      if (auth.accessToken == null || auth.idToken == null) {
        _snack('Google auth failed', error: true); setState(() => _loading = false); return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
        accessToken: auth.accessToken!,
      );
      widget.onSuccess();
    } on AuthException catch (e) { _snack(e.message, error: true);
    } catch (e) { _snack('Google error: \$e', error: true);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _apple() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.apple, redirectTo: 'fitkartapp://login-callback');
      widget.onSuccess();
    } on AuthException catch (e) { _snack(e.message, error: true);
    } catch (_) { _snack('Apple sign-in failed', error: true);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _emailAuth() async {
    final email = _emailC.text.trim();
    final pass  = _passC.text.trim();
    final name  = _nameC.text.trim();
    if (email.isEmpty || pass.isEmpty) { _snack('Please fill all fields', error: true); return; }
    if (_isSignUp && name.isEmpty)     { _snack('Enter your name', error: true); return; }
    if (pass.length < 6)               { _snack('Password min 6 characters', error: true); return; }
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(email: email, password: pass, data: {'name': name});
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      }
      widget.onSuccess();
    } on AuthException catch (e) { _snack(e.message, error: true);
    } catch (e) { _snack('Error: $e', error: true);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      // Logo + headline
      Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('🚶', style: TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('FitKart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text('Walk. Earn. Roar.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ]),
      const SizedBox(height: 32),
      Text(_isSignUp ? 'Create your account' : 'Welcome back!',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Text(_isSignUp ? 'Join 2.4M+ walkers earning FKC every day.' : 'Sign in to continue earning.',
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 28),

      // Social buttons
      _SocialBtn(
        icon: 'G', label: 'Continue with Google',
        color: const Color(0xFF4285F4), bgColor: Colors.white,
        onTap: _loading ? null : _google),
      const SizedBox(height: 12),
      _SocialBtn(
        icon: '', label: 'Continue with Apple',
        color: Colors.white, bgColor: Colors.black,
        isApple: true, onTap: _loading ? null : _apple),
      const SizedBox(height: 20),

      // Divider
      Row(children: const [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('or use email', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(child: Divider(color: AppColors.border)),
      ]),
      const SizedBox(height: 20),

      // Email form
      if (_isSignUp) ...[
        _Field(ctrl: _nameC, label: 'Full Name', hint: 'Rahul Sharma', icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),
      ],
      _Field(ctrl: _emailC, label: 'Email', hint: 'rahul@gmail.com', icon: Icons.email_outlined, type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _Field(ctrl: _passC, label: 'Password', hint: '••••••••', icon: Icons.lock_outline_rounded, obscure: _obscure,
        suffix: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.textSecondary),
          onPressed: () => setState(() => _obscure = !_obscure))),
      const SizedBox(height: 24),
      PrimaryButton(label: _isSignUp ? 'Create Account →' : 'Sign In →', onPressed: _loading ? null : _emailAuth, loading: _loading),
      const SizedBox(height: 16),
      Center(child: GestureDetector(
        onTap: () => setState(() => _isSignUp = !_isSignUp),
        child: RichText(text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          children: [
            TextSpan(text: _isSignUp ? 'Already have an account? ' : 'New here? '),
            TextSpan(text: _isSignUp ? 'Sign In' : 'Create Account',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ])))),
      const SizedBox(height: 24),
      const Center(child: Text('By continuing, you agree to our Terms & Privacy Policy.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
    ]))),
  );
}

// ─────────────────────────────────────────────────────────────
// STEP 2 — PROFILE (name, city, gender, step goal)
// ─────────────────────────────────────────────────────────────
class _ProfileScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onNext;
  final VoidCallback onSkip;
  const _ProfileScreen({super.key, required this.onNext, required this.onSkip});
  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _nameC = TextEditingController();
  final _cityC = TextEditingController();
  String _gender = 'prefer_not_to_say';
  int _goalSteps = 10000;

  final _goals = [5000, 7500, 10000, 12500, 15000, 20000];
  final _genders = ['male', 'female', 'other', 'prefer_not_to_say'];
  final _genderLabels = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void dispose() { _nameC.dispose(); _cityC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Column(children: [
      _StepHeader(step: 1, total: 5, title: 'Your Profile', subtitle: 'Help us personalise your experience', onSkip: widget.onSkip),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar placeholder
        Center(child: Stack(children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.accent]),
              shape: BoxShape.circle),
            child: const Center(child: Text('🚶', style: TextStyle(fontSize: 36)))),
          Positioned(right: 0, bottom: 0,
            child: Container(width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
        ])),
        const SizedBox(height: 28),

        _Field(ctrl: _nameC, label: 'Full Name', hint: 'Rahul Sharma', icon: Icons.person_outline_rounded),
        const SizedBox(height: 16),
        _Field(ctrl: _cityC, label: 'City', hint: 'Mumbai, Delhi, Bengaluru...', icon: Icons.location_city_outlined),
        const SizedBox(height: 20),

        // Gender
        const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: List.generate(4, (i) => GestureDetector(
          onTap: () => setState(() => _gender = _genders[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _gender == _genders[i] ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gender == _genders[i] ? AppColors.primary : AppColors.border)),
            child: Text(_genderLabels[i],
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _gender == _genders[i] ? Colors.white : AppColors.textSecondary)))))),
        const SizedBox(height: 20),

        // Daily step goal
        const Text('Daily Step Goal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('${_goalSteps.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps = ~₹${(_goalSteps * 0.01 * 0.33).toStringAsFixed(2)}/day',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _goals.map((g) => GestureDetector(
          onTap: () => setState(() => _goalSteps = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _goalSteps == g ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goalSteps == g ? AppColors.primary : AppColors.border)),
            child: Text('${(g / 1000).toStringAsFixed(g % 1000 == 0 ? 0 : 1)}k',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: _goalSteps == g ? Colors.white : AppColors.textPrimary))))).toList()),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue →', onPressed: () {
          widget.onNext({
            'name': _nameC.text.trim().isEmpty ? null : _nameC.text.trim(),
            'city': _cityC.text.trim().isEmpty ? null : _cityC.text.trim(),
            'gender': _gender,
            'goal_steps': _goalSteps,
          }..removeWhere((k, v) => v == null));
        }),
      ]))),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────
// STEP 3 — BODY METRICS (height, weight, DOB)
// ─────────────────────────────────────────────────────────────
class _BodyScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onNext;
  final VoidCallback onSkip;
  const _BodyScreen({super.key, required this.onNext, required this.onSkip});
  @override
  State<_BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<_BodyScreen> {
  double _heightCm = 170;
  double _weightKg = 70;
  DateTime? _dob;
  String _unit = 'metric'; // metric | imperial

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));
  String get _bmiLabel {
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 25)   return 'Healthy';
    if (_bmi < 30)   return 'Overweight';
    return 'Obese';
  }
  Color get _bmiColor {
    if (_bmi < 18.5) return AppColors.primary;
    if (_bmi < 25)   return AppColors.green;
    if (_bmi < 30)   return AppColors.yellow;
    return AppColors.red;
  }

  double get _displayHeight => _unit == 'metric' ? _heightCm : _heightCm / 2.54;
  double get _displayWeight => _unit == 'metric' ? _weightKg : _weightKg * 2.205;
  String get _heightUnit => _unit == 'metric' ? 'cm' : 'in';
  String get _weightUnit => _unit == 'metric' ? 'kg' : 'lbs';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Column(children: [
      _StepHeader(step: 2, total: 5, title: 'Body Metrics', subtitle: 'Improves calorie & coin accuracy', onSkip: widget.onSkip),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        // Unit toggle
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _Toggle(options: const ['Metric', 'Imperial'],
            selected: _unit == 'metric' ? 0 : 1,
            onSelect: (i) => setState(() => _unit = i == 0 ? 'metric' : 'imperial')),
        ]),
        const SizedBox(height: 24),

        // BMI card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_bmiColor.withOpacity(0.1), _bmiColor.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _bmiColor.withOpacity(0.3))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your BMI', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_bmi.toStringAsFixed(1), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _bmiColor)),
            ]),
            const SizedBox(width: 16),
            Container(width: 1, height: 50, color: AppColors.border),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_bmiLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _bmiColor)),
              const SizedBox(height: 4),
              const Text('Based on height & weight', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        const SizedBox(height: 28),

        // Height slider
        _MetricSlider(
          label: 'Height', value: _displayHeight, unit: _heightUnit,
          min: _unit == 'metric' ? 140 : 55, max: _unit == 'metric' ? 210 : 83,
          displayValue: '${_displayHeight.round()}$_heightUnit',
          onChanged: (v) => setState(() => _heightCm = _unit == 'metric' ? v : v * 2.54),
          icon: Icons.height_rounded, color: AppColors.primary),
        const SizedBox(height: 20),

        // Weight slider
        _MetricSlider(
          label: 'Weight', value: _displayWeight, unit: _weightUnit,
          min: _unit == 'metric' ? 30 : 66, max: _unit == 'metric' ? 200 : 440,
          displayValue: '${_displayWeight.round()}$_weightUnit',
          onChanged: (v) => setState(() => _weightKg = _unit == 'metric' ? v : v / 2.205),
          icon: Icons.monitor_weight_outlined, color: AppColors.accent),
        const SizedBox(height: 20),

        // Date of birth
        const Align(alignment: Alignment.centerLeft,
          child: Text('Date of Birth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime(1995, 1, 1),
              firstDate: DateTime(1930), lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)));
            if (d != null) setState(() => _dob = d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.cake_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(_dob == null ? 'Select your birthday' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(fontSize: 14, color: _dob == null ? AppColors.textSecondary : AppColors.textPrimary, fontWeight: FontWeight.w500)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
            ])),
        ),
        const SizedBox(height: 32),

        // Calorie preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.coinBg, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated daily earnings', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text('~100 FKC = ₹33 per day at 10k steps',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Continue →', onPressed: () {
          widget.onNext({
            'height_cm': _heightCm.round(),
            'weight_kg': _weightKg,
            'date_of_birth': _dob?.toIso8601String().split('T')[0],
            'unit_system': _unit,
          }..removeWhere((k, v) => v == null));
        }),
      ]))),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────
// STEP 4 — HEALTH SYNC (Google Fit / Apple Health)
// ─────────────────────────────────────────────────────────────
class _HealthSyncScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _HealthSyncScreen({super.key, required this.onNext, required this.onSkip});
  @override
  State<_HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<_HealthSyncScreen> {
  bool _syncing = false;
  bool _synced  = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await Future.delayed(const Duration(seconds: 2)); // Replace with real Health.requestAuthorization()
    setState(() { _syncing = false; _synced = true; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _StepHeader(step: 3, total: 5, title: 'Connect Health', subtitle: 'Auto-sync your steps — no manual entry', onSkip: widget.onSkip),
        const Spacer(),

        // Big icon
        Container(width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF34D399), Color(0xFF059669)]),
            shape: BoxShape.circle),
          child: const Center(child: Text('🏃', style: TextStyle(fontSize: 56)))),
        const SizedBox(height: 28),

        const Text('Sync with Health Apps', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2)),
        const SizedBox(height: 12),
        const Text('Connect Google Fit or Apple Health to automatically count every step you take — even in the background.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 32),

        // Benefits
        ...[
          ('📍', 'Background tracking', 'Steps counted even when app is closed'),
          ('🔋', 'Battery friendly', 'Uses system health APIs — no GPS drain'),
          ('🔒', 'Private & secure', 'Data never leaves your device without consent'),
        ].map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(b.$1, style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(b.$3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
          ]),
        )),

        const Spacer(),

        if (_synced) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(16)),
            child: Row(children: const [
              Icon(Icons.check_circle, color: AppColors.green, size: 24),
              SizedBox(width: 12),
              Expanded(child: Text('Health connected! Steps will sync automatically.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green))),
            ])),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Continue →', onPressed: widget.onNext),
        ] else ...[
          PrimaryButton(label: _syncing ? 'Connecting...' : 'Connect Health App', onPressed: _syncing ? null : _sync, loading: _syncing),
          const SizedBox(height: 12),
          TextButton(onPressed: widget.onSkip, child: const Text('Skip for now', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ],
        const SizedBox(height: 8),
      ]),
    )),
  );
}

// ─────────────────────────────────────────────────────────────
// STEP 5 — REWARDS EXPLAINER
// ─────────────────────────────────────────────────────────────
class _RewardsScreen extends StatefulWidget {
  final VoidCallback onNext;
  const _RewardsScreen({super.key, required this.onNext});
  @override
  State<_RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<_RewardsScreen> {
  int _steps = 5000;

  int get _coins => (_steps * 0.01).round();
  double get _inr => _coins * 0.33;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Column(children: [
      _StepHeader(step: 4, total: 5, title: 'How You Earn', subtitle: 'The FKC coin economy explained', onSkip: widget.onNext),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [

        // Interactive calculator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            const Text('Walk this many steps:', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${_steps.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
            const Text('steps today', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Slider(
              value: _steps.toDouble(), min: 1000, max: 20000, divisions: 19,
              activeColor: Colors.white, inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => _steps = v.round())),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _EarnPill('🪙', '$_coins FKC', 'Coins earned'),
              _EarnPill('💰', '₹${_inr.toStringAsFixed(2)}', 'INR value'),
              _EarnPill('📅', '₹${(_inr * 30).toStringAsFixed(0)}/mo', 'Monthly'),
            ]),
          ]),
        ),
        const SizedBox(height: 28),

        // How it works
        const Align(alignment: Alignment.centerLeft,
          child: Text('How FKC works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        const SizedBox(height: 16),
        ...[
          (Icons.directions_walk_rounded, AppColors.primary, '100 steps = 1 FKC', 'Walk anywhere — outdoors, treadmill, mall — all count'),
          (Icons.account_balance_wallet_outlined, AppColors.accent, '1 FKC = ₹0.33', 'Coins have real monetary value — redeem or donate'),
          (Icons.local_offer_outlined, AppColors.green, 'Redeem instantly', 'Exchange FKC for vouchers from 50+ top brands'),
          (Icons.trending_up_rounded, AppColors.yellow, '2× Boost available', 'Activate a daily boost to double your coin earnings'),
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: item.$2.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.$1, color: item.$2, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.$3, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(item.$4, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
            ]),
          ),
        )),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Got it! Continue →', onPressed: widget.onNext),
      ]))),
    ])),
  );

  }

// ─────────────────────────────────────────────────────────────
// STEP 6 — REFERRAL
// ─────────────────────────────────────────────────────────────
class _ReferralScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const _ReferralScreen({super.key, required this.onFinish});
  @override
  State<_ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<_ReferralScreen> {
  final _codeC = TextEditingController();
  bool _applied = false;
  bool _loading = false;
  String? _myCode;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  Future<void> _loadMyCode() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final data = await Supabase.instance.client.from('profiles').select('referral_code').eq('id', uid).single();
        if (mounted) setState(() => _myCode = data['referral_code']);
      }
    } catch (_) {}
  }

  Future<void> _applyCode() async {
    final code = _codeC.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Find user with this referral code
      final data = await Supabase.instance.client.from('profiles').select('id').eq('referral_code', code).maybeSingle();
      if (data == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid referral code'), backgroundColor: Colors.red));
      } else {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client.from('profiles').update({'referred_by': data['id']}).eq('id', uid);
          // Award referral bonus
          await Supabase.instance.client.rpc('transact_coins', params: {
            'p_user_id': uid, 'p_amount': 500,
            'p_type': 'EARN_REFERRAL', 'p_description': 'Referral bonus — joined via friend',
          });
        }
        if (mounted) setState(() => _applied = true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not apply code'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _share() {
    if (_myCode != null) {
      Clipboard.setData(ClipboardData(text: 'Join FitKart and earn FKC coins for walking! Use my code $_myCode to get 500 bonus coins. Download: fitkart.club'));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied! 🎉'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffold,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _StepHeader(step: 5, total: 5, title: 'Invite & Earn', subtitle: 'Get 500 FKC for every friend you bring', onSkip: widget.onFinish),
        const Spacer(),

        // Hero
        Container(width: 100, height: 100,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accent, AppColors.primary]), shape: BoxShape.circle),
          child: const Center(child: Text('🎁', style: TextStyle(fontSize: 48)))),
        const SizedBox(height: 24),
        const Text('You + Friend = 1,000 FKC', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2)),
        const SizedBox(height: 10),
        const Text('You get 500 FKC when your friend signs up. They get 500 FKC too. Walk together, earn together.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        const Spacer(),

        // My referral code
        if (_myCode != null) ...[
          const Align(alignment: Alignment.centerLeft,
            child: Text('Your referral code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _share,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryBg, Color(0xFFEDE9FE)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: Row(children: [
                Text(_myCode!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 2)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Copy & Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
              ])),
          ),
          const SizedBox(height: 20),
        ],

        // Have a code?
        if (!_applied) ...[
          const Align(alignment: Alignment.centerLeft,
            child: Text("Have a friend's code?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _codeC, label: '', hint: 'Enter referral code', icon: Icons.card_giftcard_rounded,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), LengthLimitingTextInputFormatter(8)])),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _loading ? null : _applyCode,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ] else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: const [
              Icon(Icons.check_circle, color: AppColors.green),
              SizedBox(width: 10),
              Text('Code applied! 500 FKC bonus added to your wallet 🎉', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.green)),
            ])),

        const Spacer(),
        PrimaryButton(label: "Let's Walk! 🚶", onPressed: widget.onFinish),
        const SizedBox(height: 8),
      ]),
    )),
  );
}

// ─────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int step, total;
  final String title, subtitle;
  final VoidCallback onSkip;
  const _StepHeader({required this.step, required this.total, required this.title, required this.subtitle, required this.onSkip});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: step / total,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 5))),
        const SizedBox(width: 12),
        Text('$step/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        TextButton(onPressed: onSkip, child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
    ]),
  );
}

class _Slide {
  final String title, subtitle;
  final Color color;
  const _Slide(this.title, this.subtitle, this.color);
}

class _StatPill extends StatelessWidget {
  final String value, label;
  const _StatPill(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: AppColors.border);
}

class _SocialBtn extends StatelessWidget {
  final String icon, label;
  final Color color, bgColor;
  final bool isApple;
  final VoidCallback? onTap;
  const _SocialBtn({required this.icon, required this.label, required this.color, required this.bgColor, this.isApple = false, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 54,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: isApple ? Colors.transparent : AppColors.border, width: 1.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (isApple) Icon(Icons.apple, color: color, size: 22)
        else Container(width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
          child: Center(child: Text(icon, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)))),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isApple ? color : AppColors.textPrimary)),
      ]),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({required this.ctrl, required this.label, required this.hint, required this.icon,
    this.obscure = false, this.type, this.suffix, this.prefix, this.maxLength, this.inputFormatters});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) ...[
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
    ],
    Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        if (prefix != null) prefix!
        else Padding(padding: const EdgeInsets.only(left: 14), child: Icon(icon, size: 18, color: AppColors.textSecondary)),
        Expanded(child: TextField(
          controller: ctrl, obscureText: obscure, keyboardType: type,
          maxLength: maxLength, inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), counterText: ''),
        )),
        if (suffix != null) suffix!,
      ]),
    ),
  ]);
}

class _Toggle extends StatelessWidget {
  final List<String> options;
  final int selected;
  final void Function(int) onSelect;
  const _Toggle({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(options.length, (i) => GestureDetector(
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected == i ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
        child: Text(options[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: selected == i ? AppColors.textPrimary : AppColors.textSecondary)))))),
  );
}

class _MetricSlider extends StatelessWidget {
  final String label, displayValue, unit;
  final double value, min, max;
  final void Function(double) onChanged;
  final IconData icon;
  final Color color;

  const _MetricSlider({required this.label, required this.value, required this.unit,
    required this.min, required this.max, required this.displayValue, required this.onChanged, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        Text(displayValue, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ]),
      Slider(value: value, min: min, max: max, activeColor: color, inactiveColor: color.withOpacity(0.2),
        onChanged: onChanged),
    ]),
  );
}

class _EarnPill extends StatelessWidget {
  final String icon, value, label;
  const _EarnPill(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
  ]);
}

class _PhoneMockup extends StatelessWidget {
  final Color color;
  const _PhoneMockup({required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Transform.rotate(angle: -0.08, child: Container(width: 70, height: 130,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)))),
    const SizedBox(width: 12),
    Transform.rotate(angle: 0.04, child: Container(width: 80, height: 150,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)))),
  ]);
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.05);
    for (double x = 20; x < size.width; x += 30) {
      for (double y = 20; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 2, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
