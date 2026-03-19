// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/pedometer_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await SupabaseService.init();
  runApp(const ProviderScope(child: FitKartApp()));
}

class FitKartApp extends StatefulWidget {
  const FitKartApp({super.key});
  @override
  State<FitKartApp> createState() => _FitKartAppState();
}

class _FitKartAppState extends State<FitKartApp> {
  bool? _showMain; // null = loading

  @override
  void initState() {
    super.initState();
    _determineStartScreen();
    // Only listen for sign-out to send user back to onboarding
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _showMain = false);
      }
      // NOTE: We do NOT react to signedIn here.
      // Navigation after sign-in is controlled by the onboarding flow itself
      // via _onOnboardingComplete(), which is called only after the full
      // 6-screen flow completes (or when user explicitly skips).
    });
  }

  Future<void> _determineStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    // Go to main ONLY if user previously completed the full onboarding
    if (mounted) setState(() => _showMain = isLoggedIn && onboardingDone);
  }

  Future<void> _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) setState(() => _showMain = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showMain == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB))),
        ),
      );
    }
    return MaterialApp(
      title: 'FitKart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: _showMain!
        ? const _AppWithPedometer()
        : OnboardingScreen(
            onGetStarted: _onOnboardingComplete,
            onLogin: _onOnboardingComplete,
          ),
    );
  }
}

class _AppWithPedometer extends StatefulWidget {
  const _AppWithPedometer();
  @override
  State<_AppWithPedometer> createState() => _AppWithPedometerState();
}

class _AppWithPedometerState extends State<_AppWithPedometer> {
  @override
  void initState() {
    super.initState();
    PedometerService().init();
  }

  @override
  Widget build(BuildContext context) => const MainShell();
}
